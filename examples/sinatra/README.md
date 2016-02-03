Using Exception Notification with Sinatra
=========================================

Quick start
-----------

```
git clone git@github.com:bogdanRada/asana_exception_notifier.git
cd asana_exception_notifier/examples/sinatra
bundle install
bundle exec foreman start
```

The last command starts the sinatra app itself. Thus, visit [http://localhost:300/](http://localhost:3000/) to check the asana notification is sent and, in a separated tab, visit [Asana.com](http://asana.com) and cause some errors. For more info, use the [source](https://github.com/bogdanRada/asana_exception_notifier/blob/master/examples/sinatra/sinatra_app.rb).
