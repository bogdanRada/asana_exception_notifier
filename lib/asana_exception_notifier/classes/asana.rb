require_relative '../helpers/application_helper'
require_relative '../request/client'
require_relative '../request/middleware'
# class used for connecting to github api and retrieves information about repository
#
# @!attribute callback
#   @return [Proc] The callback that is executed after the info is fetched from Github API
module ExceptionNotifier
  # module that is used for formatting numbers using metrics
  class AsanaNotifier < ExceptionNotifier::BaseNotifier
    include AsanaExceptionNotifier::ApplicationHelper
    # the base url to which the API will connect for fetching information about gems
    attr_reader :initial_options, :default_options

    def initialize(options)
      execute_with_rescue do
        super
        @initial_options = options.symbolize_keys
        options = @initial_options.reject { |_key, value| value.blank? }
        parse_options(options)
      end
    end

    def call(exception, options = {})
      execute_with_rescue do
        error_page = AsanaExceptionNotifier::ErrorPage.new(template_path, exception, options)
        ensure_eventmachine_running do
          EM::HttpRequest.use AsanaExceptionNotifier::Request::Middleware if ENV['DEBUG_ASANA_EXCEPTION_NOTIFIER']
          create_asana_task(error_page) if active?
        end
      end
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
      AsanaExceptionNotifier::Request::Client.new(@default_options.fetch(:asana_api_key, nil),
                                                  'https://app.asana.com/api/1.0/tasks',
                                                  'http_method' => 'post',
                                                  'em_request' => { body: build_request_options(error_page) },
                                                  'action' => 'creation'
                                                 ) do |http_response|
        ensure_eventmachine_running do
          upload_log_file_to_task(error_page, http_response.fetch('data', {}))
        end
      end
    end

    def upload_log_file_to_task(error_page, task_data)
      archives = error_page.fetch_archives
      archives.each do |zip|
        upload_archive(archives, zip, task_data)
      end
    end

    def upload_archive(archives, zip, task_data)
      return if task_data.blank?
      body = multipart_file_upload_details(zip)
      AsanaExceptionNotifier::Request::Client.new(@default_options.fetch(:asana_api_key, nil),
                                                  "https://app.asana.com/api/1.0/tasks/#{task_data['id']}/attachments",
                                                  'http_method' => 'post',
                                                  'em_request' => body,
                                                  'request_name' => zip,
                                                  'action' => 'upload'
                                                 ) do |_http_response|

        FileUtils.rm_rf([zip])
      end
    end
  end
end