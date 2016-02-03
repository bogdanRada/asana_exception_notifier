Using Exception Notification with Sinatra
=========================================

Quick start
-----------

```
git clone git@github.com:bogdanRada/asana_exception_notifier.git
cd exception_notification/examples/sinatra
bundle install
bundle exec foreman start
```

The last command starts two services, a smtp server and the sinatra app itself. Thus, visit [http://localhost:1080/](http://localhost:1080/) to check the emails sent and, in a separated tab, visit [http://localhost:3000](http://localhost:3000) and cause some errors. For more info, use the [source](https://github.com/bogdanRada/asana_exception_notifier/blob/master/examples/sinatra/sinatra_app.rb).
