require_relative './helper'
module AsanaExceptionNotifier
  # class used for rendering the template for exception
  class ErrorPage
    include AsanaExceptionNotifier::Helper

    attr_reader :template_path, :exception, :options, :boundary, :template_details, :env, :request, :tempfile, :template_params, :content

    def initialize(template_path, exception, options)
      @template_path = template_path
      @exception = exception
      @options = options.symbolize_keys
      @template_details = setup_template_details
      @env = (@options[:env] || {}).stringify_keys
      @request = (defined?(ActionDispatch::Request) ? ActionDispatch::Request.new(@env) : Rack::Request.new(@env)) if @env.present?
      @tempfile = Tempfile.new([SecureRandom.uuid, ".#{@template_details[:template_extension]}"], encoding: 'utf-8')
      @template_params = parse_exception_options
      @content = render_template
    end

    def setup_template_details
      template_extension = @template_path.scan(/\.(\w+)\.?(.*)?/)[0][0]
      get_extension_and_name_from_file(@template_path).merge(
        template_extension: template_extension,
        mime: Rack::Mime::MIME_TYPES[".#{template_extension}"]
      )
    end

    def parse_exception_options
      {
        server:  Socket.gethostname,
        rails_root: defined?(Rails) ? Rails.root : nil,
        process: $PROCESS_ID,
        data: (@env.blank? ? {} : @env.fetch(:'exception_notifier.exception_data', {})).merge(@options[:data] || {}),
        fault_data: exception_data,
        request: setup_env_params,
        timestamp: Time.now,
        referrer:  @env.fetch('HTTP_REFERER', ''),
        user_agent: @env.fetch('HTTP_USER_AGENT', '')
      }.merge(@options).reject { |_key, value| value.blank? }
    end

    def exception_data
      {
        error_class: @exception.class.to_s,
        message:  @exception.respond_to?(:message) ? @exception.message : exception.inspect,
        backtrace: @exception.respond_to?(:backtrace) ? @exception.backtrace : '',
        cause: @exception.respond_to?(:cause) ? @exception.cause : ''
      }
    end

    def setup_env_params
      return {} if @request.blank?
      {
        url: @request.original_url,
        http_method: @request.method,
        ip_address: @request.remote_ip,
        parameters: @request.filtered_parameters,
        session: @request.session,
        environment: @request.filtered_env
      }
    end

    def render_template(template = nil)
      current_template = template.present? ? template : @template_path
      Tilt.new(current_template).render(self, @template_params.stringify_keys)
    end

    def create_tempfile
      @tempfile.write(@content)
      @tempfile.close
    end

    def get_tempfile_archive(temfile_info)
      archive = File.join(File.dirname(@tempfile.path), temfile_info[:filename] + '.zip')
      FileUtils.mkdir_p(File.dirname(archive)) unless File.directory?(File.dirname(archive))
      FileUtils.rm archive, force: true if File.exist?(archive)
      archive
    end

    def compress_tempfile
      temfile_info = tempfile_details(@tempfile)
      archive = get_tempfile_archive(temfile_info)
      ::Zip::File.open(archive, Zip::File::CREATE) do |zipfile|
        zipfile.add(@tempfile.path.sub(File.dirname(@tempfile.path) + '/', ''), @tempfile.path)
      end
      zf = Zip::File.new(archive)
      zf.each_with_index do |entry, index|
        logger.debug "entry #{entry.class} #{index} is #{entry.name}, size = #{entry.size}, compressed size = #{entry.compressed_size}"
      end
      FileUtils.rm_rf([@tempfile.path])
      # Zip::File.split(archive, 102_400, false) do |part_count, part_index, chunk_bytes, segment_bytes|
      #   logger.debug "#{part_index} of #{part_count} part splitting: #{(chunk_bytes.to_f / segment_bytes.to_f * 100).to_i}%"
      # end
      [archive]
    end

    def rack_session
      @env['rack.session']
    end

    def rails_params
      @env['action_dispatch.request.parameters']
    end

    def uri_prefix
      @env['SCRIPT_NAME'] || ''
    end

    def request_path
      @env['PATH_INFO']
    end

    def text_heading(char, str)
      str + "\n" + char * str.size
    end

    def inspect_value(obj)
      CGI.escapeHTML(obj.inspect)
    rescue NoMethodError
      "<span class='unsupported'>(object doesn't support inspect)</span>"
    rescue
      "<span class='unsupported'>(exception was raised in inspect)</span>"
    end
  end
end
