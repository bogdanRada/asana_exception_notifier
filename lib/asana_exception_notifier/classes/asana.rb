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
      super
      @initial_options = options.symbolize_keys.reject { |_key, value| value.blank? }
      parse_options(@initial_options)
    end

    def call(exception, options = {})
      ensure_eventmachine_running do
        execute_with_rescue do
          EM::HttpRequest.use AsanaExceptionNotifier::Request::Middleware if ENV['DEBUG_ASANA_EXCEPTION_NOTIFIER']
          error_page = AsanaExceptionNotifier::ErrorPage.new(template_path, exception, options)
          create_asana_task(error_page) if active?
        end
      end
    end

    def asana_api_key
      @default_options.fetch(:asana_api_key, nil)
    end

    def workspace
      @default_options.fetch(:workspace, nil)
    end

    def notes
      @default_options.fetch(:notes, nil)
    end

    def task_name
      @default_options.fetch(:name, nil)
    end

    def active?
      asana_api_key.present? && workspace.present?
    end

    def template_path
      @default_options.fetch(:template_path, nil)
    end

  private

    def parse_options(options)
      options = options.reject { |key, _value| !permitted_options.key?(key) }
      @default_options = permitted_options.merge(options).reject { |_key, value| value.blank? }
    end

    def note_content(error_page)
      if path_is_a_template?(notes)
        error_page.render_template(expanded_path(notes))
      else
        notes.present? ? notes : error_page.render_template(File.join(template_dir, 'notes.text.erb'))
      end
    end

    def task_name_content(error_page)
      task_name.present? ? task_name : "[AsanaExceptionNotifier] #{error_page.exception_data[:message]}"
    end

    def build_request_options(error_page)
      @default_options.except(:asana_api_key, :template_path).merge(
        name: task_name_content(error_page),
        notes:  note_content(error_page),
        workspace: workspace.to_i
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
      archives = error_page.fetch_all_archives
      archives.each do |zip|
        upload_archive(zip, task_data)
      end
    end

    def upload_archive(zip, task_data)
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
