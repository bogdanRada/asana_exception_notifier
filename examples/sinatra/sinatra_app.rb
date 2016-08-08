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
      assignee: 'me',
      assignee_status: 'today', # 'today'
      due_at:  Time.now.iso8601,
      due_on: nil,
      hearted: false,
      hearts: [],
      projects: [],
      followers: [],
      memberships: [],
      tags: [],
      name: nil,
      notes: '',
      template_path: nil
    }

  get '/' do
    raise StandardError, "ERROR: #{params[:error]}" unless params[:error].blank?
    'Everything is fine! Now, lets break things clicking <a href="/?error=ops"> here </a>. Dont forget to see the asana tasks at <a href="http://asana.com">Asana</a> !'
  end

  get '/background_notification' do
    begin
      1/0
    rescue Exception => exception
      ExceptionNotifier.notify_exception(exception, :data => {:msg => "Cannot divide by zero!"})
    end
    'Check notification at <a href="http://asana.com">Asana</a>.'
  end
end
