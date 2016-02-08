require_relative '../helpers/application_helper'
require_relative './unsafe_filter'
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
        basic_info: fetch_basic_info,
        exception: @exception,
        request: @request,
        env: @request.respond_to?(:filtered_env) ? @request.filtered_env : @env,
        data: (@env.blank? ? {} : @env.fetch(:'exception_notifier.exception_data', {})).merge(@options[:data] || {}),
        exception_data: exception_data,
        exception_service_data: exception_service,
        request_data: setup_env_params,
        parameters: @request.respond_to?(:filtered_parameters) ? filter_params(@request.filtered_parameters) : filter_params(request_params),
        session: filter_params(session.respond_to?(:to_hash) ? session.to_hash : session.to_h),
        cookies: @request.cookies.to_h
      }.merge(@options).reject { |_key, value| value.blank? }
    end

    def session
      @request.session
    end

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

    def exception_data
      {
        error_class: @exception.class.to_s,
        message:  @exception.respond_to?(:message) ? @exception.message : exception.inspect,
        backtrace: @exception.respond_to?(:backtrace) ? (@exception.backtrace || []).join("\n") : nil,
        cause: @exception.respond_to?(:cause) ? @exception.cause : nil
      }
    end

    def exception_service
      {
        service_class: @exception.respond_to?(:service_class) ? @exception.service_class : nil,
        arguments: @exception.respond_to?(:service_arguments) ? filter_params(@exception.service_arguments).inspect.gsub(',', ",\n") : nil,
        service_method: @exception.respond_to?(:service_method) ? @exception.service_method : nil,
        trace: @exception.respond_to?(:service_backtrace) ? @exception.service_backtrace : nil
      }
    end

    def setup_env_params
      {
        url: @request.respond_to?(:original_url) ? @request.original_url : @request.path_info,
        referrer: @request.referer,
        http_method: action_dispatch? ? @request.method : @request.request_method,
        ip_address:  @request.respond_to?(:remote_ip) ? @request.remote_ip : @request.ip,
        user_agent: @request.user_agent
      }
    end

    def filter_params(params)
      AsanaExceptionNotifier::UnsafeFilter.new(params, @options.fetch(:unsafe_options, [])).arguments
    end

    def request_params
      @request.params
    rescue
      {}
    end

    def fieldsets_links
      fieldsets.map { |key, _value| link_helper(key.to_s) }.join(' | ')
    end

    def fieldsets
      @fieldsets ||= mount_tables_for_fieldsets
      @fieldsets
    end

    def mount_tables_for_fieldsets
      hash = fetch_fieldsets
      hash.each do |key, value|
        html = mount_table_for_hash(value)
        hash[key] = html if html.present?
      end
      hash
    end

    def fetch_fieldsets(hash = {})
      @template_params.each_with_parent do |parent, key, value|
        next if value.blank? || key.blank?
        parent_name = set_fieldset_key(hash, parent, 'system_info')
        hash[parent_name][key] = value
      end
      hash.keys.map(&:to_s).sort
      hash
    end

    def render_template(template = nil)
      execute_with_rescue do
        current_template = template.present? ? template : @template_path
        @template_params[:fieldsets] = fieldsets
        @template_params[:fieldsets_links] = fieldsets_links
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

    def fetch_all_archives
      fetch_archives
    rescue
      []
    end

    def fetch_archives(output = render_template)
      return [] if output.blank?
      filename, path = create_tempfile(output)
      archive = compress_files(File.dirname(path), filename, [expanded_path(path)])
      remove_tempfile(path)
      split_archive(archive, "part_#{filename}", 1024 * 1024 * 100)
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
