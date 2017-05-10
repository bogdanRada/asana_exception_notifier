require_relative '../../lib/asana_exception_notifier'

# IMPORTANT !!!! DON'T use  code from this file , this is done so that manually testing the gem would be easier.
# Manual tests are done with command: ruby spec/manual_tests/test_notification.rb , which should send a notification to Asana
# about an error occuring , if the system has configured properly the ASANA_API_KEY and ASANA_WORKSPACE_ID environment variables


# DON'T use this Code from this file. This is done so that manual testing the gem would be easier.
# The initialize method is overriden here so that we can see the resulting HTML generated before it gets archived
# This helps when modifying the error page template manually and trying to see if the result is the expected one.
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

# DON'T require this manually, this is done here so that the gem will be configured with defaults while manually testing the gem
# This should already be included in your app if you have followed the Readme and executed "rails g asana_exception_notifier:install"
require_relative '../../lib/generators/asana_exception_notifier/templates/asana_exception_notifier'

# Constructing the error we want to send during our manual tests
exception = StandardError.new


# FOR manual tests we are interested in duration of each request so we are registering subscribers for request.
# This should not be done for production applications. This is used only for testing connections
require_relative './subscribers/metrics'
ActiveSupport::Notifications.subscribe('request.faraday') do |*args|
  Subscribers::Metrics.new(*args)
end

# Finally send our notification manually
# This can be done manually in applications too, when rescueing from an exception
ExceptionNotifier.notify_exception(exception, notifiers: :asana)
