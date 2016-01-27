require_relative '../lib/asana_exception_notifier'
require_relative '../lib/generators/asana_exception_notifier/templates/asana_exception_notifier'
exception = StandardError.new
ExceptionNotifier.notify_exception(exception, notifiers: :asana)
