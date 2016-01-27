# module that is used for formatting numbers using metrics
module AsanaExceptionNotifier
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
      hash.map do |key , value|
        value.is_a?(Hash) ? show_hash_content(value) : ["#{key}:", value]
      end.join("\n  ")
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

    def run_eventmachine(&block)
      EM.run do
        block.call
      end
    end

    # Dispatches the response either to the final callback or to the block that will use the response
    # and then call the callback
    #
    # @param [String] res The response string that will be dispatched
    # @param [Hash] options The callback that is used to dispatch further the response
    # @param [Proc] block The block that is used for parsing response and then calling the callback
    # @return [void]
    def dispatch_http_response(res, options, &block)
      callback = options.fetch('callback', nil)
      (!res.empty? && !callback.nil?) ? callback.call(res) : block.call(res)
    end



  end
end
