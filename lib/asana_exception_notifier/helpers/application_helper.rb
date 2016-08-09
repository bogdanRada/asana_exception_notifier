# frozen_string_literal: true
require_relative './heredoc_helper'
module AsanaExceptionNotifier
  # module that is used for formatting numbers using metrics
  module ApplicationHelper
    include AsanaExceptionNotifier::HeredocHelper
  # function that makes the methods incapsulated as utility functions

  module_function

    # returns the Hash containing as keys the permitted options and as values their default values
    #
    # @return [Hash] Returns the Hash containing as keys the permitted options and as values their default values
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

    # returns the expanded path of a file path
    #
    # @param [String] path The file path that will be expanded
    #
    # @return [String]  returns the expanded path of a file path
    def expanded_path(path)
      File.expand_path(path)
    end

    # checks to see if a path is valid
    # @see #template_path_exist
    # @param [String] path The file path that will be used
    #
    # @return [Boolean]  returns true if the path is valid otherwise false
    def path_is_a_template?(path)
      path.present? && template_path_exist(path)
    end

    # method used to extract the body of a IO object
    # @param [IO] io The IO object that will be used
    #
    # @return [String]  returns the body of the IO object by rewinding it and reading the content, or executes inspect if a exception happens
    def extract_body(io)
      return unless io.respond_to?(:rewind)
      io.rewind
      io.read
    rescue
      io.inspect
    end

    # method used to return the file and the path of a tempfile , along with the extension and the name of the file
    # @see #get_extension_and_name_from_file
    # @param [Tempfile] tempfile the temporary file that will be used
    #
    # @return [Hash] returns the the file and the path of a tempfile , along with the extension and the name of the file
    def tempfile_details(tempfile)
      file_details = get_extension_and_name_from_file(tempfile)
      {
        file: tempfile,
        path:  tempfile.path
      }.merge(file_details)
    end

    # Returns utf8 encoding of the msg
    # @param [String] msg
    # @return [String] Returns utf8 encoding of the msg
    def force_utf8_encoding(msg)
      msg.respond_to?(:force_encoding) && msg.encoding.name != 'UTF-8' ? msg.force_encoding('UTF-8') : msg
    end

    # returns the logger used to log messages and errors
    #
    # @return [Logger]
    def logger
      @logger ||= (defined?(Rails) && rails_logger.present? ? rails_logger : ExceptionNotifier.logger)
      @logger = @logger.present? ? @logger : Logger.new(STDOUT)
    end

    # returns the rails logger
    #
    # @return [Rails::Logger]
    def rails_logger
      Rails.logger
    end

    # returns the newly created thread
    # @see #run_new_thread
    # @see Thread#abort_on_exception
    # @param [Proc] &block the block that the new thread will execute
    #
    # @return [Thread] returns the newly created thread
    def ensure_thread_running(&block)
      Thread.abort_on_exception = true
      run_new_thread(&block)
    end

    # method used to log exceptions
    # @see #log_bactrace
    # @param [Exception] exception the exception that will be used
    #
    # @return [void]
    def log_exception(exception)
      logger.debug exception.inspect
      log_bactrace(exception) if exception.respond_to?(:backtrace)
    end

    # method used to log exception backtrace
    # @param [Exception] exception the exception that will be used
    #
    # @return [void]
    def log_bactrace(exception)
      logger.debug exception.backtrace.join("\n")
    end

    # method used to rescue exceptions
    # @see #rescue_interrupt
    # @see #log_exception
    #
    # @param [Hash] options Additional options used for returning values when a exception occurs, or empty string
    #
    # @return [String, nil, Object] Returns nil if the exception is a interrupt or a String empty if no value was provided in the options hash or the value from the options
    def execute_with_rescue(options = {})
      yield if block_given?
    rescue Interrupt
      rescue_interrupt
    rescue => error
      log_exception(error)
      options.fetch(:value, '')
    end

    # method used to rescue from interrupt and show a message
    #
    # @return [void]
    def rescue_interrupt
      `stty icanon echo`
      puts "\n Command was cancelled due to an Interrupt error."
    end

    # method used to create a thread and execute a block
    # @see Thread#new
    # @return [Thread] returns the newly created thread
    def run_new_thread
      Thread.new do
        yield if block_given?
      end.join
    end

    # returns the templates directory
    # @see #root
    # @return [String] returns the path to the templates directory
    def template_dir
      File.expand_path(File.join(root, 'templates'))
    end

    # returns true if file exists or false otherwise
    # @see File#exist?
    # @return [String] returns the path to the templates directory
    def template_path_exist(path)
      File.exist?(expanded_path(path))
    end

    def get_hash_rows(hash, rows = [], _prefix = '')
      hash.each do |key, value|
        if value.is_a?(Hash)
          get_object_rows(value, rows)
        else
          rows.push([key.inspect, escape(inspect_value(value).inspect)])
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
