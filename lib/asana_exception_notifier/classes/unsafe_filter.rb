# frozen_string_literal: true
require_relative '../helpers/application_helper'
module AsanaExceptionNotifier
  # class used to filter unsafe params
  #
  # @!attribute arguments
  #   @return [#delete] THe arguments that will be filtered
  # @!attribute unsafe_options
  #   @return [Array<String>, Array<Symbol>] Additional unsafe options that will be used for filtering
  class UnsafeFilter
    include AsanaExceptionNotifier::ApplicationHelper

    # the default options that are considered unsafe
    UNSAFE_OPTIONS = %w(
      password password_confirmation new_password new_password_confirmation
      old_password email_address email authenticity_token utf8
    ).freeze

    attr_reader :arguments, :unsafe_options

    # Initializes the instance with the arguments that will be filtered and the additional unsafe options
    # and starts filtering the arguments
    # @see #remove_unsafe
    #
    # @param [#delete] arguments The arguments that will be filtered
    # @param [Array<String>, Array<Symbol>] unsafe_options Additional unsafe options that will be used for filtering
    #
    # @return [void]
    def initialize(arguments, unsafe_options = [])
      @unsafe_options = unsafe_options.present? && unsafe_options.is_a?(Array) ? unsafe_options.map(&:to_s) : []
      @arguments = arguments.present? ? arguments : {}
      remove_unsafe(@arguments)
    end

  private

    # Returns the arguments, if they are blank
    # Otherwise first tries to remove attributes
    # then the blank values, and then tries to remove any remaining unsafe from the remaining object
    # @see #remove_blank
    # @see #remove_unsafe_from_object
    #
    # @param [#delete] args The arguments that will be filtered
    #
    # @return [Object, nil]
    def remove_unsafe(args)
      return args if args.blank?
      args.delete(:attributes!)
      remove_blank(args)
      remove_unsafe_from_object(args)
      args
    end

    # If arguments is a hash will try to remove any unsafe values
    # otherwise will call the remove_unsafe to start removing from object
    # @see #verify_unsafe_pair
    # @see #remove_unsafe
    #
    # @param [#delete] args The arguments that will be filtered
    #
    # @return [Object, nil]
    def remove_unsafe_from_object(args)
      if args.is_a?(Hash)
        args.each_pair do |key, value|
          verify_unsafe_pair(key, value)
        end
      else
        remove_unsafe(value: args)
      end
    end

    # returns true if the key is included in the default unsafe options or in the custom ones, otherwise false
    #
    # @param [String] key The key that will be checked if is unsafe
    #
    # @return [Boolean] returns true if the key is included in the default unsafe options or in the custom ones, otherwise false
    def unsafe?(key)
      @unsafe_options.include?(key) || AsanaExceptionNotifier::UnsafeFilter::UNSAFE_OPTIONS.include?(key)
    end

    # If the value is a hash, we start removing unsafe options from the hash, otherwise we check the key
    # @see #unsafe?
    # @param [String] key The key that will be checked if is unsafe
    # @param [Object] value The value that will be checked if it is unsafe
    #
    # @return [void]
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
