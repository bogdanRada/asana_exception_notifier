require_relative './core'
# class used for connecting to github api and retrieves information about repository
#
# @!attribute callback
#   @return [Proc] The callback that is executed after the info is fetched from Github API
module AsanaExceptionNotifier
  module API
    class Asana < AsanaExceptionNotifier::API::Core
      # the base url to which the API will connect for fetching information about gems

      attr_reader :callback

      # Method used to instantiate an instance of RubygemsApi class with the params received from URL
      # @see #fetch_repo_data
      # @param [Hash] params The params received from URL
      # @param [Proc] callback The callback that is executed after the info is fetched from Github API
      # @return [void]
      def initialize(exception, options)
        @params = options.stringify_keys
        @exception = exception
        ensure_eventmachine_running do
          create_if_valid
        end
      end

      #  returns the logger used to log messages and errors
      #
      # @return [Logger]
      #
      # @api public
      def logger
        @logger ||= Logger.new($stdout)
      end

      # Method that checks if the gem is valid , and if it is will fetch the infromation about the gem
      # and pass the callback to the method . If is not valid the callback will be called with nil value
      # @see #valid?
      # @see #fetch_info
      #
      # @param [Lambda] callback The callback that needs to be executed after the information is downloaded
      # @return [void]
      def create_if_valid
        if valid?
          create_asana_task
        else
          logger.debug("data not valid!!")
        end
      end

      def em_request_options
        super.merge(
        head: {
          'Authorization' => "Bearer #{ENV['ASANA_API_KEY']}"
        },
        body: body_object
        )
      end

      def body_object
        {
          'assignee' => 9261272620298,
          'notes' => 'How are you today?',
          'followers' => [],
          'name' => 'Hello, world!',
          'workspace' => 498346170860
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

      # Method that is used to determine if the gem is valid by checking his name and version
      # THe name is required and the version need to checked if is stable or sintactically valid
      # @see  #gem_path
      #
      # @return [Boolean] Returns true if the gem is valid
      def valid?
        @exception.present?
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
end
