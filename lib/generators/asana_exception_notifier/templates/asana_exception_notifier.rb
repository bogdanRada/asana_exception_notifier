# frozen_string_literal: true
require 'asana_exception_notifier'

ExceptionNotification.configure do |config|
  # Email notifier sends notifications to Asana by creating tasks .
  config.add_notifier :asana,     asana_api_key: ENV['ASANA_API_KEY'],
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
                                  template_path: nil,
                                  unsafe_options: []
end
