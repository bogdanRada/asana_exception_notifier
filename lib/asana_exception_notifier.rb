require 'rubygems'
require 'bundler'
require 'bundler/setup'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/module/delegation'

require 'json'
require 'em-http-request'
require 'eventmachine'
require 'exception_notification'

require 'logger'

Gem.find_files('asana_exception_notifier/**/*.rb').each { |path| require path }

ExceptionNotifier.add_notifier :asana_exception_notifier,
->(exception, options) { AsanaExceptionNotifier::API::Asana.new(exception, options) }
