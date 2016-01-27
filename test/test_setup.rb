require_relative '../lib/asana_exception_notifier'
exception = StandardError.new
ExceptionNotifier.notify_exception(exception, {:notifiers => :asana_exception_notifier})
