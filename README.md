asana_exception_notifier
========================

[![Gem Version](https://badge.fury.io/rb/asana_exception_notifier.svg)](http://badge.fury.io/rb/asana_exception_notifier) [![Gem Downloads](https://ruby-gem-downloads-badge.herokuapp.com/asana_exception_notifier?type=total)](https://github.com/bogdanRada/asana_exception_notifier) [![Analytics](https://ga-beacon.appspot.com/UA-72570203-1/bogdanRada/asana_exception_notifier)](https://github.com/bogdanRada/asana_exception_notifier)

Description
-----------

Simple ruby implementation to send notifications to Asana when a exception happens in Rails or Rack-based apps by creating a task and uploading exception details to the task

The gem provides a notifier for sending notifications to Asana when errors occur in a Rack/Rails application [courtesy of exception_notifications gem](https://github.com/smartinez87/exception_notifications). Check out that gem for more details on setting up the rack middleware with additional options.

Requirements
------------

-	Ruby 2.0 or greater
-	Rails 4.0 or greater, Sinatra or another Rack-based application.

Dependencies
------------

1.	[ActiveSuport > 4.0](https://rubygems.org/gems/activesupport)
2.	[em-http-request >= 1.1.0](https://github.com/igrigorik/em-http-request)
3.	[eventmachine >= 1.0.7](https://github.com/eventmachine/eventmachine)
4.	[exception_notification >= 4.1.4](https://github.com/smartinez87/exception_notification)
5.	[multipart_body >= 0.2.1](https://github.com/cloudmailin/multipart_body)
6.	[tilt >= 1.4](https://github.com/rtomayko/tilt/)

Installation Instructions
-------------------------

Add the following to your Gemfile :

```ruby
  gem "asana_exception_notifier"
```

#### Options

##### subdomain

*String, required*

Your subdomain at Campfire.

##### room_name

*String, required*

The Campfire room where the notifications must be published to.

##### token

*String, required*

The API token to allow access to your Campfire account.

For more options to set Campfire, like *ssl*, check [here](https://github.com/collectiveidea/tinder/blob/master/lib/tinder/campfire.rb#L17).

### Rails

If you are settting up for the first time this gem, just run the following command from the terminal:

```
rails g asana_exception_notifier:install
```

This command generates an initialize file (`config/initializers/asana_exception_notifier.rb`) where you can customize your configurations.

Make sure the gem is not listed solely under the `production` group, since this initializer will be loaded regardless of environment.

AsanaExceptionNotifier is used as a rack middleware, or in the environment you want it to run. In most cases you would want AsanaExceptionNotifier to run on production. Thus, you can make it work by putting the following lines in your `config/environments/production.rb`:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack
```

### Rack/Sinatra

In order to use ExceptionNotification with Sinatra, please take a look in the [example application](https://github.com/smartinez87/exception_notification/tree/master/examples/sinatra).

But, you also can easily implement your own [custom notifier](#custom-notifier).

Background Notifications
------------------------

If you want to send notifications from a background process like DelayedJob, you should use the `notify_exception` method like this:

```ruby
begin
  some code...
rescue => exception
  ExceptionNotifier.notify_exception(exception, notifiers: :asana)
end
```

You can include information about the background process that created the error by including a data parameter:

```ruby
begin
  some code...
rescue => exception
  ExceptionNotifier.notify_exception(exception,
    :data => {:worker => worker.to_s, :queue => queue, :payload => payload}, notifiers: :asana)
end
```

### Manually notify of exception

If your controller action manually handles an error, the notifier will never be run. To manually notify of an error you can do something like the following:

```ruby
rescue_from Exception, :with => :server_error

def server_error(exception)
  # Whatever code that handles the exception

  ExceptionNotifier.notify_exception(exception,
    :env => request.env, :data => {:message => "was doing something wrong"}, notifiers: :asana)
end
```

Testing
-------

To test, do the following:

1.	cd to the gem root.
2.	bundle install
3.	bundle exec rake

Contributions
-------------

Please log all feedback/issues via [Github Issues](http://github.com/bogdanRada/asana_exception_notifier/issues). Thanks.

Contributing to asana_exception_notifier
----------------------------------------

-	Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
-	Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
-	Fork the project.
-	Start a feature/bugfix branch.
-	Commit and push until you are happy with your contribution.
-	Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
-	Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.
-	You can read more details about contributing in the [Contributing](https://github.com/bogdanRada/asana_exception_notifier/blob/master/CONTRIBUTING.md) document

== Copyright

Copyright (c) 2016 bogdanRada. See LICENSE.txt for further details.
