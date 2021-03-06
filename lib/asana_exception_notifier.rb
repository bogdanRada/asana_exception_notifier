# frozen_string_literal: true
require 'rubygems'
require 'bundler'
require 'bundler/setup'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/array/extract_options'
require 'active_support/notifications'

require 'exception_notifier'
require 'exception_notification/rack'
if defined?(Rails)
  require 'exception_notification/rails'
end
if defined?(Resque)
  require 'exception_notification/resque'
end
if defined?(Sidekiq)
  require 'exception_notification/sidekiq'
end
require 'exception_notification'

require 'asana'
require 'typhoeus'
require 'typhoeus/adapters/faraday'
require 'faraday_middleware'

require 'rack'
require 'zip'
require 'rack/mime'
require 'sys-uname'

require 'tilt'
require 'erb'
require 'tilt/erb'

require 'logger'
require 'fileutils'
require 'ostruct'
require 'thread'
require 'json'
require 'tempfile'
require 'English'
require 'pathname'
require 'socket'

%w(initializers helpers request classes).each do |folder_name|
  Gem.find_files("asana_exception_notifier/#{folder_name}/**/*.rb").each { |path| require path }
end
require_relative './asana_exception_notifier/version'
