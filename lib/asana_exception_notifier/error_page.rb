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
        template_extension: template_extension
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
      zf =::Zip::File.open(archive, Zip::File::CREATE) do |zipfile|
        zipfile.add(@tempfile.path.sub(File.dirname(@tempfile.path) + '/', ''), @tempfile.path)
      end
      FileUtils.rm_rf([@tempfile.path])
      logger.debug "[AsanaExceptionNotifier] Created Archive  #{archive} from #{zf.name}, size = #{zf.size}, compressed size = #{zf.compressed_size}"
      partial_name = "part_#{temfile_info[:filename]}"
      indexes = Zip::File.split(archive, 512, true, partial_name)
      archives = indexes.times.map do |index|
        File.join(File.dirname(archive), "#{partial_name}.zip.#{format('%03d', index + 1)}")
      end
      archives.blank? ? [archive] : archives
    end

    def upload_log_file_to_task(api_key, message)
      return if message.blank?
      create_tempfile
      archives = compress_tempfile
      archives.each do |zip|
        body = multipart_file_upload_details(zip)
        AsanaExceptionNotifier::Request.new(api_key,
                                            "https://app.asana.com/api/1.0/tasks/#{message['id']}/attachments",
                                            'http_method' => 'post',
                                            'em_request' => body,
                                            'multi' => true,
                                            'request_name' => zip
                                           ) do |_http_response|
          FileUtils.rm_rf([zip])
        end
      end
    end

    def rack_session
      @env.fetch('rack.session', {})
    end

    def rails_params
      @env.fetch('action_dispatch.request.parameters', {})
    end

    def uri_prefix
      @env.fetch('SCRIPT_NAME', '')
    end

    def request_path
      @env.fetch('PATH_INFO', '')
    end
  end
end
