module AsanaExceptionNotifier
  module Generators
    # module that is used for formatting numbers using metrics
    class InstallGenerator < Rails::Generators::Base
      desc 'Creates a AsanaExceptionNotifier initializer.'

      source_root File.expand_path('../templates', __FILE__)

      def copy_initializer
        template 'asana_exception_notifier.rb', 'config/initializers/asana_exception_notifier.rb'
      end
    end
  end
end
