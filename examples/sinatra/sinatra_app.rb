$stdout.sync = true
require 'rubygems'
require 'bundler'
require 'bundler/setup'
ENV['RACK_ENV'] ||= ENV['RAILS_ENV'].present? ? ENV['RAILS_ENV'] : 'development'
Bundler.require :default, (ENV['RACK_ENV'] || 'development').to_sym


class SinatraApp < Sinatra::Base
  use Rack::Config do |env|
    env["action_dispatch.parameter_filter"] = [:password] # This is highly recommended.  It will prevent the ExceptionNotification email from including your users' passwords
  end

  use ExceptionNotification::Rack,
    :asana => {
      asana_api_key: ENV['ASANA_API_KEY'],
      workspace: ENV['ASANA_WORKSPACE_ID'],
    }

  get '/' do
    raise StandardError, "ERROR: #{params[:error]}" unless params[:error].blank?
    'Everything is fine! Now, lets break things clicking <a href="/?error=ops"> here </a>. Dont forget to see the emails at <a href="http://localhost:1080">mailcatcher</a> !'
  end

  get '/background_notification' do
    begin
      1/0
    rescue Exception => e
      ExceptionNotifier.notify_exception(e, :data => {:msg => "Cannot divide by zero!"})
    end
    'Check email at <a href="http://localhost:1080">mailcatcher</a>.'
  end
end
