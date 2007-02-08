module ActionView
  module Helpers
    # Provides a set of methods for making it easier to locate problems.
    module DebugHelper
      # Returns a <pre>-tag set with the +object+ dumped by YAML. Very readable way to inspect an object.
      def debug(object)
        begin
          Marshal::dump(object)
          "<pre class='debug_dump'>#{h(object.to_yaml).gsub("  ", "&nbsp; ")}</pre>"
        rescue Exception => e  # errors from Marshal or YAML
          # Object couldn't be dumped, perhaps because of singleton methods -- this is the fallback
          "<code class='debug_dump'>#{h(object.inspect)}</code>"
        end
      end
    end
  end
end