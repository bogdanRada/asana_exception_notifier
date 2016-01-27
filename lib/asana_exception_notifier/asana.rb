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
      @default_options = options
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
          'Authorization' => "Bearer #{@asana_api_key}"
        },
        body: body_object(body)
      )
    end

    def active?
      !@asana_api_key.nil? && !@workspace.nil?
    end

  private

    def parse_exception_options(exception, options)
      @params = options
      @params[:exception] = exception
      env = @params[:env]

      @params = @default_options.merge(@params)

      @params[:body] ||= {}
      @params[:body][:server] = Socket.gethostname
      @params[:body][:process] = $PROCESS_ID
      if defined?(Rails) && Rails.respond_to?(:root)
        @params[:body][:rails_root] = Rails.root
      end
      @params[:body][:exception] = {
        error_class: exception.class.to_s,
        message: exception.message.inspect,
        backtrace: exception.backtrace
      }

      unless env.nil?
        @params[:body][:data] = (env && env['exception_notifier.exception_data'] || {}).merge(@params[:data] || {})
        request = ActionDispatch::Request.new(env)

        request_items = {
          url: request.original_url,
          http_method: request.method,
          ip_address: request.remote_ip,
          parameters: request.filtered_parameters,
          timestamp: Time.current
        }

        @params[:body][:request] = request_items
        @params[:body][:session] = request.session
        @params[:body][:environment] = request.filtered_env
      end
      @params
    end

    def parse_options(options)
      @asana_api_key = options.fetch('asana_api_key', nil)
      @assignee = options.fetch('assignee', nil)
      @assignee_status = options.fetch('assignee_status', nil)
      @due_at  = options.fetch('due_at', nil)
      @hearted = options.fetch('hearted', nil)
      @projects = options.fetch('projects', [])
      @followers = options.fetch('followers', [])
      @workspace = options.fetch('workspace', nil)
      @memberships = options.fetch('memberships', [])
      @tags = options.fetch('tags', [])
    end

    def template_name
      template_path = @default_options.fetch('template_path', nil)
      template_path.nil? ? File.join(File.dirname(__FILE__), 'note_templates', 'asana_exception_notifier.text.erb') : template_path
    end

    def render_note_template(body)
      erb_template(template_name, body)
    end

    def body_object(body)
      {
        'assignee' => @assignee || 'me',
        'assignee_status' => @assignee_status || 'inbox',
        'due_at' => @due_at || Time.now.iso8601,
        'hearted' => @hearted,
        'projects' => @projects,
        'followers' => @followers,
        'workspace' => @workspace,
        'memberships' => @memberships,
        'tags' => @tags,
        'notes' => render_note_template(body),
        'name' => "[AsanaExceptionNotifier] #{@exception.class.inspect}"
      }
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
