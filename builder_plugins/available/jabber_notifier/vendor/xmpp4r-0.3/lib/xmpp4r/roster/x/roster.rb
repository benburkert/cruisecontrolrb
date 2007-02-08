# =XMPP4R - XMPP Library for Ruby
# License:: Ruby's license (see the LICENSE file) or GNU GPL, at your option.
# Website::http://home.gna.org/xmpp4r/

require 'xmpp4r/x'
require 'xmpp4r/jid'

module Jabber
  module Roster
  ##
  # Implementation of JEP-0144
  # for <tt><x xmlns='http://jabber.org/protocol/rosterx'/></tt>
  # attached to <tt><message/></tt> stanzas
  #
  # Should be backwards compatible to JEP-0093,
  # as only action attribute of roster items are missing there.
  # Pay attention to the namespace which is <tt>jabber:x:roster</tt>
  # for JEP-0093!
    class XRoster < X
      ##
      # Initialize a new XRoster element
      def initialize
        super()
        add_namespace('http://jabber.org/protocol/rosterx')
      end
      
      ##
      # Add an element to the roster attachment
      #
      # Converts <item/> elements to XRosterItem
      def typed_add(element)
        if element.kind_of?(REXML::Element) && (element.name == 'item')
          super(XRosterItem::new.import(element))
        else
          super(element)
        end
      end
    end #Class XRoster
    
    X.add_namespaceclass('jabber:x:roster', XRoster)
    X.add_namespaceclass('http://jabber.org/protocol/rosterx', XRoster)
    
    ##
    # Class containing an <item/> element
    #
    # The 'name' attribute has been renamed to 'iname' here
    # as 'name' is already used by REXML::Element for the
    # element's name. It's still name='...' in XML.
    #
    # This is all a bit analoguous to Jabber::RosterItem, used by
    # Jabber::IqQueryRoster. But this class lacks the subscription and
    # ask attributes.
    class XRosterItem < REXML::Element
      ##
      # Construct a new roster item
      # jid:: [JID] Jabber ID
      # iname:: [String] Name in the roster
      def initialize(jid=nil, iname=nil)
        super('item')
        self.jid = jid
        self.iname = iname
      end
      
      ##
      # Create new XRosterItem from REXML::Element
      # item:: [REXML::Element] source element to copy attributes and children from
      def XRosterItem.import(item)
        XRosterItem::new.import(item)
      end
      
      ##
      # Get name of roster item
      #
      # names can be set by the roster's owner himself
      # return:: [String]
      def iname
        attributes['name']
      end
      
      ##
      # Set name of roster item
      # val:: [String] Name for this item
      def iname=(val)
        attributes['name'] = val
      end
      
      ##
      # Get JID of roster item
      # Resource of the JID will _not_ be stripped
      # return:: [JID]
      def jid
        JID::new(attributes['jid'])
      end
      
      ##
      # Set JID of roster item
      # val:: [JID] or nil
      def jid=(val)
        attributes['jid'] = val.nil? ? nil : val.to_s
      end
      
      ##
      # Get action for this roster item
      # * :add
      # * :modify
      # * :delete
      # result:: [Symbol] (defaults to :add according to JEP-0144)
      def action
        case attributes['action']
          when 'modify' then :modify
          when 'delete' then :delete
          else :add
        end
      end
      
      ##
      # Set action for this roster item
      # (see action)
      def action=(a)
        case a
          when :modify then attributes['action'] = 'modify'
          when :delete then attributes['action'] = 'delete'
          else attributes['action'] = 'add'
        end
      end

      ##
      # Get groups the item belongs to
      # result:: [Array] of [String] The groups
      def groups
        result = []
        each_element('group') { |group|
          result.push(group.text)
        }
        result
      end
      
      ##
      # Set groups the item belongs to,
      # deletes old groups first.
      #
      # See JEP 0083 for nested groups
      # ary:: [Array] New groups, duplicate values will be removed
      def groups=(ary)
        # Delete old group elements
        delete_elements('group')
        
        # Add new group elements
        ary.uniq.each { |group|
          add_element('group').text = group
        }
      end
    end #Class XRosterItem
  end #Module Roster
end #Module Jabber
