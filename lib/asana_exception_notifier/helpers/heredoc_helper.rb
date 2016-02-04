module AsanaExceptionNotifier
  # helper methods that use Heredoc syntax
  module HeredocHelper
  module_function

    def link_helper(link)
      <<-HTML
      <a href="javascript:void(0)" onclick="AjaxExceptionNotifier.hideAllAndToggle('#{link.downcase}')">#{link.camelize}</a>
      HTML
    end

    # Gets a bidimensional array and create a table.
    # The first array is used as label.
    #
    def mount_table(array, options = {})
      header = array.extract_options!
      <<-HTML
      <table #{hash_to_html_attributes(options)}>
      <thead><tr><th>#{get_table_headers(header)}</th></tr></thead>
      <tbody>#{get_table_rows(array)}</tbody>
      </table>
      HTML
    end
  end
end
