require 'asana_exception_notifier'

ExceptionNotification.configure do |config|
  # Email notifier sends notifications to Asana by creating tasks .
  config.add_notifier :asana,     asana_api_key: ENV['ASANA_API_KEY'],
                                  assignee: 'me',
                                  assignee_status: 'today', # 'today'
                                  due_at:  Time.now.iso8601,
                                  hearted: false,
                                  projects: [],
                                  followers: [],
                                  workspace: ENV['ASANA_WORKSPACE_ID'],
                                  memberships: [],
                                  tags: [],
                                  name: nil,
                                  template_path: nil
end
