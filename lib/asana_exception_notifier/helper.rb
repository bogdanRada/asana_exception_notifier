require_relative './request_middleware'
module AsanaExceptionNotifier
  # module that is used for formatting numbers using metrics
  module Helper
  # function that makes the methods incapsulated as utility functions

  module_function

    def extract_body(env)
      return if env.blank? || !env.is_a?(Hash)
      io = env['rack.input']
      io.rewind if io.respond_to?(:rewind)
      io.read
    end

    def exception_data(exception)
      {
        'error_class' => exception.class.to_s,
        'message' =>  exception.message.inspect,
        'backtrace' => exception.backtrace
      }
    end

    def setup_env_params(env)
      return {} if env.blank? || !defined?(ActionDispatch::Request)
      request = ActionDispatch::Request.new(env)
      {
        'url' => request.original_url,
        'http_method' => request.method,
        'ip_address' => request.remote_ip,
        'parameters' => request.filtered_parameters,
        'timestamp' => Time.current,
        'session' => request.session,
        'environment' => request.filtered_env,
        'status' => request.status,
        'body' => request.body
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
      tempfile
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

    # Mount table for hash, using name and value and adding a name_value class
    # to the generated table.
    #
    def mount_table_for_hash(hash, _options = {})
      return if hash.blank?
      get_hash_rows(hash)
    end
  end
end
