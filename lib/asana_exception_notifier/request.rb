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
          begin
            send_request
          rescue => exception
            logger.debug exception.inspect
            logger.debug exception.backtrace
            request.fail(result: { message: exception })
          end
        end
      end
    end

    def send_request
      fetch_data(@url, @options) do |http_response|
        data = JSON.parse(http_response)
        message = data.fetch('data', {})
        callback_task_creation(data['errors'], message, action: 'creation')
      end
    end

    def callback_task_creation(errors, message, options)
      action = options.fetch(:action, '')
      if errors.present?
        logger.debug("\n\n[AsanaExceptionNotifier]: Task #{action} failed with error: #{errors}")
        fail(message)
      else
        logger.debug("\n\n[AsanaExceptionNotifier]: Task #{action} successfully with: #{message.fetch('id', message)}")
        succeed(message)
      end
    end
  end
end
