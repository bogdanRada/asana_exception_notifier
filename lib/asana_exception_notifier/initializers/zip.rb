Zip.setup do |c|
  c.on_exists_proc = true
  c.continue_on_exists_proc = true
  c.unicode_names = false
  c.default_compression = Zlib::BEST_COMPRESSION
end

Zip::File.class_eval do
  singleton_class.send(:alias_method, :original_get_segment_size_for_split, :get_segment_size_for_split)

  def self.get_segment_size_for_split(segment_size)
    segment_size
  end
end
