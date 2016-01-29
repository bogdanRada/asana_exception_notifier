require_relative './request_middleware'
module AsanaExceptionNotifier
  # module that is used for formatting numbers using metrics
  module Helper
  # function that makes the methods incapsulated as utility functions

  module_function

    def permitted_options
      {
        asana_api_key:  nil,
        workspace: nil,
        assignee:  nil,
        assignee_status: nil,
        due_at: nil,
        due_on: nil,
        hearted: false,
        hearts: [],
        projects: [],
        followers: [],
        memberships: [],
        tags: [],
        notes: '',
        name: '',
        template_path: default_template_path
      }
    end

    def extract_body(env)
      return if env.blank? || !env.is_a?(Hash)
      io = env['rack.input']
      io.rewind if io.respond_to?(:rewind)
      io.read
    end

    def show_hash_content(hash)
      hash.map do |key, value|
        value.is_a?(Hash) ? show_hash_content(value) : ["#{key}:", value]
      end.join("\n  ")
    end

    def tempfile_details(tempfile)
      file_details = get_extension_and_name_from_file(tempfile)
      {
        file: tempfile,
        path:  tempfile.path
      }.merge(file_details)
    end

    #  returns the logger used to log messages and errors
    #
    # @return [Logger]
    #
    # @api public
    def logger
      @logger ||= defined?(Rails) ? Rails.logger : ExceptionNotifier.logger
    end

    def ensure_eventmachine_running(&block)
      register_em_error_handler
      run_eventmachine(&block)
    end

    def register_em_error_handler
      EM.error_handler do |error|
        logger.debug "AsanaExceptionNotifier: Error during event loop : #{error.inspect}"
        logger.debug "AsanaExceptionNotifier:#{error.backtrace.join("\n")}"
      end
    end

    def run_eventmachine(&_block)
      EM.run do
        EM::HttpRequest.use AsanaExceptionNotifier::RequestMiddleware if ENV['DEBUG_ASANA_EXCEPTION_NOTIFIER']
        yield
      end
    end

    def default_template_path
      File.join(File.dirname(__FILE__), 'note_templates', 'asana_exception_notifier.html.erb')
    end

    def template_path_exist(path)
      return path if File.exist?(path)
      fail ArgumentError, "file #{path} doesn't exist"
    end

    def max_length(rows, index)
      value = rows.max_by { |array| array[index].to_s.size }
      value.is_a?(Array) ? value[index] : value
    end

    def get_hash_rows(hash, rows = [], prefix = '')
      hash.each do |key, value|
        if value.is_a?(Hash)
          get_hash_rows(value, rows, "#{key}.")
        else
          rows.push(["#{prefix}#{key}", value])
        end
      end
      rows
    end

    def get_extension_and_name_from_file(tempfile)
      path = tempfile.respond_to?(:path) ? tempfile.path : tempfile
      pathname = Pathname.new(path)
      extension = pathname.extname
      {
        extension: extension,
        filename: File.basename(pathname, extension),
        file_path: path
      }
    end

    def setup_em_options(options)
      options.symbolize_keys!
      options[:em_request] ||= {}
      options
    end

    # Mount table for hash, using name and value and adding a name_value class
    # to the generated table.
    #
    def mount_table_for_hash(hash, _options = {})
      return if hash.blank?
      get_hash_rows(hash)
    end
  end
end
