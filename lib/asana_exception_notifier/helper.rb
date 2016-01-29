require_relative './request_middleware'
module AsanaExceptionNotifier
  # module that is used for formatting numbers using metrics
  module Helper
  # function that makes the methods incapsulated as utility functions

  module_function

    def permitted_options
      {
        asana_api_key:  nil,
        workspace: nil,
        assignee:  nil,
        assignee_status: nil,
        due_at: nil,
        due_on: nil,
        hearted: false,
        hearts: [],
        projects: [],
        followers: [],
        memberships: [],
        tags: [],
        notes: '',
        name: '',
        template_path: default_template_path
      }
    end

    def extract_body(env)
      return if env.blank? || !env.is_a?(Hash)
      io = env['rack.input']
      io.rewind if io.respond_to?(:rewind)
      io.read
    end

    def exception_data(exception)
      {
        error_class: exception.class.to_s,
        message:  exception.message.inspect,
        backtrace: exception.backtrace
      }
    end

    def setup_env_params(env)
      return {} if env.blank? || !defined?(ActionDispatch::Request)
      request = ActionDispatch::Request.new(env)
      {
        url: request.original_url,
        http_method: request.method,
        ip_address: request.remote_ip,
        parameters: request.filtered_parameters,
        timestamp: Time.current,
        session: request.session,
        environment: request.filtered_env,
        status: request.status,
        body: request.body
      }
    end

    def show_hash_content(hash)
      hash.map do |key, value|
        value.is_a?(Hash) ? show_hash_content(value) : ["#{key}:", value]
      end.join("\n  ")
    end

    #  returns the logger used to log messages and errors
    #
    # @return [Logger]
    #
    # @api public
    def logger
      @logger ||= defined?(Rails) ? Rails.logger : ExceptionNotifier.logger
    end

    def ensure_eventmachine_running(&block)
      register_em_error_handler
      run_eventmachine(&block)
    end

    def register_em_error_handler
      EM.error_handler do |error|
        logger.debug "AsanaExceptionNotifier: Error during event loop : #{error.inspect}"
        logger.debug "AsanaExceptionNotifier:#{error.backtrace.join("\n")}"
      end
    end

    def run_eventmachine(&_block)
      EM.run do
        EM::HttpRequest.use AsanaExceptionNotifier::RequestMiddleware if ENV['DEBUG_ASANA_EXCEPTION_NOTIFIER']
        yield
      end
    end

    def default_template_path
      File.join(File.dirname(__FILE__), 'note_templates', 'asana_exception_notifier.text.erb')
    end

    def setup_temfile_upload(content)
      tempfile = Tempfile.new('asana_exception_notifier')
      tempfile.write(content)
      tempfile.close
      tempfile_details(tempfile, content)
    end

    def template_path_exist(path)
      return path if File.exist?(path)
      fail ArgumentError, "file #{path} doesn't exist"
    end

    def max_length(rows, index)
      value = rows.max_by { |array| array[index].to_s.size }
      value.is_a?(Array) ? value[index] : value
    end

    def get_hash_rows(hash, rows = [], prefix = '')
      hash.each do |key, value|
        if value.is_a?(Hash)
          get_hash_rows(value, rows, "#{key}.")
        else
          rows.push(["#{prefix}#{key}", value])
        end
      end
      rows
    end

    def get_extension_and_name_from_file(tempfile)
      pathname = Pathname.new(tempfile.path)
      extension = pathname.extname
      {
        extension: extension,
        filename: File.basename(pathname, extension)
      }
    end

    def tempfile_details(tempfile, content)
      file_details = get_extension_and_name_from_file(tempfile)
      details = {
        file: tempfile,
        path:  tempfile.path,
        filename: file_details[:filename],
        extension:  file_details[:extension],
        content: content
      }
      multipart_file_details(details)
    end

    def file_upload_request_options(boundary, body, file_details)
      {
        body: body.to_s,
        file_details: file_details,
        head:
        {
          'Content-Type' => "multipart/form-data;boundary=#{boundary}",
          'Content-Length' => File.size(file_details[:path]),
          'Expect' => '100-continue'
        }
      }
    end

    def parse_exception_options(exception, options)
      options.symbolize_keys!
      env = options[:env]
      {
        env: env,
        exception: exception,
        server:  Socket.gethostname,
        rails_root: defined?(Rails) ? Rails.root : nil,
        process: $PROCESS_ID,
        data: (env.blank? ? {} : env[:'exception_notifier.exception_data']).merge(options[:data] || {}),
        fault_data: exception_data(exception),
        request: setup_env_params(env)
      }.merge(options).reject { |_key, value| value.blank? }
    end

    def setup_em_options(options)
      options.symbolize_keys!
      options[:em_request] ||= {}
      options[:em_request][:head] ||= {}
      options
    end

    def multipart_file_details(file_details)
      file_part = Part.new(name: 'file',
                           body: file_details[:content],
                           filename: file_details[:filename],
                           content_type: 'text/html'
                          )
      boundary = "---------------------------#{rand(10_000_000_000_000_000_000)}"
      body = MultipartBody.new([file_part], boundary)
      file_upload_request_options(boundary, body, file_details)
    end

    # Mount table for hash, using name and value and adding a name_value class
    # to the generated table.
    #
    def mount_table_for_hash(hash, _options = {})
      return if hash.blank?
      get_hash_rows(hash)
    end
  end
end
