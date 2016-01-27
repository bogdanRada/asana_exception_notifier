require File.expand_path('../lib/asana_exception_notifier/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'asana_exception_notifier'
  s.version = AsanaExceptionNotifier.gem_version
  s.platform = Gem::Platform::RUBY
  s.summary = ''
  s.email = 'raoul_ice@yahoo.com'
  s.homepage = 'http://github.com/bogdanRada/asana_exception_notifier/'
  s.description = ''
  s.authors = ['bogdanRada']
  s.date = Date.today

  s.licenses = ['MIT']
  s.files = `git ls-files`.split("\n")
  s.test_files = s.files.grep(/^(spec)/)
  s.require_paths = ['lib']

  s.add_runtime_dependency 'em-http-request', '~> 1.1', '>= 1.1.2'
  s.add_runtime_dependency 'eventmachine', '~> 1.0', '>= 1.0.7'
  s.add_runtime_dependency 'exception_notification', '~> 4.1', '>= 4.1.4'

  s.add_development_dependency 'rspec', '~> 3.4', '>= 3.4'
  s.add_development_dependency 'simplecov', '~> 0.10', '>= 0.10'
  s.add_development_dependency 'simplecov-summary', '~> 0.0.4', '>= 0.0.4'
  s.add_development_dependency 'mocha', '~> 1.1', '>= 1.1'
  s.add_development_dependency 'coveralls', '~> 0.7', '>= 0.7'
  s.add_development_dependency 'rake', '~> 10.5', '>= 10.5'
  s.add_development_dependency 'yard', '~> 0.8', '>= 0.8.7'
  s.add_development_dependency 'redcarpet', '~> 3.3', '>= 3.3'
  s.add_development_dependency 'github-markup', '~> 1.3', '>= 1.3.3'
  s.add_development_dependency 'inch', '~> 0.6', '>= 0.6'
end
