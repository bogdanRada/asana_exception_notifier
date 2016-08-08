# frozen_string_literal: true
# override Hash class
class Hash
  def each_with_parent(parent = nil, &block)
    each do |key, value|
      if value.is_a?(Hash)
        deep_hash_with_parent(value, key, &block)
      elsif block_given?
        yield(parent, key, value)
      end
    end
  end

  def deep_hash_with_parent(value, key, &block)
    value.each_with_parent(key, &block)
  end
end
