require_relative './helper'
module AsanaExceptionNotifier
  module API
    # module that is used for formatting numbers using metrics
    #
    # @!attribute params
    #   @return [Hash] THe params received from URL
    # @!attribute hostname
    #   @return [String] THe hostname from where the badges are fetched from
    # @!attribute base_url
    #   @return [String] THe base_url of the API
    module Core
      include Helper

      attr_reader :params

      # Returns the connection options used for connecting to API's
      #
      # @return [Hash] Returns the connection options used for connecting to API's
      def em_connection_options
        {
          connect_timeout: 5,        # default connection setup timeout
          inactivity_timeout: 10,    # default connection inactivity (post-setup) timeout
          ssl: {
            verify_peer: false
          },
          head: {
            'ACCEPT' => '*/*',
            'Connection' => 'keep-alive'
          }
        }
      end

      # Returns the request options used for connecting to API's
      #
      # @return [Hash] Returns the request options used for connecting to API's
      def em_request_options(_options = {})
        {
          redirects: 5,              # follow 3XX redirects up to depth 5
          keepalive: true,           # enable keep-alive (don't send Connection:close header)
          head: {
            'ACCEPT' => '*/*'
          }
        }
      end

      # instantiates an eventmachine http request object that will be used to make the htpp request
      # @see EventMachine::HttpRequest#initialize
      #
      # @param [String] url The URL that will be used in the HTTP request
      # @return [EventMachine::HttpRequest] Returns an http request object
      def em_request(url, options)
        uri = Addressable::URI.parse(url)
        conn_options = em_connection_options.merge(ssl: { sni_hostname: uri.host })
        em_request = EventMachine::HttpRequest.new(url, conn_options)
        em_request.send(options.fetch('http_method', 'get'), em_request_options(options))
      end

      # Method that fetch the data from a URL and registers the error and success callback to the HTTP object
      # @see #em_request
      # @see #register_error_callback
      # @see #register_success_callback
      #
      # @param [url] url The URL that is used to fetch data from
      # @param [Lambda] callback The callback that will be called if the response is blank
      # @param [Proc] block If the response is not blank, the block will receive the response
      # @return [void]
      def fetch_data(url, options = {}, &block)
        http = em_request(url, options)
        register_error_callback(http)
        register_success_callback(http, options, &block)
      end

      # Method that is used to register a success callback to a http object
      # @see #callback_before_success
      # @see #dispatch_http_response
      #
      # @param [EventMachine::HttpRequest] http The HTTP object that will be used for registering the success callback
      # @param [Lambda] callback The callback that will be called if the response is blank
      # @param [Proc] block If the response is not blank, the block will receive the response
      # @return [void]
      def register_success_callback(http, options)
        http.callback do
          res = callback_before_success(http.response)
          callback = options.fetch('callback', nil)
          block_given? ? yield(res) : callback.call(res)
        end
      end

      # Callback that is used before returning the response the the instance
      #
      # @param [String] response The response that will be dispatched to the instance class that made the request
      # @return [String] Returns the response
      def callback_before_success(response)
        response
      end

      # This method is used to reqister a error callback to a HTTP request object
      # @see #callback_error
      # @param [EventMachine::HttpRequest] http The HTTP object that will be used for reqisteringt the error callback
      # @return [void]
      def register_error_callback(http)
        http.errback { |error| callback_error(error) }
      end

      # Method that is used to react when an error happens in a HTTP request
      # and prints out an error message
      #
      # @param [Object] error The error that was raised by the HTTP request
      # @return [void]
      def callback_error(error)
        logger.debug "Error during fetching data  : #{error.inspect}"
      end
    end
  end
end
