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
        body_options = body_object(template_params)
        create_asana_task(body_options) if active?
      end
    end

    def em_request_options(options)
      super.merge(
        head: {
          'Authorization' => "Bearer #{@default_options.fetch('asana_api_key', nil)}"
        },
        body: options.fetch('body', {})
      )
    end

    def active?
      @default_options.fetch('asana_api_key', nil).present? && @default_options.fetch('workspace', nil).present?
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

    def render_note_template(template_params)
      template_params.stringify_keys!
      Tilt.new(template_path).render(self, template_params)
    end

    def body_object(body)
      @default_options.merge(
        'notes' => render_note_template(body)
      )
    end

    # This method fetches data from Github api and returns the size in
    #
    # @return [void]
    def create_asana_task(body_options)
      fetch_data('https://app.asana.com/api/1.0/tasks', 'http_method' => 'post', 'body' => body_options) do |http_response|
        logger.debug(http_response)
      end
    end
  end
end
