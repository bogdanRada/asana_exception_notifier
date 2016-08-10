# frozen_string_literal: true
module AsanaExceptionNotifier
  # module that defines the available generators for this gem
  module Generators
    # module that is used for formatting numbers using metrics
    class InstallGenerator < Rails::Generators::Base
      desc 'Creates a AsanaExceptionNotifier initializer.'

      source_root File.expand_path('../templates', __FILE__)

      # This method will copy the template from this gem into the `config/initializers/asana_exception_notifier.rb` file in the application
      #
      # @return [void]
      def copy_initializer
        template 'asana_exception_notifier.rb', 'config/initializers/asana_exception_notifier.rb'
      end
    end
  end
end
