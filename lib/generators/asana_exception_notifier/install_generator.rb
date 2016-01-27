module AsanaExceptionNotifier
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Creates a AsanaExceptionNotifier initializer."

      source_root File.expand_path('../templates', __FILE__)

      def copy_initializer
        template 'asana_exception_notifier.rb', 'config/initializers/exception_notification.rb'
      end
    end
  end
end
