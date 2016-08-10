# frozen_string_literal: true
Zip.setup do |c|
  # By default, rubyzip will not overwrite files if they already exist inside of the extracted path.
  # To change this behavior, you may specify a configuration option like so:
  c.on_exists_proc = true
  # Additionally, if you want to configure rubyzip to overwrite existing files while creating a .zip file, you can do so with the following:
  c.continue_on_exists_proc = true
  # If you want to store non-english names and want to open them on Windows(pre 7) you need to set this option: ( We don't want that)
  c.unicode_names = false
  # Some zip files might have an invalid date format, which will raise a warning. You can hide this warning with the following setting:
  c.warn_invalid_date = false
  # You can set the default compression level like so: Possible values are Zlib::BEST_COMPRESSION, Zlib::DEFAULT_COMPRESSION and Zlib::NO_COMPRESSION
  c.default_compression = Zlib::BEST_COMPRESSION
  # To save zip archives in sorted order like below, you need to set ::Zip.sort_entries to true
  c.sort_entries = true
end

# Zip::File.class_eval do
#   singleton_class.send(:alias_method, :original_get_segment_size_for_split, :get_segment_size_for_split)
#
#   # This method was overidden from the original method that contained this code
#   #   case
#   #      when MIN_SEGMENT_SIZE > segment_size
#   #        MIN_SEGMENT_SIZE
#   #      when MAX_SEGMENT_SIZE < segment_size
#   #          MAX_SEGMENT_SIZE
#   #      else
#   #        segment_size
#   #      end
#   # where
#   #  MAX_SEGMENT_SIZE     = 3_221_225_472 (1024 * 1024 * 1024 * 3)
#   #  MIN_SEGMENT_SIZE     = 65_536 (1024 * 64)
#   #
#   # Because if you wanted to split a archive using a smaller size than the minimum size, it wouldn't be possible
#   # because will always return the minimum size which is 64 Kb
#   #
#   # @param [Integer] segment_size the size that will be used to split an archive called by the Zip::File.split method
#   #
#   # @return [Integer] returns the size that will be used for splitting an archive
#   def self.get_segment_size_for_split(segment_size)
#     segment_size
#   end
# end
