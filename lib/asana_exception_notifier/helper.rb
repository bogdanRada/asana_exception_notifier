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

    def multi_request_manager
      @multi_manager ||= EventMachine::MultiRequest.new
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

    # Returns utf8 encoding of the msg
    # @param [String] msg
    # @return [String] ReturnsReturns utf8 encoding of the msg
    def force_utf8_encoding(msg)
      msg.respond_to?(:force_encoding) && msg.encoding.name != 'UTF-8' ? msg.force_encoding('UTF-8') : msg
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
        logger.debug '[AsanaExceptionNotifier]: Error during event loop :'
        logger.debug "[AsanaExceptionNotifier]: #{log_exception(error)}"
      end
    end

    def log_exception(exception)
      logger.debug exception.inspect
      logger.debug exception.backtrace.join("\n")
    end

    def run_eventmachine(&_block)
      EM.run do
        EM::HttpRequest.use AsanaExceptionNotifier::RequestMiddleware if ENV['DEBUG_ASANA_EXCEPTION_NOTIFIER']
        yield
      end
    end

    def template_dir
      File.expand_path(File.join(File.dirname(__FILE__), 'note_templates'))
    end

    def default_template_path
      File.join(template_dir, 'asana_exception_notifier.html.erb')
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

    # returns the root path of the gem
    #
    # @return [void]
    #
    # @api public
    def root
      File.expand_path(File.dirname(File.dirname(__dir__)))
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

    def create_upload_file_part(file)
      Part.new(name: 'file',
               body: force_utf8_encoding(File.read(file)),
               filename: File.basename(file),
               content_type: 'application/zip'
              )
    end

    def multipart_file_upload_details(file)
      boundary = "---------------------------#{rand(10_000_000_000_000_000_000)}"
      body = MultipartBody.new([create_upload_file_part(file)], boundary)
      file_upload_request_options(boundary, body, file)
    end

    def file_upload_request_options(boundary, body, file)
      {
        body: body.to_s,
        head:
        {
          'Content-Type' => "multipart/form-data;boundary=#{boundary}",
          'Content-Length' => File.size(file),
          'Expect' => '100-continue'
        }
      }
    end

    def get_response_from_request(http, options)
      http_response = http.respond_to?(:response) ? http.response : http.responses[:callback]
      options[:multi_request].present? && http_response.is_a?(Hash) ? http_response.values.map(&:response) : http_response
    end

    def split_archive(archive, partial_name, segment_size)
      indexes = Zip::File.split(archive, segment_size, true, partial_name)
      archives = Array.new(indexes) do |index|
        File.join(File.dirname(archive), "#{partial_name}.zip.#{format('%03d', index + 1)}")
      end
      archives.blank? ? [archive] : archives
    end

    def create_archive(directory, name)
      archive = File.join(directory, name + '.zip')
      archive_dir = File.dirname(archive)
      FileUtils.mkdir_p(archive_dir) unless File.directory?(archive_dir)
      FileUtils.rm archive, force: true if File.exist?(archive)
      archive
    end
  end
end
