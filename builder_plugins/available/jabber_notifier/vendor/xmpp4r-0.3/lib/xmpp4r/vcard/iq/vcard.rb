# =XMPP4R - XMPP Library for Ruby
# License:: Ruby's license (see the LICENSE file) or GNU GPL, at your option.
# Website::http://home.gna.org/xmpp4r/

require 'xmpp4r/iq'

module Jabber
  module Vcard
    ##
    # vCard container for User Information
    # (can be specified by users themselves, mostly kept on servers)
    # (JEP 0054)
    class IqVcard < REXML::Element
      ##
      # Initialize a <vCard/> element
      # fields:: [Hash] Initialize with keys as XPath element names and values for element texts
      def initialize(fields=nil)
        super("vCard")
        add_namespace('vcard-temp')

        unless fields.nil?
          fields.each { |name,value|
            self[name] = value
          }
        end
      end

      ##
      # element:: [REXML::Element] to import
      # result:: [IqVcard] with all attributes and children copied from element
      def IqVcard.import(element)
        IqVcard::new.import(element)
      end

      ##
      # Get an elements/fields text
      #
      # vCards have too much possible children, so ask for them here
      # and extract the result with iqvcard.element('...').text
      # name:: [String] XPath
      def [](name)
        text = nil
        each_element(name) { |child| text = child.text }
        text
      end

      ##
      # Set an elements/fields text
      # name:: [String] XPath
      # text:: [String] Value
      def []=(name, text)
        xe = self
        name.split(/\//).each do |elementname|
          # Does the children already exist?
          newxe = nil
          xe.each_element(elementname) { |child| newxe = child }

          if newxe.nil?
            # Create a new
            xe = xe.add_element(elementname)
          else
            # Or take existing
            xe = newxe
          end
        end
        xe.text = text
      end

      ##
      # Get vCard field names
      #
      # Example:
      #  ["NICKNAME", "BDAY", "ORG/ORGUNIT", "PHOTO/TYPE", "PHOTO/BINVAL"]
      #
      # result:: [Array] of [String]
      def fields
        element_names(self).uniq
      end

      ##
      # Recursive helper function,
      # returns all element names in an array, concatenated
      # to their parent's name with a slash
      def element_names(xe, prefix='')  # :nodoc:
        res = []
        xe.each_element { |child|
          if child.kind_of?(REXML::Element)
            children = element_names(child, "#{prefix}#{child.name}/")
            if children == []
              res.push("#{prefix}#{child.name}")
            else
              res += children
            end
          end
        }
        res
      end

      Iq.add_elementclass('vCard', IqVcard)
    end
  end
end
