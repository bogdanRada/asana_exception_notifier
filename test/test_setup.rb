require_relative '../lib/asana_exception_notifier'

AsanaExceptionNotifier::ErrorPage.class_eval do
  alias_method :original_initialize, :initialize

  def initialize(*args)
    original_initialize(*args)
    debug_template if ENV['DEBUG_ASANA_TEMPLATE']
  end

  def debug_template
    _filename, path = create_tempfile
    system("google-chrome #{path}")
    sleep while 0 == 0
  end
end

require_relative '../lib/generators/asana_exception_notifier/templates/asana_exception_notifier'
exception = StandardError.new
ExceptionNotifier.notify_exception(exception, notifiers: :asana)
