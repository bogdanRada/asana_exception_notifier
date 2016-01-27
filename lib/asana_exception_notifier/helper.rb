module AsanaExceptionNotifier
  # module that is used for formatting numbers using metrics
  module Helper
  # function that makes the methods incapsulated as utility functions

  module_function

    # def extract_body(env)
    #   if io = env['rack.input']
    #     io.rewind if io.respond_to?(:rewind)
    #     io.read
    #   end
    # end

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
      @logger ||= ExceptionNotifier.logger
    end

    def ensure_eventmachine_running(&block)
      register_em_error_handler
      run_eventmachine(&block)
    end

    def register_em_error_handler
      EM.error_handler do |error|
        logger.debug "Error during event loop : #{error.inspect}"
        logger.debug error.backtrace
      end
    end

    def run_eventmachine(&_block)
      EM.run do
        yield
      end
    end

    def erb_template(file_path, options)
      namespace = OpenStruct.new(options)
      template = ERB.new(File.read(file_path)).result(namespace.instance_eval { binding })
      template
    end
  end
end
