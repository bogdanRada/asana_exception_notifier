require_relative './helper'
require_relative './request'
# class used for connecting to github api and retrieves information about repository
#
# @!attribute callback
#   @return [Proc] The callback that is executed after the info is fetched from Github API
module ExceptionNotifier
  # module that is used for formatting numbers using metrics
  class AsanaNotifier < ExceptionNotifier::BaseNotifier
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
      error_page = AsanaExceptionNotifier::ErrorPage.new(template_path, exception, options)
      create_asana_task(error_page) if active?
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
      api_key = @default_options.fetch(:asana_api_key, nil)
      AsanaExceptionNotifier::Request.new(api_key,
                                          'https://app.asana.com/api/1.0/tasks',
                                          'http_method' => 'post',
                                          'em_request' => { body: build_request_options(error_page) }
                                         ) do |http_response|
        error_page.upload_log_file_to_task(api_key, http_response)
      end
    end
  end
end
