# frozen_string_literal: true
require_relative '../helpers/application_helper'
# class used for connecting to connecting to Asana and creation of task and upload of archives
#
# @!attribute [r] initial_options
#   @return [Hash] THe initial options that the notifier received ( blank values are filtered )
# @!attribute [r] default_options
#   @return [Hash] The permitted_options that are merged with initial options ( blank values are filtered )
module ExceptionNotifier
  # module that is used for formatting numbers using metrics
  class AsanaNotifier < ExceptionNotifier::BaseNotifier
    include AsanaExceptionNotifier::ApplicationHelper

    # The initial options that the middleware was configured with
    # @return [Hash] THe initial options that the notifier received ( blank values are filtered )
    attr_reader :initial_options

    # The resulting options after merging with permitted_options and with initial_options
    # @return [Hash] The permitted_options that are merged with initial options ( blank values are filtered )
    attr_reader :default_options

    # Initializes the instance with the options from the configuration and
    # parses the options
    # @see #parse_options
    #
    # @param [options] options The options that can be set in the configuration block
    # @option params [String] :asana_api_key Your Personal Access Token from Asana. You can get it from https://app.asana.com/-/account_api.
    #   Please make sure you keep the token secret, and don't commit it in your repository.
    #   I suggest to put it into an environment variable and use it from that variable. ( This is REQUIRED )
    # @option params [Integer] :workspace The workspace ID where the task will be created. ( This is REQUIRED )
    # @option params [String, nil] :assignee Who will be assigned by default to the task that is going to be created. (Default: 'me').
    #   Can be disabled by setting it to NIL value
    # @option params [String, nil] :assignee_status Scheduling status of this task for the user it is assigned to.
    #   This field can only be set if the assignee is non-null. (Default: 'today'). Can be disabled by setting it to NIL value.
    # @option params [Time, nil] :due_at Date and time on which this task is due, or null if the task has no due time.
    #   This takes a UTC timestamp and should not be used together with due_on. Default ( Time.now.iso8601)
    # @option params [Time, nil] :due_on Date on which this task is due, or null if the task has no due date.
    #   This takes a date with YYYY-MM-DD format and should not be used together with due_at
    # @option params [Boolean, nil] :hearted True if the task is hearted by the authorized user, false if not (Default: false).
    # @option params [Array<String>] :hearts Array of users who will heart the task after creation. (Default: empty Array)
    # @option params [Array<String>] :projects Array of projects this task is associated with.
    #   At task creation time, this array can be used to add the task to many projects at once.(Default: empty array).
    # @option params [Array<String>] :followers Array of users following this task. (Default: empty array).
    # @option params [Array<String>] :memberships Array of projects this task is associated with and the section it is in.
    #   At task creation time, this array can be used to add the task to specific sections.
    #   Note that over time, more types of memberships may be added to this property.(Default: []).
    # @option params [Array<String>] :tags Array of tags associated with this task.
    #   This property may be specified on creation using just an array of existing tag IDs. (Default: false).
    # @option params [String] :notes More detailed, free-form textual information associated with the task. (Default: '')
    # @option params [String] :name Name of the task. This is generally a short sentence fragment that fits on a line in the UI for maximum readability.
    #   However, it can be longer. (Default: "[AsanaExceptionNotifier] %Exception Class Name%").
    # @option params [String] :template_path This can be used to override the default template when rendering the exception details with customized template.
    # @option params [Array<String>] :unsafe_options This can be used to specify options as strings that will be filtered from session and from request parameters
    #   ( The options will not be displayed in the HTML template)
    # @return [void]
    def initialize(options)
      super
      @initial_options = options.symbolize_keys.reject { |_key, value| value.blank? }
      parse_options(@initial_options)
    end

    # Returns the asana client that will be used to connect to Asana API and sets the configuration for the client
    # @see #faraday_configuration
    #
    # @return [Asana::Client] Returns the client used for connecting to Asana API's
    def asana_client
      @asana_client = Asana::Client.new do |config|
        config.authentication :access_token, asana_api_key
        config.debug_mode
        config.faraday_adapter :typhoeus
        faraday_configuration(config)
      end
    end

    # Returns the asana client that will be used to connect to Asana API
    # @param [Asana::Configuration] config The configuration object that will be used to set the faraday adapter options for connecting to API's
    #
    # @return [void]
    def faraday_configuration(config)
      config.configure_faraday do |conn|
        conn.request :url_encoded
        conn.use :instrumentation
        conn.response :logger
        conn.response :follow_redirects
      end
    end

    # When a exception is caught , this method will be called to publish to Asana the exception details
    # In order not to block the main thread, while we are parsing the exception, and constructing the template date,
    # and connecting to asana, this will spawn a new thread to ensure that the processing of the exception is deferred
    # from the main thread.
    # This method will also create the asana task after the processing of the exception and all the other data is gathered
    # by the AsanaExceptionNotifier::ErrorPage class
    #
    #
    # @see #ensure_thread_running
    # @see #execute_with_rescue
    # @see AsanaExceptionNotifier::ErrorPage#new
    # @see #create_asana_task
    #
    # @param [Exception] exception The exception that was caught by the middleware
    # @param [Hash] options Additional options that the middleware can send ( Default : {})
    #
    # @return [void]
    def call(exception, options = {})
      ensure_thread_running do
        execute_with_rescue do
          error_page = AsanaExceptionNotifier::ErrorPage.new(template_path, exception, options)
          create_asana_task(error_page) if active?
        end
      end
    end

    # Method that is used to fetch the Asana api key from the default_options
    #
    # @return [String, nil] returns the asana api key if was provided in configuration, or nil otherwise
    def asana_api_key
      @default_options.fetch(:asana_api_key, nil)
    end

    # Method that is used to fetch the workspace ID from the default_options
    #
    # @return [String, nil] returns the workspace ID if was provided in configuration, or nil otherwise
    def workspace
      @default_options.fetch(:workspace, nil)
    end

    # Method that is used to fetch the notes from the default_options
    #
    # @return [String, nil] returns the notes if they were provided in configuration, or nil otherwise
    def notes
      @default_options.fetch(:notes, nil)
    end

    # Method that is used to fetch the task name from the default_options
    #
    # @return [String, nil] returns the task name if was were provided in configuration, or nil otherwise
    def task_name
      @default_options.fetch(:name, nil)
    end

    # Method that is used by the ExceptionNotifier gem to check if this notifier can be activated.
    # The method checks if the asana api key and workspace ID were provided
    #
    # @return [Boolean] returns true if the asana api key and the workspace ID were provided in the configuration, otherwise false
    def active?
      asana_api_key.present? && workspace.present?
    end

    # Method that retrieves the template_path for rendering the exception details
    #
    # @return [String, nil] returns the template_path if was were provided in configuration, or nil otherwise
    def template_path
      @default_options.fetch(:template_path, nil)
    end

  private

    # Method that parses the options, and rejects keys that are not permitted , and values that are blank
    # @see #permitted_options
    #
    # @param [Hash] options Additional options that are merged in the default options
    #
    # @return [void]
    def parse_options(options)
      options = options.reject { |key, _value| !permitted_options.key?(key) }
      @default_options = permitted_options.merge(options).reject { |_key, value| value.blank? }
    end

    # Method that tries to render a custom notes template or the default notes template
    # @see #path_is_a_template
    # @see #expanded_path
    # @see AsanaExceptionNotifier::ErrorPage#render_template
    #
    # @param [AsanaExceptionNotifier::ErrorPage] error_page the Erorr page class that is responsible for rendering the exception templates
    #
    # @return [String] The content of the notes templates after being rendered
    def note_content(error_page)
      if path_is_a_template?(notes)
        error_page.render_template(expanded_path(notes))
      else
        notes.present? ? notes : error_page.render_template(File.join(template_dir, 'notes.text.erb'))
      end
    end

    # Returns the customized task name ( if any provided ) or the default one
    #
    # @param [AsanaExceptionNotifier::ErrorPage] error_page the Erorr page class that is responsible handling exceptions
    #
    # @return [String] The task name that will be used when creating the asana task
    def task_name_content(error_page)
      task_name.present? ? task_name : "[AsanaExceptionNotifier] #{error_page.exception_data[:message]}"
    end

    # Builds all the options needed for creating a asana task
    # @see #task_name_content
    # @see #note_content
    #
    # @param [AsanaExceptionNotifier::ErrorPage] error_page the Erorr page class that is responsible handling exceptions
    #
    # @return [void]
    def build_request_options(error_page)
      @default_options.except(:asana_api_key, :template_path).merge(
        name: task_name_content(error_page),
        notes:  note_content(error_page),
        workspace: workspace
      ).symbolize_keys!
    end

    # Method that is used to create the asana task and upload the log files to the task
    # @see Asana::Resources::Task#create
    # @see #build_request_options
    # @see #upload_log_file_to_task
    #
    # @param [AsanaExceptionNotifier::ErrorPage] error_page the Erorr page class that is responsible handling exceptions
    #
    # @return [void]
    def create_asana_task(error_page)
      task = asana_client.tasks.create(build_request_options(error_page))
      ensure_thread_running do
        upload_log_file_to_task(error_page, task)
      end
    end

    # Method that is used to fetch all the needed archives that will be uploaded to the task
    # and upload each of them
    # @see AsanaExceptionNotifier::ErrorPage#fetch_all_archives
    # @see #upload_archive
    #
    # @param [AsanaExceptionNotifier::ErrorPage] error_page the Erorr page class that is responsible handling exceptions
    # @param [Asana::Resources::Task] task the task that was created, and needed to upload archives to the task
    #
    # @return [void]
    def upload_log_file_to_task(error_page, task)
      archives = error_page.fetch_all_archives
      archives.each do |zip|
        upload_archive(zip, task)
      end
    end

    # Method that is used to upload an archive to a task, The file will be deleted after the upload finishes
    # @see Asana::Resources::Task#attach
    #
    # @param [String] zip the file path to the archive that will be uploaded
    # @param [Asana::Resources::Task] task the task that was created, and needed to upload archives to the task
    #
    # @return [void]
    def upload_archive(zip, task)
      return if task.blank?
      task.attach(
        filename: zip,
        mime: 'application/zip'
      )
      FileUtils.rm_rf([zip])
    end
  end
end
