# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'

require 'simplecov'
require 'simplecov-summary'
require 'coveralls'

# require "codeclimate-test-reporter"
formatters = [SimpleCov::Formatter::HTMLFormatter]

formatters << Coveralls::SimpleCov::Formatter # if ENV['TRAVIS']
# formatters << CodeClimate::TestReporter::Formatter # if ENV['CODECLIMATE_REPO_TOKEN'] && ENV['TRAVIS']

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(formatters)

Coveralls.wear!
SimpleCov.start 'rails' do
  add_filter 'spec'

  at_exit {}
end

# CodeClimate::TestReporter.configure do |config|
#  config.logger.level = Logger::WARN
# end
# CodeClimate::TestReporter.start

require 'bundler/setup'
require 'asana_exception_notifier'

RSpec.configure do |config|
  require 'rspec/expectations'
  require 'rspec/mocks'
  config.include RSpec::Matchers

  config.mock_with :rspec

  config.after(:suite) do
    if SimpleCov.running
      SimpleCov::Formatter::HTMLFormatter.new.format(SimpleCov.result)

      SimpleCov::Formatter::SummaryFormatter.new.format(SimpleCov.result)
    end
  end
end
