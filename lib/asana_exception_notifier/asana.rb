require_relative './helper'
require_relative './core'
# class used for connecting to github api and retrieves information about repository
#
# @!attribute callback
#   @return [Proc] The callback that is executed after the info is fetched from Github API
module ExceptionNotifier
  # module that is used for formatting numbers using metrics
  class AsanaNotifier < ExceptionNotifier::BaseNotifier
    include AsanaExceptionNotifier::API::Core
    include AsanaExceptionNotifier::Helper
    # the base url to which the API will connect for fetching information about gems
    attr_reader :initial_options, :exception

    def initialize(options)
      super
      @initial_options = options.symbolize_keys
      options = @initial_options.reject { |_key, value| value.blank? }
      parse_options(options)
    end

    def call(exception, options = {})
      ensure_eventmachine_running do
        error_page = AsanaExceptionNotifier::ErrorPage.new(template_path, exception, options)
        create_asana_task(error_page) if active?
      end
    end

    def em_request_options(options)
      request = setup_em_options(options).delete(:em_request)
      params = {
        head: (request[:head] || {}).merge(
          'Authorization' => "Bearer #{@default_options.fetch(:asana_api_key, nil)}"
        ),
        body: request[:body]
      }
      # raise params.inspect
      super.merge(params)
    end

    def active?
      @default_options.fetch(:asana_api_key, nil).present? && @default_options.fetch(:workspace, nil).present?
    end

  private

    def parse_options(options)
      options = options.symbolize_keys.reject { |key, _value| !permitted_options.key?(key) }
      @default_options = permitted_options.merge(options).reject { |_key, value| value.blank? }
    end

    def template_path
      template_path = @default_options.fetch(:template_path, nil)
      template_path.blank? ? default_template_path : template_path_exist(File.expand_path(template_path))
    end

    def build_request_options(error_page)
      @default_options.except(:asana_api_key, :template_path).merge(
        name: @default_options.fetch(:name, nil) || "[AsanaExceptionNotifier] #{error_page.exception_data[:message]}",
        notes:  @default_options.fetch(:notes, nil) || error_page.render_template(File.join(template_dir, 'asana_exception_notifier.text.erb')),
        workspace: @default_options.fetch(:workspace, nil).to_i
      ).symbolize_keys!
    end

    # This method fetches data from Github api and returns the size in
    #
    # @return [void]
    def create_asana_task(error_page)
      fetch_data('https://app.asana.com/api/1.0/tasks', 'http_method' => 'post', 'em_request' => { body: build_request_options(error_page) }) do |http_response|
        data = JSON.parse(http_response)
        callback_task_creation(data['errors'], data['data'], action: 'creation') do
          upload_log_file_to_task(data['data'], error_page)
        end
      end
    end

    def callback_task_creation(errors, message, options)
      if errors.present?
        logger.debug("\n\n[AsanaExceptionNotifier]: Task #{options.fetch(:action, '')} failed with error: #{errors}")
      else
        logger.debug("\n\n[AsanaExceptionNotifier]: Task #{options.fetch(:action, '')} successfully with: #{message.fetch('id', message)}")
        yield if block_given?
      end
    end

    def upload_log_file_to_task(message, error_page)
      return if error_page.blank? || message.blank?
      fetch_data("https://app.asana.com/api/1.0/tasks/#{message['id']}/attachments", 'http_method' => 'post', 'em_request' => error_page.multipart_file_upload_details) do |http_response|
        data = JSON.parse(http_response)
        callback_task_creation(data['errors'], data['data'], action: 'uploaded')
      end
    end
  end
end
