require_relative '../helpers/application_helper'
module AsanaExceptionNotifier
  # class used for rendering the template for exception
  class ErrorPage
    include AsanaExceptionNotifier::ApplicationHelper

    attr_reader :template_path, :exception, :options, :boundary, :template_details, :env, :request, :tempfile, :template_params, :content

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

    def html_template(path)
      @template_path = if path_is_a_template?(path)
                         expanded_path(path)
                       else
                         File.join(template_dir, 'exception_details.html.erb')
                       end
    end

    def action_dispatch?
      defined?(ActionDispatch::Request)
    end

    def setup_template_details
      template_extension = @template_path.scan(/\.(\w+)\.?(.*)?/)[0][0]
      get_extension_and_name_from_file(@template_path).merge(
        template_extension: template_extension
      )
    end

    def parse_exception_options
      @template_params ||= {
        server:  Socket.gethostname,
        exception: @exception,
        request: @request,
        environment: action_dispatch? ? @request.filtered_env : @env,
        rails_root: defined?(Rails) ? Rails.root : nil,
        process: $PROCESS_ID,
        data: (@env.blank? ? {} : @env.fetch(:'exception_notifier.exception_data', {})).merge(@options[:data] || {}),
        exception_data: exception_data,
        request_data: setup_env_params,
        uname: Sys::Uname.uname,
        timestamp: @timestamp,
        pwd:  File.expand_path($PROGRAM_NAME)
      }.merge(@options).reject { |_key, value| value.blank? }
    end

    def exception_data
      {
        error_class: @exception.class.to_s,
        message:  @exception.respond_to?(:message) ? @exception.message : exception.inspect,
        backtrace: @exception.respond_to?(:backtrace) ? @exception.backtrace : '',
        cause: @exception.respond_to?(:cause) ? @exception.cause : ''
      }
    end

    def setup_env_params
      {
        url: action_dispatch? ? @request.original_url : @request.path_info,
        referrer: @request.referer,
        http_method: action_dispatch? ? @request.method : @request.request_method,
        ip_address:  action_dispatch? ? @request.remote_ip : @request.ip,
        parameters: action_dispatch? ? @request.filtered_parameters : request_params,
        session: @request.session,
        cookies: @request.cookies,
        user_agent: @request.user_agent
      }
    end

    def request_params
      @request.params
    rescue
      {}
    end

    def fieldsets_links
      fieldsets.map { |key, _value| link_helper(key.to_s) }.join(' | ')
    end

    def fetch_fieldsets(hash, links = {}, prefix = nil)
      return unless hash.is_a?(Hash)
      hash.each do |key, value|
        if value.is_a?(Hash)
          fetch_fieldsets(value, links, key)
        else
          add_to_links(links, prefix, key: key, value: value)
        end
      end
      links
    end

    def add_to_links(links, prefix, options = {})
      expected_value = parse_fieldset_value(options)
      return unless expected_value.present?
      prefix_name = set_fieldset_key(links, prefix || 'basic_info')
      links[prefix_name][options[:key]] = expected_value
    end

    def fieldsets
      @fieldsets ||= fetch_fieldsets(parse_exception_options).except(:env)
    end

    def render_template(template = nil)
      execute_with_rescue do
        current_template = template.present? ? template : @template_path
        Tilt.new(current_template).render(self, @template_params.stringify_keys)
      end
    end

    def create_tempfile(output = render_template)
      tempfile = Tempfile.new([SecureRandom.uuid, ".#{@template_details[:template_extension]}"], encoding: 'utf-8')
      tempfile.write(output)
      ObjectSpace.undefine_finalizer(tempfile) # force garbage collector not to remove automatically the file
      tempfile.close
      tempfile_details(tempfile).slice(:filename, :path).values
    end

    def fetch_archives(output = render_template)
      execute_with_rescue(value: []) do
        return [] if output.blank?
        filename, path = create_tempfile(output)
        archive = compress_files(File.dirname(path), filename, [expanded_path(path)])
        remove_tempfile(path)
        split_archive(archive, "part_#{filename}", 1024 * 1024 * 100)
      end
    end

    def remove_tempfile(path)
      if ENV['DEBUG_ASANA_TEMPLATE']
        logger.debug(path)
      else
        FileUtils.rm_rf([path])
      end
    end
  end
end
