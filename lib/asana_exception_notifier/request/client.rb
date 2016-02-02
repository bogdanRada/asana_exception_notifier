require_relative './core'
module AsanaExceptionNotifier
  module Request
    # class used to make request in deferrable way
    class Client
      include AsanaExceptionNotifier::Request::Core
      include EM::Deferrable

      attr_reader :url, :options, :api_key, :request_name, :request_final, :action

      def initialize(api_key, url, options, &callback)
        @api_key = api_key
        @url = url

        @options = options.symbolize_keys
        @request_name = @options.fetch(:request_name, '')
        @request_final = @options.fetch(:request_final, false)
        @action = @options.fetch(:action, '')

        self.callback(&callback)

        send_request_and_rescue
      end

      def multi_manager
        @multi_manager ||= options.fetch(:multi_manager, nil)
      end

      def em_request_options
        request = setup_em_options(@options).delete(:em_request)
        params = {
          head: (request[:head] || {}).merge(
            'Authorization' => "Bearer #{@api_key}"
          ),
          body: request[:body]
        }
        super(params)
      end

      def send_request_and_rescue
        @http = em_request(@url, @options)
        send_request
      rescue => exception
        log_exception(exception)
        fail(result: { message: exception })
      end

      def send_request
        fetch_data(@options) do |http_response|
          handle_all_responses(http_response)
        end
      end

      def handle_all_responses(http_response)
        @multi_manager.requests.delete(@http) if @multi_manager.present?
        if http_response.is_a?(Hash) && %i(callback errback).all? { |key| http_response.symbolize_keys.keys.include?(key) }
          handle_multi_response(http_response)
        else
          handle_response(http_response, @options.fetch(:request_name, ''))
        end
      end

      def handle_multi_response(http_response)
        logger.debug('[AsanaExceptionNotifier]: Handling multi responses')
        get_multi_request_values(http_response, :callback).each { |request_name, response| handle_response(response, request_name) }
        get_multi_request_values(http_response, :errback).each { |request_name, response| handle_error(response, request_name) }
      end

      def handle_error(error, key = '')
        logger.debug("[AsanaExceptionNotifier]: Task #{key} #{@action} returned:  #{error}")
        fail(error)
      end

      def handle_response(http_response, key = '')
        logger.debug("[AsanaExceptionNotifier]: Task #{key} #{@action} returned:  #{http_response}")
        data = JSON.parse(http_response)
        callback_task_creation(data)
      end

      def callback_task_creation(data)
        data.fetch('errors', {}).present? ? handle_error(data) : succeed(data)
      end
    end
  end
end