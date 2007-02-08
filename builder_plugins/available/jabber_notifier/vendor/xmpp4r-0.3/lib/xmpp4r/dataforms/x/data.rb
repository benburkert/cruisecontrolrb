# =XMPP4R - XMPP Library for Ruby
# License:: Ruby's license (see the LICENSE file) or GNU GPL, at your option.
# Website::http://home.gna.org/xmpp4r/

require 'xmpp4r/x'
require 'xmpp4r/jid'

module Jabber
  module Dataforms
    ##
    # Data Forms (JEP-0004) implementation
    class XData < X
      def initialize(type=nil)
        super()
        add_namespace('jabber:x:data')
        self.type = type
      end

      def typed_add(xe)
        if xe.kind_of?(REXML::Element)
          case xe.name
            when 'instructions' then super XDataInstructions.new.import(xe)
            when 'title' then super XDataTitle.new.import(xe)
            when 'field' then super XDataField.new.import(xe)
            when 'reported' then super XDataReported.new.import(xe)
            #when 'item' then super XDataItem.new.import(xe)
            else super xe
          end
        else
          super xe
        end
      end

      ##
      # Search a field by it's var-name
      # var:: [String]
      # result:: [XDataField] or [nil]
      def field(var)
        each_element { |xe|
          return xe if xe.kind_of?(XDataField) and xe.var == var
        }
        nil
      end

      ##
      # Type of this Data Form
      # result:: * :cancel
      #          * :form
      #          * :result
      #          * :submit
      #          * nil
      def type
        case attributes['type']
          when 'cancel' then :cancel
          when 'form' then :form
          when 'result' then :result
          when 'submit' then :submit
          else nil
        end
      end

      ##
      # Set the type (see type)
      def type=(t)
        case t
          when :cancel then attributes['type'] = 'cancel'
          when :form then attributes['type'] = 'form'
          when :result then attributes['type'] = 'result'
          when :submit then attributes['type'] = 'submit'
          else attributes['type'] = nil
        end
      end
    end

    X.add_namespaceclass('jabber:x:data', XData)

    ##
    # Child of XData, contains the title of this Data Form
    class XDataTitle < REXML::Element
      def initialize
        super('title')
      end
      def to_s
        text.to_s
      end
      def title
        text
      end
    end

    ##
    # Child of XData, contains the instructions of this Data Form
    class XDataInstructions < REXML::Element
      def initialize
        super('instructions')
      end
      def to_s
        text.to_s
      end
      def instructions
        text
      end
    end

    ##
    # Child of XData, contains configurable/configured options of this Data Form
    class XDataField < REXML::Element
      def initialize(var=nil, type=nil)
        super('field')
        self.var = var
        self.type = type
      end

      def label
        attributes['label']
      end

      def label=(s)
        attributes['label'] = s
      end

      def var
        attributes['var']
      end

      def var=(s)
        attributes['var'] = s
      end

      ##
      # Type of this field
      # result::
      #          * :boolean
      #          * :fixed
      #          * :hidden
      #          * :jid_multi
      #          * :jid_single
      #          * :list_multi
      #          * :list_single
      #          * :text_multi
      #          * :text_private
      #          * :text_single
      #          * nil
      def type
        case attributes['type']
          when 'boolean' then :boolean
          when 'fixed' then :fixed
          when 'hidden' then :hidden
          when 'jid-multi' then :jid_multi
          when 'jid-single' then :jid_single
          when 'list-multi' then :list_multi
          when 'list-single' then :list_single
          when 'text-multi' then :text_multi
          when 'text-private' then :text_private
          when 'text-single' then :text_single
          else nil
        end
      end

      ##
      # Set the type of this field (see type)
      def type=(t)
        case t
          when :boolean then attributes['type'] = 'boolean'
          when :fixed then attributes['type'] = 'fixed'
          when :hidden then attributes['type'] = 'hidden'
          when :jid_multi then attributes['type'] = 'jid-multi'
          when :jid_single then attributes['type'] = 'jid-single'
          when :list_multi then attributes['type'] = 'list-multi'
          when :list_single then attributes['type'] = 'list-single'
          when :text_multi then attributes['type'] = 'text-multi'
          when :text_private then attributes['type'] = 'text-private'
          when :text_single then attributes['type'] = 'text-single'
          else attributes['type'] = nil
        end
      end

      ##
      # Is this field required (has the <required/> child)?
      def required?
        res = false
        each_element('required') { res = true }
        res
      end

      ##
      # Set if this field is required
      # r:: [true] or [false]
      def required=(r)
        delete_elements('required')
        if r
          add REXML::Element.new('required')
        end
      end

      ##
      # Get the values (in a Data Form with type='submit')
      def values
        res = []
        each_element('value') { |e|
          res << e.text
        }
        res
      end

      ##
      # Set the values
      def values=(ary)
        delete_elements('value')
        ary.each { |v|
          add(REXML::Element.new('value')).text = v
        }
      end

      ##
      # Get the options (in a Data Form with type='form')
      def options
        res = {}
        each_element('option') { |e|
          value = nil
          e.each_element('value') { |ve| value = ve.text }
          res[value] = e.attributes['label']
        }
        res
      end

      ##
      # Set the options
      def options=(hsh)
        delete_elements('option')
        hsh.each { |value,label|
          o = add(REXML::Element.new('option'))
          o.attributes['label'] = label
          o.add(REXML::Element.new('value')).text = value
        }
      end
    end

    ##
    # The <reported/> element, can contain XDataField elements
    class XDataReported < REXML::Element
      def initialize
        super('reported')
      end
    end
  end
end

