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
