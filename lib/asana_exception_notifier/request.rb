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

    def em_request_options
      request = setup_em_options(@options).delete(:em_request)
      params = {
        head: (request[:head] || {}).merge(
          'Authorization' => "Bearer #{@api_key}"
        ),
        body: request[:body]
      }
      # raise params.inspect
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
      send_request(@options[:request_name])
    rescue => exception
      log_exception(exception)
      fail(result: { message: exception })
    end

    def get_response(http_response, request_name)
      response = @options[:multi].present? ? http_response[request_name].response : http_response
      JSON.parse(response)
    end

    def send_request(request_name)
      fetch_data(@url, @options) do |http_response|
        data = get_response(http_response, request_name)
        message = data.fetch('data', {})
        callback_task_creation(data['errors'], message, action: 'creation')
      end
    end

    def callback_task_creation(errors, message, options)
      action = options.fetch(:action, '')
      if errors.present?
        logger.debug("[AsanaExceptionNotifier]: Task #{action} failed with error: #{errors}")
        fail(errors)
      else
        logger.debug("[AsanaExceptionNotifier]: Task #{action} successfully with: #{message.slice('id', 'name')}")
        succeed(message)
      end
    end
  end
end
