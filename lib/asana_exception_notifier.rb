require 'rubygems'
require 'bundler'
require 'bundler/setup'

require 'em-http-request'
require 'eventmachine'
require 'exception_notification'

require 'ostruct'

Gem.find_files('asana_exception_notifier/**/*.rb').each { |path| require path }

ExceptionNotification.configure do |config|

  config.add_notifier :asana, {
    'asana_api_key' => ENV['ASANA_API_KEY'],
    'assignee' => 9261272620298,
    'assignee_status' => 'bla',
    'due_on' => nil,
    'due_at' => nil,
    'hearted' => true,
    'projects' => [],
    'followers' => [],
    'workspace' => 498346170860,
    'memberships' => [],
    'tags' => []
  }

end
