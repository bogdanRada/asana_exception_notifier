# IMPORTANT !!!! DON'T use  code from this file , this is done so that manually testing the gem would be easier.
# Manual tests are done with command: ruby spec/manual_tests/test_notification.rb , which should send a notification to Asana
# about an error occuring , if the system has configured properly the ASANA_API_KEY and ASANA_WORKSPACE_ID environment variables

module Subscribers
  class Base

    attr_reader :event

    def initialize(*args)
      @event = ActiveSupport::Notifications::Event.new(*args)
      process
    end

    def process
      raise NotImplementedError
    end

  end
end
