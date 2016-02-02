require 'rubygems'
require 'bundler'
require 'bundler/setup'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/keys'

require 'exception_notifier'
require 'exception_notification/rack'
if defined?(Rails)
  require 'exception_notification/rails'
end
require 'exception_notification'

require 'em-http-request'
require 'eventmachine'

require 'multipart_body'
require 'rack'
require 'zip'
require 'rack/mime'
require 'sys-uname'

require 'erb'
require 'tilt'
require 'tilt/erb'

require 'logger'
require 'fileutils'
require 'ostruct'
require 'thread'
require 'json'
require 'tempfile'
require 'English'
require 'pathname'

%w(initializers helpers request classes).each do |folder_name|
  Gem.find_files("asana_exception_notifier/#{folder_name}/**/*.rb").each { |path| require path }
end
require_relative './asana_exception_notifier/version'
