# =XMPP4R - XMPP Library for Ruby
# License:: Ruby's license (see the LICENSE file) or GNU GPL, at your option.
# Website::http://home.gna.org/xmpp4r/

module Jabber
  module Bytestreams
    ##
    # Class for accessing <query/> elements with
    # xmlns='http://jabber.org/protocol/bytestreams'
    # in <iq/> stanzas.
    class IqQueryBytestreams < IqQuery
      NS_BYTESTREAMS = 'http://jabber.org/protocol/bytestreams'

      ##
      # Initialize such a <query/>
      # sid:: [String] Session-ID
      # mode:: [Symbol] :tcp or :udp
      def initialize(sid=nil, mode=nil)
        super()
        add_namespace(IqQueryBytestreams::NS_BYTESTREAMS)
        self.sid = sid
        self.mode = mode
      end

      def typed_add(xe)
        if xe.kind_of?(REXML::Element) and xe.name == 'streamhost'
          super StreamHost.new.import(xe)
        elsif xe.kind_of?(REXML::Element) and xe.name == 'streamhost-used'
          super StreamHostUsed.new.import(xe)
        else
          super xe
        end
      end

      ##
      # Session-ID
      def sid
        attributes['sid']
      end

      ##
      # Set Session-ID
      def sid=(s)
        attributes['sid'] = s
      end

      ##
      # Transfer mode
      # result:: :tcp or :udp
      def mode
        case attributes['mode']
          when 'udp' then :udp
          else :tcp
        end
      end

      ##
      # Set the transfer mode
      # m:: :tcp or :udp
      def mode=(m)
        case m
          when :udp then attributes['mode'] = 'udp'
          else attributes['mode'] = 'tcp'
        end
      end

      ##
      # Get the <streamhost-used/> child
      # result:: [StreamHostUsed]
      def streamhost_used
        first_element('streamhost-used')
      end

      ##
      # Get the text of the <activate/> child
      # result:: [JID] or [nil]
      def activate
        j = first_element_text('activate')
        j ? JID.new(j) : nil
      end

      ##
      # Set the text of the <activate/> child
      # s:: [JID]
      def activate=(s)
        replace_element_text('activate', s ? s.to_s : nil)
      end
    end

    IqQuery.add_namespaceclass(IqQueryBytestreams::NS_BYTESTREAMS, IqQueryBytestreams)

    ##
    # <streamhost/> element, normally appear
    # as children of IqQueryBytestreams
    class StreamHost < REXML::Element
      ##
      # Initialize a <streamhost/> element
      # jid:: [JID]
      # host:: [String] Hostname or IP address
      # port:: [Fixnum] Port number
      def initialize(jid=nil, host=nil, port=nil)
        super('streamhost')
        self.jid = jid
        self.host = host
        self.port = port
      end

      ##
      # Get the JID of the streamhost
      def jid
        (a = attributes['jid']) ? JID.new(a) : nil
      end

      ##
      # Set the JID of the streamhost
      def jid=(j)
        attributes['jid'] = (j ? j.to_s : nil)
      end

      ##
      # Get the host address of the streamhost
      def host
        attributes['host']
      end

      ##
      # Set the host address of the streamhost
      def host=(h)
        attributes['host'] = h
      end

      ##
      # Get the zeroconf attribute of the streamhost
      def zeroconf
        attributes['zeroconf']
      end

      ##
      # Set the zeroconf attribute of the streamhost
      def zeroconf=(s)
        attributes['zeroconf'] = s
      end

      ##
      # Get the port number of the streamhost
      def port
        p = attributes['port'].to_i
        (p == 0 ? nil : p)
      end

      ##
      # Set the port number of the streamhost
      def port=(p)
        attributes['port'] = p.to_s
      end
    end

    ##
    # <streamhost-used/> element, normally appears
    # as child of IqQueryBytestreams
    class StreamHostUsed < REXML::Element
      def initialize(jid=nil)
        super('streamhost-used')
        self.jid = jid
      end

      def jid
        (a = attributes['jid']) ? JID.new(a) : nil
      end

      def jid=(j)
        attributes['jid'] = (j ? j.to_s : nil)
      end
    end
  end
end

