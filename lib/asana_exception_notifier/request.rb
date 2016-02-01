require_relative './helper'
require_relative './core'
module AsanaExceptionNotifier
  # class used to make request in deferrable way
  class Request
    include AsanaExceptionNotifier::API::Core
    include AsanaExceptionNotifier::Helper
    include EM::Deferrable

    attr_reader :url, :options

    def initialize(api_key, url, options, &callback)
      @api_key = api_key
      @url = url

      @options = options.symbolize_keys

      self.callback(&callback)
      run_http_request
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
      super.merge(params)
    end

    def run_http_request
      ensure_eventmachine_running do
        Thread.new do
          send_request_and_rescue
        end
      end
    end

    def send_request_and_rescue
      http = em_request(@url, @options)
      send_request(http)
    rescue => exception
      log_exception(exception)
      fail(result: { message: exception })
    end

    def send_request(http)
      fetch_data(http, @options) do |http_response|
        handle_multi_response(http, http_response)
      end
    end

    def handle_multi_response(http, http_response)
      logger.debug("[AsanaExceptionNotifier]: Task #{@options.fetch(:action, '')} returned:  #{http_response}")
      @multi_manager.requests.delete(http) if @multi_manager.present?
      if http_response.is_a?(Array)
        http_response.each { |response| handle_response(response) }
      else
        handle_response(http_response)
      end
    end

    def handle_response(http_response)
      data = JSON.parse(http_response)
      callback_task_creation(data)
    end

    def callback_task_creation(data)
      data.fetch('errors', {}).present? ? fail(data) : succeed(data)
    end
  end
end
