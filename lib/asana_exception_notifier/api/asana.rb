require_relative './core'
# class used for connecting to github api and retrieves information about repository
#
# @!attribute callback
#   @return [Proc] The callback that is executed after the info is fetched from Github API
module ExceptionNotifier
  class AsanaNotifier < ExceptionNotifier::BaseNotifier
    include AsanaExceptionNotifier::API::Core
    # the base url to which the API will connect for fetching information about gems

    def initialize(options)
      super
      parse_options(options)
    end

    # Method used to instantiate an instance of RubygemsApi class with the params received from URL
    # @see #fetch_repo_data
    # @param [Hash] params The params received from URL
    # @param [Proc] callback The callback that is executed after the info is fetched from Github API
    # @return [void]
    def call(exception, options={})
      @params = options.stringify_keys
      @exception = exception
      ensure_eventmachine_running do
        create_asana_task if !@exception.nil? && !@exception.empty?
      end
    end

    private


    def parse_options(options)
      @asana_api_key = options.fetch('asana_api_key', nil)
      @assignee = options.fetch('assignee', nil)
      @assignee_status = options.fetch('assignee_status', nil)
      @due_on  = options.fetch('due_on', nil)
      @due_at  = options.fetch('due_at', nil)
      @hearted = options.fetch('hearted', nil)
      @projects = options.fetch('projects', [])
      @followers = options.fetch('followers', [])
      @workspace = options.fetch('workspace', nil)
      @memberships = options.fetch('memberships', [])
      @tags = options.fetch('tags', [])
    end

    def active?
      !@asana_api_key.nil? && !@workspace.nil?
    end

    #  returns the logger used to log messages and errors
    #
    # @return [Logger]
    #
    # @api public
    def logger
      @logger ||= ExceptionNotifier.logger
    end

    def em_request_options
      super.merge(
      head: {
        'Authorization' => "Bearer #{@asana_api_key}"
      },
      body: body_object
      )
    end

    def body_object
      {
        'assignee' => @assignee,
        'assignee_status' => @assignee_status,
        'due_on' => @due_on,
        'due_at' => @due_at,
        'hearted' => @hearted,
        'projects' => @projects,
        'followers' => @followers,
        'workspace' => @workspace,
        'memberships' => @memberships,
        'tags' => @tags,
        'notes' => 'How are you today?',
        'name' => 'Hello, world!'
      }
    end

    # This method fetches data from Github api and returns the size in
    #
    # @return [void]
    def create_asana_task
      fetch_data('https://app.asana.com/api/1.0/tasks', 'http_method' => 'post') do |http_response|
        logger.debug(http_response)
      end
    end


    # Method that is executed after we receive an successful response.
    # This method willt try and parse the response as JSON, and if the
    # parsing fails will return  nil
    #
    # @param [String] response The response received after successful HTTP request
    # @return [Hash, nil] Returns the response parsed to JSON, and if the parsing fails returns nil
    def callback_before_success(response)
      parse_json(response)
    end
  end

end
