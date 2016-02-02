require_relative '../helpers/application_helper'
module AsanaExceptionNotifier
  # class used for rendering the template for exception
  class ErrorPage
    include AsanaExceptionNotifier::ApplicationHelper

    attr_reader :template_path, :exception, :options, :boundary, :template_details, :env, :request, :tempfile, :template_params, :content

    def initialize(template_path, exception, options)
      @template_path = template_path
      @exception = exception
      @options = options.symbolize_keys
      @template_details = setup_template_details
      @env = (@options[:env] || ENV.to_h).stringify_keys
      @request = (defined?(ActionDispatch::Request) ? ActionDispatch::Request.new(@env) : Rack::Request.new(@env))
      @timestamp = Time.now
      parse_exception_options
    end

    def setup_template_details
      template_extension = @template_path.scan(/\.(\w+)\.?(.*)?/)[0][0]
      get_extension_and_name_from_file(@template_path).merge(
      template_extension: template_extension
      )
    end

    def parse_exception_options
      @template_params ||=  {
        server:  Socket.gethostname,
        exception: @exception,
        request: @request,
        environment: defined?(ActionDispatch::Request) ? @request.filtered_env : @env,
        rails_root: defined?(Rails) ? Rails.root : nil,
        process: $PROCESS_ID,
        data: (@env.blank? ? {} : @env.fetch(:'exception_notifier.exception_data', {})).merge(@options[:data] || {}),
        exception_data: exception_data,
        request_data: setup_env_params,
        uname: Sys::Uname.uname,
        timestamp: @timestamp,
        pwd:  File.expand_path($PROGRAM_NAME),
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
      return {} if @request.blank? || (@request.respond_to?(:env) && @request.env.blank?)
      {
        url: defined?(ActionDispatch::Request) ? @request.original_url : @request.path_info,
        referrer: @request.referer,
        http_method: defined?(ActionDispatch::Request) ? @request.method : @request.request_method,
        ip_address:  defined?(ActionDispatch::Request) ? @request.remote_ip : @request.ip,
        parameters: defined?(ActionDispatch::Request) ? @request.filtered_parameters : (@request.params rescue {}),
        session: @request.session,
        cookies: @request.cookies,
        user_agent: @request.user_agent
      }
    end

    def fieldsets_links
      fieldsets.map { |key, value| link_helper(key.to_s) }.join(' | ')
    end

    def fetch_fieldsets(hash, links = {}, prefix = '')
      return if hash.blank? || !hash.is_a?(Hash)
      hash.each do |key, value|
        if value.is_a?(Hash)
          fetch_fieldsets(value, links, key)
        elsif prefix.present?
          add_to_links(links, prefix, key, value)
        else
          add_to_links(links, 'basic_info', key, value)
        end
      end
      links
    end

    def add_to_links(links, prefix, key, value)
      links[prefix] ||={}
      links[prefix][key] = value if value.present?
    end

    def fieldsets
      @fieldsets ||= fetch_fieldsets(parse_exception_options)
    end

    def render_template(template = nil)
      execute_with_rescue do
        current_template = template.present? ? template : @template_path
        Tilt.new(current_template).render(self, @template_params.stringify_keys)
      end
    end

    def create_tempfile(output = render_template)
      tempfile = Tempfile.new([SecureRandom.uuid, ".#{@template_details[:template_extension]}"], encoding: 'utf-8')
      tempfile.write(output)
      tempfile.close
      details = tempfile_details(tempfile)
      [details[:filename], details[:path]]
    end

    def fetch_archives(output = render_template)
      return [] if output.blank?
      filename, path = create_tempfile(output)
      archive = compress_files(File.dirname(path), filename, [path])
      remove_tempfile(path)
      split_archive(archive, "part_#{filename}", 1024 * 1024 * 100)
    end

    def remove_tempfile(path)
      if ENV['DEBUG_ASANA_TEMPLATE']
        logger.debug(path)
      else
        FileUtils.rm_rf([path])
      end
    end


  end
end
