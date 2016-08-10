# frozen_string_literal: true
module AsanaExceptionNotifier
  # helper methods that use Heredoc syntax
  module HeredocHelper
  module_function

    # This method creates a HTML link , that when will be clicked will trigger the toggle of a fieldset, by either making it hidden or visible
    # @param [String] link The link id of the fieldset that will be toggled when the resulting HTML link will be clicked
    #
    # @return [String] returns HTML link that will be used to toggle between fieldsets
    def link_helper(link)
      <<-HTML
      <a href="javascript:void(0)" onclick="AjaxExceptionNotifier.hideAllAndToggle('#{link.downcase}')">#{link.camelize}</a>
      HTML
    end

    # Gets a bidimensional array and create a table.
    # The first array is used as label.
    # @param [Array<Array<String>>] array The array of arrays of strings that will be used for constructing the HTML table
    # @param [Hash] options The options list that will be used to construct the HTML attributes on the HTML table
    #
    # @return [String] returns the HTML table that was generated from the received array
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
