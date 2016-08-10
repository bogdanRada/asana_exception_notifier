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
    #
    # @see File#exist?
    #
    # @return [String] returns the path to the templates directory
    def template_path_exist(path)
      File.exist?(expanded_path(path))
    end

    # Method used to construct table rows from a Hash, by constructing an array of arrays with two elements ( First is the key and the value )
    # This is useful for constructing the table, the number of elements in a array means the number of columns of the table
    #
    # This is a recursive function if the Hash contains other Hash values.
    # @see #inspect_value
    #
    # @param [Hash] hash the Hash that wil be used to construct the array of arrays with two columns
    # @param [Array<Array<String>>] rows This is the array that will contain the result ( Default: empty array).
    #
    # @return [Array<Array<String>>] Returns an array of arrays (with two elements), useful for printing tables from a Hash
    def get_hash_rows(hash, rows = [])
      hash.each do |key, value|
        if value.is_a?(Hash)
          get_hash_rows(value, rows)
        else
          rows.push([inspect_value(key), inspect_value(value)])
        end
      end
      rows
    end

    # Method used to inspect a value, by checking if is a IO object, and in that case extract the body from the IO object,
    # otherwise will just use the "inpspect" method. The final result will be escaped so that it can be printed in HTML
    # @see #extract_body
    # @see #escape
    #
    # @param [#inspect, #to_s] value The value that will be inspected and escaped
    #
    # @return [String] Returns the value inspected and escaped
    def inspect_value(value)
      inspected_value = value.is_a?(IO) ? extract_body(value) : value.inspect
      escape(inspected_value)
    end

    # Method used to escape a text by escaping some characters like '&', '<' and '>' , which could affect HTML format
    # @param [#to_s] text The text that will be escaped
    #
    # @return [String] Returns the text HTML escaped
    def escape(text)
      text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    # Method used to set the prefix name on the links Hash, this is needed when building a table from a hash,
    # because when going through the first level of a Hash, we don't have a title of what this level is about ,
    # but deeper levels can have a title, by using the key to which the value is associated
    #
    # Because of this this method expects a default name, in case the prefix is blank
    # @param [Hash] links The links Hash object that will be used to print the fieldsets links in HTML template
    # @param [String] prefix The prefix that will be set as key on the links Hash and associated with a empty Hash , if the links hash does not have this key yet
    # @param [String] default The default prefix that will be set as key on the links Hash and associated with a empty Hash , if the links hash does not have this key yet and the prefix is blank
    #
    # @return [String] Returns the prefix that was used to set the key on the links Hash, either the 'prefix' variable or the 'default' variable
    def set_fieldset_key(links, prefix, default)
      prefix_name = prefix.present? ? prefix : default
      links[prefix_name] ||= {}
      prefix_name
    end

    # This method is used to mount a table from a hash. After the table is mounted, since the generated table has two columns ( Array of array with two elements),
    # We're going to prepend to this generated table a array with two elements (Name and Value) , which will be the columns headers on the generated table .
    # We also will add a HTML class attribute to the generated table ('name_values')
    # @see #get_hash_rows
    # @see #mount_table
    #
    # @param [Hash] hash The Hash that will be used to mount a table from the keys and values
    # @param [Hash] options Additional options that will be used to set HTML attributes on the generated table
    #
    # @return [String] Returns the HTML table generated as a string, which can be printed anywhere
    def mount_table_for_hash(hash, options = {})
      return if hash.blank?
      rows = get_hash_rows(hash, options.fetch('rows', []))
      mount_table(rows.unshift(%w(Name Value)), { class: 'name_values' }.merge(options))
    end

    # This method receives a options list which will be used to construct a string which will be used to set HTML attributes on a HTML element
    #
    # @param [Hash] hash The Hash that will be used to construct the string of HTML attributes
    #
    # @return [String] Returns the string of HTML attributes which can be used on any HTML element
    def hash_to_html_attributes(hash)
      hash.map do |key, value|
        "#{key}=\"#{value.gsub('"', '\"')}\" "
      end.join(' ')
    end

    # This method can receive either a Hash or an Array, which will be filtered of blank values
    #
    # @param [Hash, Array] args The Hash or the array which will be used for filtering blank values
    #
    # @return [Hash, Array] Returns the Hash or the array received , filtered of blank values
    def remove_blank(args)
      args.delete_if { |_key, value| value.blank? } if args.is_a?(Hash)
      args.reject!(&:blank?) if args.is_a?(Array)
    end

    # This method is used to construct the Th header elements that can be used on HTML table from a array, by humanizing and escaping the values
    # @see #escape
    #
    # @param [#map] header the Header array that will be used to construct the Th header elements that can be used on HTML table
    #
    # @return [String] Returns the HTML th elements constructed from the array , that can be used on a HTML table
    def get_table_headers(header)
      header.map { |name| escape(name.to_s.humanize) }.join('</th><th>')
    end

    # This method is to construct a HTML row for each value that exists in the array, each value from the array is a array itself.
    # The row is constructed by joining the values from each array with td element, so the result will be a valid HTML row element
    # The final result is a concatenation of multiple row elements that can be displayed inside a tbody element from a HTML table
    # @param [#map] array The Array that will be used to construct the inner rows of a HTML table
    #
    # @return [String] Returns a concatenation of multiple HTML tr and td elements that are in fact the inner rows of HTML table
    def get_table_rows(array)
      array.map { |name| "<tr><td>#{name.join('</td><td>')}</td></tr>" }.join
    end

    # returns the root path of the gem ( the lib directory )
    #
    # @return [String] Returns the root path of the gem ( the lib directory )
    def root
      File.expand_path(File.dirname(__dir__))
    end

    # returns the extension of the file, the filename and the file path of the Tempfile file received as argument
    # @param [Tempfile] tempfile the Tempfile that will be used
    #
    # @return [Hash] returns the extension of the file, the filename and the file path of the Tempfile file received as argument
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

    # Splits a archive into multiple archives if the size of the archive is greater than the segment_size received as argument
    # and returns a array that contains the paths to each of the archives that were resulted after splitting
    # @param [::Zip::File] archive the archive that will try to be splitted
    # @param [String] partial_name the partial name that will be used when splitting the archives
    # @param [Integer] segment_size the size that will be used for splitting the archive
    #
    # @return [Array<String>] returns a array that contains the paths to each of the archives that were resulted after splitting
    def split_archive(archive, partial_name, segment_size)
      indexes = Zip::File.split(archive, segment_size, true, partial_name)
      archives = Array.new(indexes) do |index|
        File.join(File.dirname(archive), "#{partial_name}.zip.#{format('%03d', index + 1)}")
      end if indexes.present?
      archives.blank? ? [archive] : archives
    end

    # This method receives multiple files, that will be added to a archive and will return the resulting archive
    # @see #prepare_archive_creation
    # @see #add_files_to_zip
    # @see Zip::File::open
    #
    # @param [String] directory The directory where the archive will be created
    # @param [String] name The name of the archive ( without the .zip extension )
    # @param [Array<File>] files The Array of files that will be added to the archive
    #
    # @return [Zip::File] returns the archive that was created after each of the files were added to the archive and compressed
    def archive_files(directory, name, files)
      archive = prepare_archive_creation(directory, name)
      ::Zip::File.open(archive, Zip::File::CREATE) do |zipfile|
        add_files_to_zip(zipfile, files)
      end
      archive
    end

    # This method receives multiple files, that will be added to a archive
    # @param [::Zip::File] zipfile The archive that will be used to add files to it
    # @param [Array<File>] files The Array of files that will be added to the archive
    #
    # @return [void]
    def add_files_to_zip(zipfile, files)
      files.each do |file|
        zipfile.add(file.sub(File.dirname(file) + '/', ''), file)
      end
    end

    # This method prepares the creation of a archive, by making sure that the directory is created and
    # if the archive already exists, will be removed, and the path to where this archive needs to be created will be returned
    # @param [String] directory The directory where the archive should be created
    # @param [String] name The name of the archive ( without the .zip extension )
    #
    # @return [String] returns the path to where this archive needs to be created
    def prepare_archive_creation(directory, name)
      archive = File.join(directory, name + '.zip')
      archive_dir = File.dirname(archive)
      FileUtils.mkdir_p(archive_dir) unless File.directory?(archive_dir)
      FileUtils.rm archive, force: true if File.exist?(archive)
      archive
    end
  end
end
