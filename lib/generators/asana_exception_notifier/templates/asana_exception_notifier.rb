require 'asana_exception_notifier'

ExceptionNotification.configure do |config|
  # Email notifier sends notifications to Asana by creating tasks .
  config.add_notifier :asana,     'asana_api_key' => ENV['ASANA_API_KEY'],
                                  'assignee' => nil,
                                  'assignee_status' => nil,
                                  'due_at' => nil,
                                  'hearted' => false,
                                  'projects' => [],
                                  'followers' => [],
                                  'workspace' => 498_346_170_860,
                                  'memberships' => [],
                                  'tags' => [],
                                  'name' => nil,
                                  'template_path' => nil
end
