# override Hash class
class Hash
  def each_with_parent(parent = nil, &block)
    each do |key, value|
      if value.is_a?(Hash)
        value.each_with_parent(key, &block)
      else
        yield(parent, key, value)
      end
    end
  end
end
