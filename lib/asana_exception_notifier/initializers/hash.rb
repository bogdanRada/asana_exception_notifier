# frozen_string_literal: true
# override Hash class
class Hash
  # This method is used for iterating over a Hash , but besides yielding the key and the value, this will also yield the parent
  # key of the current Hash object if the Hash is associated to a key
  #
  # @example Printing a Hash that contains other hashes inside, and fetching the parent keys
  #  hash = {
  #           key: :my_value,
  #           key2: {
  #             innner_key: :inner_value
  #           }
  #         }
  #   hash.each_with_parent { |parent, key, value| puts [parent, key, value].inspect }
  #   will print:
  #       [nil, :key, :my_value]
  #       [:key2, :innner_key, :inner_value]
  #
  # @see #deep_hash_with_parent
  #
  # @param [String, nil] parent The parent key of the current level of the Hash
  #   ( first level of any Hash has no parent, but if the hash has a value which is also a Hash,
  #   the parent of that value will be the key associated to the value )
  # @param [Proc] &block The block which will be used to yield the parent string, the current key and the value,
  #   while the Hash is being iterated over
  #
  # @return [void]
  def each_with_parent(parent = nil, &block)
    each do |key, value|
      if value.is_a?(Hash)
        deep_hash_with_parent(value, key, &block)
      elsif block_given?
        yield(parent, key, value)
      end
    end
  end

  # Checks if the value is a Hash , and will execute the each with parent for the given hash
  # @see #each_with_parent
  #
  # @param [Hash] value The Hash that will be used for iteration
  # @param [Hash] key The key that will be sent as the parent key of the specified Hash
  # @param [Proc] &block The block which will be used to yield the parent string, the current key and the value,
  #   while the Hash is being iterated over
  #
  # @return [void]
  def deep_hash_with_parent(value, key, &block)
    return unless value.is_a?(Hash)
    value.each_with_parent(key, &block)
  end
end
