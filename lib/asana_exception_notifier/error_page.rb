require_relative './helper'
module AsanaExceptionNotifier
  # class used for rendering the template for exception
  class ErrorPage
    include AsanaExceptionNotifier::Helper

    attr_reader :template_path, :exception, :options, :template_params, :env

    def initialize(template_path, exception, options)
      @template_path = template_path
      @exception = exception
      @options = options.symbolize_keys
      @template_details = setup_template_details
      @env = @options[:env]
      @request = @env.present? && defined?(ActionDispatch::Request) ? ActionDispatch::Request.new(@env) : nil
      @tempfile = Tempfile.new(SecureRandom.uuid, encoding: 'utf-8')
      @template_params = parse_exception_options
      @content = render
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
        data: (@env.blank? ? {} : @env[:'exception_notifier.exception_data']).merge(@options[:data] || {}),
        fault_data: exception_data,
        request: setup_env_params
      }.merge(options).reject { |_key, value| value.blank? }
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
      return if @request.blank?
      {
        url: @request.original_url,
        http_method: @request.method,
        ip_address: @request.remote_ip,
        parameters: @request.filtered_parameters,
        timestamp: Time.current,
        session: @request.session,
        environment: @request.filtered_env,
        status: @request.status,
        body: @request.body
      }
    end

    def render
      rows = mount_table_for_hash(@template_params.except(:fault_data))
      @template_params[:table_data] = rows
      @template_params[:format_type] = "%-#{max_length(rows, 0).size}s: %-#{max_length(rows, 1).size}s\r\n"
      Tilt.new(template_path).render(self, @template_params.stringify_keys)
    end

    def create_tempfile
      @tempfile.write(@content)
      @tempfile.close
    end

    def multipart_file_upload_details
      create_tempfile
      file_part = Part.new(name: 'file',
                           body: @content,
                           filename: "#{SecureRandom.uuid}.#{@template_details[:template_extension]}",
                           content_type: @template_details[:mime]
                          )
      boundary = "---------------------------#{rand(10_000_000_000_000_000_000)}"
      body = MultipartBody.new([file_part], boundary)
      file_upload_request_options(boundary, body)
    end

    def file_upload_request_options(boundary, body)
      {
        body: body.to_s,
        head:
        {
          'Content-Type' => "multipart/form-data;boundary=#{boundary}",
          'Content-Length' => File.size(tempfile_details(@tempfile)[:path]),
          'Expect' => '100-continue'
        }
      }
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
