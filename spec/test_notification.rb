require_relative '../lib/asana_exception_notifier'

AsanaExceptionNotifier::ErrorPage.class_eval do
  alias_method :original_initialize, :initialize

  def initialize(*args)
    original_initialize(*args)
    debug_html_template if ENV['DEBUG_ASANA_TEMPLATE']
  end

  def debug_html_template
    _filename, path = create_tempfile
    system("google-chrome #{path}")
    sleep until 0 == 1
  end
end

require_relative '../lib/generators/asana_exception_notifier/templates/asana_exception_notifier'
exception = StandardError.new
ExceptionNotifier.notify_exception(exception, notifiers: :asana)
