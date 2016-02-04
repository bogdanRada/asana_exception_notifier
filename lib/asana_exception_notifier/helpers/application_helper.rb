require_relative './heredoc_helper'
module AsanaExceptionNotifier
  # module that is used for formatting numbers using metrics
  module ApplicationHelper
    include AsanaExceptionNotifier::HeredocHelper
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
        template_path: nil,
        unsafe_options: []
      }
    end

    def expanded_path(path)
      File.expand_path(path)
    end

    def path_is_a_template?(path)
      path.present? && template_path_exist(expanded_path(path))
    end

    def multi_request_manager
      @multi_manager ||= EventMachine::MultiRequest.new
    end

    def extract_body(io)
      return unless io.respond_to?(:rewind)
      io.rewind
      io.read
    rescue
      io.inspect
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
      Thread.abort_on_exception = true
      register_em_error_handler
      run_em_reactor(&block)
    end

    def register_em_error_handler
      EM.error_handler do |error|
        logger.debug '[AsanaExceptionNotifier]: Error during event loop :'
        logger.debug "[AsanaExceptionNotifier]: #{log_exception(error)}"
      end
    end

    def log_exception(exception)
      logger.debug exception.inspect
      log_bactrace(exception) if exception.respond_to?(:backtrace)
    end

    def log_bactrace(exception)
      logger.debug exception.backtrace.join("\n")
    end

    def execute_with_rescue(options = {})
      yield if block_given?
    rescue Interrupt
      rescue_interrupt
    rescue => error
      log_exception(error)
      options.fetch(:value, '')
    end

    def rescue_interrupt
      `stty icanon echo`
      puts "\n Command was cancelled due to an Interrupt error."
    end

    def run_em_reactor
      Thread.new do
        EM.run do
          EM.defer proc { yield if block_given? }
        end
      end.join
    end

    def template_dir
      File.expand_path(File.join(root, 'templates'))
    end

    def template_path_exist(path)
      File.exist?(path)
    end

    def get_hash_rows(hash, rows = [], prefix = '')
      hash.each do |key, value|
        if value.is_a?(Hash)
          get_hash_rows(value, rows, key)
        else
          rows.push(["#{prefix}#{key}".inspect, escape(inspect_value(value).inspect)])
        end
      end
      rows
    end

    def inspect_value(value)
      value.is_a?(IO) ? extract_body(value) : value
    end

    def escape(text)
      text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    def set_fieldset_key(links, prefix, default)
      prefix_name = prefix.present? ? prefix : default
      links[prefix_name] ||= {}
      prefix_name
    end

    def parse_fieldset_value(options)
      value = options[:value]
      value.is_a?(Hash) ? value.reject! { |_new_key, new_value| new_value.is_a?(Hash) } : value
    end

    # Mount table for hash, using name and value and adding a name_value class
    # to the generated table.
    #
    def mount_table_for_hash(hash, options = {})
      return if hash.blank?
      rows = get_hash_rows(hash, options.fetch('rows', []))
      mount_table(rows.unshift(%w(Name Value)), { class: 'name_values' }.merge(options))
    end

    def hash_to_html_attributes(hash)
      hash.map do |key, value|
        "#{key}=\"#{value.gsub('"', '\"')}\" "
      end.join(' ')
    end

    def remove_blank(args)
      args.delete_if { |_key, value| value.blank? } if args.is_a?(Hash)
      args.reject!(&:blank?) if args.is_a?(Array)
    end

    def get_table_headers(header)
      header.map { |name| escape(name.to_s.humanize) }.join('</th><th>')
    end

    def get_table_rows(array)
      array.map { |name| "<tr><td>#{name.join('</td><td>')}</td></tr>" }.join
    end

    # returns the root path of the gem
    #
    # @return [void]
    #
    # @api public
    def root
      File.expand_path(File.dirname(__dir__))
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

    def create_upload_file_part(file)
      Part.new(name: 'file',
               body: force_utf8_encoding(File.read(file)),
               filename:  file,
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

    def get_response_from_request(http, _options)
      http.respond_to?(:response) ? http.response : http.responses
    end

    def get_multi_request_values(http_response, key)
      response_method = key.to_s == 'callback' ? 'response' : 'error'
      http_response[key.to_sym].values.map { |request| request.send(response_method) }.reject(&:blank?)
    end

    def split_archive(archive, partial_name, segment_size)
      indexes = Zip::File.split(archive, segment_size, true, partial_name)
      archives = Array.new(indexes) do |index|
        File.join(File.dirname(archive), "#{partial_name}.zip.#{format('%03d', index + 1)}")
      end if indexes.present?
      archives.blank? ? [archive] : archives
    end

    def compress_files(directory, name, files)
      archive = create_archive(directory, name)
      ::Zip::File.open(archive, Zip::File::CREATE) do |zipfile|
        add_files_to_zip(zipfile, files)
      end
      archive
    end

    def add_files_to_zip(zipfile, files)
      files.each do |file|
        zipfile.add(file.sub(File.dirname(file) + '/', ''), file)
      end
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
