# frozen_string_literal: true
require_relative '../helpers/application_helper'
require_relative './unsafe_filter'
module AsanaExceptionNotifier
  # class used for rendering the template for exception
  #
  # @!attribute template_path
  #   @return [Hash] The template_path that will be used to render the exception details
  # @!attribute exception
  #   @return [Hash] The exception that will be parsed
  # @!attribute options
  #   @return [Hash] Additional options sent by the middleware that will be used to provide additional informatio
  # @!attribute template_details
  #   @return [Hash] The name and the extension of the template
  # @!attribute env
  #   @return [Hash] The environment that was sent by the middleware or the ENV variable
  # @!attribute request
  #   @return [Hash] The request that is built based on the environment, in order to provide more information
  # @!attribute tempfile
  #   @return [Hash] The archive that will be created and then splitted into multiple archives (if needed )
  # @!attribute template_params
  #   @return [Hash] The template params that will be sent to the template
  class ErrorPage
    include AsanaExceptionNotifier::ApplicationHelper

    attr_reader :template_path, :exception, :options, :template_details, :env, :request, :tempfile, :template_params

    # Initializes the instance with the template path that will be used to render the template,
    # the exception caught by the middleware and additional options sent by the middleware
    # @see #html_template
    # @see #setup_template_details
    # @see #parse_exception_options
    #
    # @param [String] template_path The template_path that will be used to render the exception details
    # @param [Exception] exception The exception that was caught by the middleware
    # @param [Hash] options Additional options that the middleware can send ( Default : {})
    #
    # @return [void]
    def initialize(template_path, exception, options)
      @exception = exception
      @options = options.symbolize_keys
      html_template(template_path)
      @template_details = setup_template_details
      @env = (@options[:env] || ENV.to_h).stringify_keys
      @request = action_dispatch? ? ActionDispatch::Request.new(@env) : Rack::Request.new(@env)
      @timestamp = Time.now
      parse_exception_options
    end

    # Initializes the instance with the template path that will be used to render the template,
    # the exception caught by the middleware and additional options sent by the middleware
    # @see #path_is_a_template
    # @see #expanded_path
    # @see #template_dir
    #
    # @param [String] path The template_path that will be used to render the exception details
    #
    # @return [void]
    def html_template(path)
      @template_path = if path_is_a_template?(path)
                         expanded_path(path)
                       else
                         File.join(template_dir, 'exception_details.html.erb')
                       end
    end

    # Returns true or false if ActionDispatch is available
    #
    # @return [Boolean] returns true if ActionDispatch::Request is defined, false otherwise
    def action_dispatch?
      defined?(ActionDispatch::Request)
    end

    # Gets the name and the extension of the template path, if was provided custom
    # ( this is needed in case someone wants something else than ERB template , since Tilt can support multiple formats)
    # @see #get_extension_and_name_from_file
    #
    # @return [Hash] Returns a hash containing the name and the extension of the template
    def setup_template_details
      template_extension = @template_path.scan(/\.(\w+)\.?(.*)?/)[0][0]
      get_extension_and_name_from_file(@template_path).merge(
        template_extension: template_extension
      )
    end

    # :reek:TooManyStatements: { max_statements: 10 }
    #
    # Fetches information about request, exception, environment and other additional information needed for the template
    # @see #fetch_basic_info
    # @see #exception_data
    # @see #setup_env_params
    # @see #filter_params
    # @see #session
    # @see #request_params
    # @see Rack::Request#cookies
    # @see ActionDispatch::Request#filtered_env
    # @see ActionDispatch::Request#filtered_parameters
    #
    # @return [Hash] Returns a hash containing all the information gathered about the exception, including env, cookies, session, and other additional information
    def parse_exception_options
      @template_params ||= {
        basic_info: fetch_basic_info,
        exception: @exception,
        request: @request,
        env: @request.respond_to?(:filtered_env) ? @request.filtered_env : @env,
        data: (@env.blank? ? {} : @env.fetch(:'exception_notifier.exception_data', {})).merge(@options[:data] || {}),
        exception_data: exception_data,
        request_data: setup_env_params,
        parameters: @request.respond_to?(:filtered_parameters) ? filter_params(@request.filtered_parameters) : filter_params(request_params),
        session: filter_params(session.respond_to?(:to_hash) ? session.to_hash : session.to_h),
        cookies: filter_params(@request.cookies.to_h)
      }.merge(@options).reject { |_key, value| value.blank? }
    end

    # returns the session from the request, (either from ActionDispatch or from Rack)
    #
    # @return [Hash] Returns the session of the request
    def session
      @request.session
    end

    # returns basic information about the system, like hostname, rails root directory, the process Id, the uname , the timestamp, and the Program name
    # @see Socket#gethostname
    # @see Rails::root
    # @see Sys::Uname#uname
    #
    # @return [Hash] Returns basic information about the system, like hostname, and other additionl information
    def fetch_basic_info
      {
        server:  Socket.gethostname,
        rails_root: defined?(Rails) ? Rails.root : nil,
        process: $PROCESS_ID,
        uname: Sys::Uname.uname,
        timestamp: @timestamp,
        pwd:  File.expand_path($PROGRAM_NAME)
      }
    end

    # returns information about the exception, like the class name, the message, the backtrace, the cause ( if gem 'cause' is used)
    #
    # @return [Hash] Returns information about the exception, like the class name, the message, the backtrace, the cause ( if gem 'cause' is used)
    def exception_data
      exception_service.merge(
        error_class: @exception.class.to_s,
        message:  @exception.respond_to?(:message) ? @exception.message : exception.inspect,
        backtrace: @exception.respond_to?(:backtrace) ? (@exception.backtrace || []).join("\n") : nil,
        cause: @exception.respond_to?(:cause) ? @exception.cause : nil
      )
    end

    # returns the instance variables defined by the exception, useful when using custom exceptions
    #
    # @return [Hash] Returns information about the instance variables defined by the exception, useful when using custom exceptions
    def exception_service
      hash = {}
      @exception.instance_variables.select do |ivar|
        attr_value = @exception.instance_variable_get(ivar)
        hash[ivar.to_s] = attr_value if attr_value.present?
      end
      hash
    end

    # returns information about URL, referer, http_method used, ip address and user agent
    #
    # @return [Hash] Returns information about URL, referer, http_method used, ip address and user agent
    def setup_env_params
      {
        url: @request.respond_to?(:original_url) ? @request.original_url : @request.path_info,
        referrer: @request.referer,
        http_method: action_dispatch? ? @request.method : @request.request_method,
        ip_address:  @request.respond_to?(:remote_ip) ? @request.remote_ip : @request.ip,
        user_agent: @request.user_agent
      }
    end

    # Filters sensitive information from parameters so that they won't get leaked into the template
    # @see AsanaExceptionNotifier::UnsafeFilter#new
    #
    # @return [Hash] Returns the information filtered , by using custom filters or the default one
    def filter_params(params)
      AsanaExceptionNotifier::UnsafeFilter.new(params, @options.fetch(:unsafe_options, [])).arguments
    end

    # returns the params sent with the initial request
    #
    # @return [Hash] Returns the params sent with the initial request
    def request_params
      @request.params
    rescue
      {}
    end

    # returns the names that will be used on the table header in the template
    # @see #fieldsets
    # @see #link_helper
    #
    # @return [String] returns the names that will be used on the table header in the template
    def fieldsets_links
      fieldsets.map { |key, _value| link_helper(key.to_s) }.join(' | ')
    end

    # returns fieldsets that will be showned in the template on separate table
    # @see #mount_tables_for_fieldsets
    #
    # @return [Array<Hash>] returns fieldsets that will be showned in the template on separate table
    def fieldsets
      @fieldsets ||= mount_tables_for_fieldsets
      @fieldsets
    end

    # returns fieldsets that will be showned in the template on separate table
    # @see #fetch_fieldsets
    # @see #mount_table_for_hash
    #
    # @return [Hash] returns the tables that will be used to render on the template as a Hash
    def mount_tables_for_fieldsets
      hash = fetch_fieldsets
      hash.each do |key, value|
        html = mount_table_for_hash(value)
        hash[key] = html if html.present?
      end
      hash
    end

    # iterates over the template params and sets the fieldsets that will be will be displayed in tables
    # @see #set_fieldset_key
    #
    # @param [Hash] hash the hash that will contain the data will be displayed in tables
    #
    # @return [void]
    def build_template_params_hash(hash)
      @template_params.each_with_parent do |parent, key, value|
        next if value.blank? || key.blank?
        parent_name = set_fieldset_key(hash, parent, 'system_info')
        hash[parent_name][key] = value
      end
    end

    # builds the template params that wil be used to construct the fieldsets and sorts them alphabetically
    # @see #build_template_params_hash
    #
    # @param [Hash] hash the hash that will contain the template params that wil be used to construct the fieldsets sorted alphabetically
    #
    # @return [Hash] returns the hash that will contain the template params that wil be used to construct the fieldsets sorted alphabetically
    def fetch_fieldsets(hash = {})
      build_template_params_hash(hash)
      hash.keys.map(&:to_s).sort
      hash
    end

    # adds the fieldsets and the fieldsets_links to the template params
    # @see #fieldsets
    # @see #fieldsets_links
    #
    # @return [void]
    def setup_template_params_for_rendering
      @template_params[:fieldsets] = fieldsets
      @template_params[:fieldsets_links] = fieldsets_links
    end

    # renders the template or the default template with the template params
    # @see #execute_with_rescue
    # @see #setup_template_params_for_rendering
    #
    # @return [void]
    def render_template(template = nil)
      execute_with_rescue do
        current_template = template.present? ? template : @template_path
        setup_template_params_for_rendering
        Tilt.new(current_template).render(self, @template_params.stringify_keys)
      end
    end

    # Creates a archive from the render_template outpout and returns the filename and the path of the file
    # @see Tempfile#new
    # @see Tempfile#write
    # @see ObjectSpace#undefine_finalizer
    # @see Tempfile#close
    # @see #tempfile_details
    #
    # @return [Array<String>] returns an array containing the filename as first value, and the path to the tempfile created as second value
    def create_tempfile(output = render_template)
      tempfile = Tempfile.new([SecureRandom.uuid, ".#{@template_details[:template_extension]}"], encoding: 'utf-8')
      tempfile.write(output)
      ObjectSpace.undefine_finalizer(tempfile) # force garbage collector not to remove automatically the file
      tempfile.close
      tempfile_details(tempfile).slice(:filename, :path).values
    end

    # Executes the fetch_archives and returns the result or empty array in case of exception
    # @see #fetch_archives
    #
    # @return [Array] returns an array with file paths to the created archives
    def fetch_all_archives
      fetch_archives
    rescue
      []
    end

    # Creates the archive, compresses it , and then removes the temporary file and splits the archive if needed
    # @see #create_tempfile
    # @see #compress_files
    # @see #remove_tempfile
    # @see #split_archive
    #
    # @return [Array] returns an array with file paths to the created archives
    def fetch_archives(output = render_template)
      return [] if output.blank?
      filename, path = create_tempfile(output)
      archive = compress_files(File.dirname(path), filename, [expanded_path(path)])
      remove_tempfile(path)
      split_archive(archive, "part_#{filename}", 1024 * 1024 * 100)
    end

    # If DEBUG_ASANA_TEMPLATE is present this method will only log the path , otherwise will remove the file.
    #
    # @return [void]
    def remove_tempfile(path)
      if ENV['DEBUG_ASANA_TEMPLATE']
        logger.debug(path)
      else
        FileUtils.rm_rf([path])
      end
    end
  end
end
