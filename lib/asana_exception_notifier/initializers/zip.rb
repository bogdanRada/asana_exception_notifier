Zip.setup do |c|
  c.on_exists_proc = true
  c.continue_on_exists_proc = true
  c.unicode_names = false
  c.default_compression = Zlib::BEST_COMPRESSION
end

Zip::File.class_eval do
  singleton_class.send(:alias_method, :original_split, :split)

  def self.split(zip_file_name, segment_size = MAX_SEGMENT_SIZE, delete_zip_file = true, partial_zip_file_name = nil, &block)
    raise Error, "File #{zip_file_name} not found" unless ::File.exist?(zip_file_name)
    raise Errno::ENOENT, zip_file_name unless ::File.readable?(zip_file_name)
    zip_file_size = ::File.size(zip_file_name)
    segment_size  = segment_size # removed get_segment_size_for_split  so that segment_size remains the one from params
    return if zip_file_size <= segment_size
    segment_count = get_segment_count_for_split(zip_file_size, segment_size)
    # Checking for correct zip structure
    open(zip_file_name) {}
    partial_zip_file_name = get_partial_zip_file_name(zip_file_name, partial_zip_file_name)
    szip_file_index       = 0
    ::File.open(zip_file_name, 'rb') do |zip_file|
      until zip_file.eof?
        szip_file_index += 1
        save_splited_part(zip_file, partial_zip_file_name, zip_file_size, szip_file_index, segment_size, segment_count, &block) # added the block param
      end
    end
    ::File.delete(zip_file_name) if delete_zip_file
    szip_file_index
  end
end
