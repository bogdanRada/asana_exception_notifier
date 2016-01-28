$stdout.sync = true if $stdout.isatty
$stdin.sync = true if $stdin.isatty
require 'rubygems'
require 'bundler'
require 'bundler/setup'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/keys'

require 'em-http-request'
require 'eventmachine'
require 'exception_notification'

require 'erb'
require 'tilt'
require 'tilt/erb'

require 'logger'
require 'fileutils'
require 'ostruct'
require 'thread'
require 'json'
require 'tempfile'

Gem.find_files('asana_exception_notifier/**/*.rb').each { |path| require path }
