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
      @initial_options = options.stringify_keys
      options = @initial_options.reject { |_key, value| value.blank? }
      parse_options(options)
    end

    def call(exception, options = {})
      ensure_eventmachine_running do
        template_params = parse_exception_options(exception, options)
        create_asana_task(template_params) if active?
      end
    end

    def em_request_options(options)
      params = {
        head: {
          'Authorization' => "Bearer #{@default_options.fetch('asana_api_key', nil)}"
        }
      }.merge(options['em_request'])
      # raise params.inspect
      super.merge(params)
    end

    def active?
      @default_options.fetch('asana_api_key', nil).present? && @default_options.fetch('workspace', nil).present?
    end

  private

    def parse_exception_options(exception, options)
      env = options['env']
      {
        'env' => env,
        'exception' => exception,
        'server' =>  Socket.gethostname,
        'rails_root' => defined?(Rails) ? Rails.root : nil,
        'process' => $PROCESS_ID,
        'data' => (env.blank? ? {} : env['exception_notifier.exception_data']).merge(options['data'] || {}),
        'fault_data' => exception_data(exception),
        'request' => setup_env_params(env)
      }.merge(options).reject { |_key, value| value.blank? }
    end

    def parse_options(options)
      @default_options = {
        'asana_api_key' => nil,
        'assignee' => 'me',
        'assignee_status' => 'inbox',
        'due_at' => Time.now.iso8601,
        'hearted' => false,
        'projects' => [],
        'followers' => [],
        'workspace' => nil,
        'memberships' => [],
        'tags' => [],
        'template_path' => default_template_path
      }.merge(options)
    end

    def template_path
      template_path = @default_options.fetch('template_path', nil)
      template_path.blank? ? default_template_path : template_path_exist(File.expand_path(template_path))
    end

    def render_note_template(template_params)
      rows = mount_table_for_hash(template_params.except('exception', 'fault_data'))
      template_params[:table_data] = rows
      template_params[:format_type] = "%-#{max_length(rows, 0).size}s: %-#{max_length(rows, 1).size}s\r\n"
      Tilt.new(template_path).render(self, template_params.stringify_keys)
    end

    def build_request_options(template_params)
      @default_options.merge(
        'name' => "[AsanaExceptionNotifier] #{template_params['fault_data']['error_class']}",
        'notes' => render_note_template(template_params)
      )
    end

    # This method fetches data from Github api and returns the size in
    #
    # @return [void]
    def create_asana_task(template_params)
      fetch_data('https://app.asana.com/api/1.0/tasks', 'http_method' => 'post', 'em_request' => { body: build_request_options(template_params) }) do |http_response|
        logger.debug(http_response)
        data = JSON.parse(http_response)
        upload_log_file_to_task(data['data']['id'], template_params) if data['error'].blank?
      end
    end

    def upload_log_file_to_task(task_id, template_params)
      content = render_note_template(template_params)
      file = setup_temfile_upload(content)
      fetch_data("https://app.asana.com/api/1.0/tasks/#{task_id}/attachments", 'http_method' => 'post', 'em_request' => { body: { file: file.path } }) do |http_response|
        logger.debug(http_response)
        file.unlink
      end
    end
  end
end
