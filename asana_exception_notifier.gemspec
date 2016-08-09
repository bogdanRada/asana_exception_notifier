require File.expand_path('../lib/asana_exception_notifier/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'asana_exception_notifier'
  s.version = AsanaExceptionNotifier.gem_version
  s.platform = Gem::Platform::RUBY
  s.summary = 'Simple ruby implementation to send notifications to Asana
    when a exception happens in Rails or Rack-based apps by creating a task and uploading exception details to the task'
  s.email = 'raoul_ice@yahoo.com'
  s.homepage = 'http://github.com/bogdanRada/asana_exception_notifier'
  s.description = 'Simple ruby implementation to send notifications to Asana
      when a exception happens in Rails or Rack-based apps by creating a task and uploading exception details to the task using zip archives'
  s.authors = ['bogdanRada']
  s.date = Date.today

  s.licenses = ['MIT']
  s.files = `git ls-files`.split("\n")
  s.test_files = s.files.grep(/^(spec)/)
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 2.0'
  s.required_rubygems_version = '>= 2.5'
  s.metadata = {
    'source_code' => s.homepage,
    'bug_tracker' => "#{s.homepage}/issues"
  }

  s.add_runtime_dependency 'activesupport', '>= 4.0', '>= 4.0'
  s.add_runtime_dependency 'asana', '~> 0.5', '>= 0.5.0'
  s.add_runtime_dependency 'typhoeus', '~> 1.0', '>= 1.0.2'
  s.add_runtime_dependency 'exception_notification', '~> 4.1', '>= 4.1.4'
  s.add_runtime_dependency 'tilt', '>= 1.4', '< 3'
  s.add_runtime_dependency 'rack', '>= 1.5', '>= 1.5'
  s.add_runtime_dependency 'rubyzip', '~> 1.0',  '>= 1.0.0' # will load new rubyzip version
  s.add_runtime_dependency 'zip-zip', '~> 0.3', '>= 0.3' # will load compatibility for old rubyzip API
  s.add_runtime_dependency 'sys-uname', '~> 1.0', '>= 1.0.2'
  s.add_runtime_dependency 'faraday-conductivity', '~> 0.3', '>= 0.3.1'

  s.add_development_dependency 'appraisal', '~> 2.1', '>= 2.1'
  s.add_development_dependency 'rspec', '~> 3.4', '>= 3.4'
  s.add_development_dependency 'simplecov', '~> 0.11', '>= 0.10'
  s.add_development_dependency 'simplecov-summary', '~> 0.0.4', '>= 0.0.4'
  s.add_development_dependency 'coveralls', '~> 0.7', '>= 0.7'
  s.add_development_dependency 'rake', '~> 11.0', '>= 11.0'
  s.add_development_dependency 'yard', '~> 0.8', '>= 0.8.7'
  s.add_development_dependency 'redcarpet', '~> 3.3', '>= 3.3'
  s.add_development_dependency 'github-markup', '~> 1.3', '>= 1.3.3'
  s.add_development_dependency 'inch', '~> 0.6', '>= 0.6'
end
