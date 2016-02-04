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
      return '' if array.blank?
      header = array.shift

      header = header.map { |name| escape(name.to_s.humanize) }
      rows = array.map { |name| "<tr><td>#{name.join('</td><td>')}</td></tr>" }

      <<-HTML
      <table #{hash_to_html_attributes(options)}>
      <thead><tr><th>#{header.join('</th><th>')}</th></tr></thead>
      <tbody>#{rows.join}</tbody>
      </table>
      HTML
    end
  end
end
