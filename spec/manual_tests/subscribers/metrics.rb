# IMPORTANT !!!! DON'T use  code from this file , this is done so that manually testing the gem would be easier.
# Manual tests are done with command: ruby spec/manual_tests/test_notification.rb , which should send a notification to Asana
# about an error occuring , if the system has configured properly the ASANA_API_KEY and ASANA_WORKSPACE_ID environment variables

require_relative './base'
module Subscribers
  class Metrics < Base

    def process
      payload   = event.payload
      dur   = event.duration
      url = payload[:url]
      http_method = payload[:method].to_s.upcase
      $stderr.puts '[%s] %s %s (%.3f s)' % [url.host, http_method, url.request_uri, dur]
    end

  end
end
