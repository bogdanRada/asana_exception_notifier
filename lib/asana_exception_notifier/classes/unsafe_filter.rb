require_relative '../helpers/application_helper'
module AsanaExceptionNotifier
  # class used to filter unsafe params
  class UnsafeFilter
    include AsanaExceptionNotifier::ApplicationHelper

    UNSAFE_OPTIONS = %w(
      password password_confirmation new_password new_password_confirmation
      old_password email_address email authenticity_token utf8
    ).freeze

    attr_reader :arguments, :unsafe_options

    def initialize(arguments, unsafe_options = [])
      @unsafe_options = unsafe_options.present? && unsafe_options.is_a?(Array) ? unsafe_options.map(&:to_s) : []
      @arguments = arguments.present? ? arguments : {}
      remove_unsafe(@arguments)
    end

  private

    def remove_unsafe(args)
      return args if args.blank?
      args.delete(:attributes!)
      remove_blank(args)
      remove_unsafe_from_object(args)
      args
    end

    def remove_unsafe_from_object(args)
      if args.is_a?(Hash)
        args.each_pair do |key, value|
          verify_unsafe_pair(key, value)
        end
      else
        remove_unsafe(value: args)
      end
    end

    def unsafe?(key)
      @unsafe_options.include?(key) || AsanaExceptionNotifier::UnsafeFilter::UNSAFE_OPTIONS.include?(key)
    end

    def verify_unsafe_pair(key, value)
      case value
        when Hash
          remove_unsafe(value)
        else
          args.delete(key) if unsafe?(key.to_s)
      end
    end
  end
end
