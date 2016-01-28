require_relative '../asana_exception_notifier/helper'
require_relative '../asana_exception_notifier/core'
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
    attr_reader :params, :exception

    def initialize(options)
      super
      @initial_options = options.stringify_keys
      options = @initial_options.reject { |_key, value| value.blank? }
      parse_options(options)
    end

    def call(exception, options = {})
      ensure_eventmachine_running do
        create_asana_task(exception, options)
      end
    end

    def em_request_options(options)
      body = parse_exception_options(options['exception'], options['params'])
      super.merge(
        head: {
          'Authorization' => "Bearer #{@default_options.fetch('asana_api_key', nil)}"
        },
        body: body_object(body)
      )
    end

    def active?
      @asana_api_key.present? && @workspace.present?
    end

  private

    def parse_exception_options(exception, options)
      params = @default_options.merge(options)
      env = params['env']
      {
        'env' => env,
        'exception' => exception,
        'server' =>  Socket.gethostname,
        'rails_root' => defined?(Rails) ? Rails.root : nil,
        'process' => $PROCESS_ID,
        'data' => (env.blank? ? {} : env['exception_notifier.exception_data']).merge(params['data'] || {}),
        'fault_data' => exception_data(exception),
        'request' => setup_env_params(env)
      }.merge(params)
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
        'name' => '[AsanaExceptionNotifier]'
      }.merge(options)
    end

    def template_path
      template_path = @default_options.fetch('template_path', nil)
      template_path.blank? ? default_template_path : template_path
    end

    def render_note_template(body)
      body.stringify_keys!
      Tilt.new(template_path).render(self, body)
    end

    def body_object(body)
      @default_options.merge(
        'notes' => render_note_template(body)
      )
    end

    # This method fetches data from Github api and returns the size in
    #
    # @return [void]
    def create_asana_task(exception, options)
      fetch_data('https://app.asana.com/api/1.0/tasks', 'http_method' => 'post', 'exception' => exception, 'params' => options) do |http_response|
        logger.debug(http_response)
      end
    end
  end
end
