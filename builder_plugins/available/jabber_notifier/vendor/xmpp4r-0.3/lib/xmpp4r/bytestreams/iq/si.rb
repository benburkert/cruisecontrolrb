require 'time'  # For Time#xmlschema

require 'xmpp4r/feature_negotiation/iq/feature'

module Jabber
  module Bytestreams
    ##
    # Iq child 'si' for Stream-Initiation
    class IqSi < REXML::Element
      PROFILE_FILETRANSFER = 'http://jabber.org/protocol/si/profile/file-transfer'

      def initialize(id=nil, profile=nil, mime_type=nil)
        super('si')

        add_namespace 'http://jabber.org/protocol/si'
        self.id = id
        self.profile = profile
        self.mime_type = mime_type
      end

      def IqSi.import(element)
        IqSi::new.import(element)
      end

      def typed_add(element)
        if element.kind_of?(REXML::Element) and element.name == 'file'
          super IqSiFile.new.import(element)
        elsif element.kind_of?(REXML::Element) and element.name == 'feature'
          super FeatureNegotiation::IqFeature.new.import(element)
        else
          super element
        end
      end

      ##
      # Session ID of this stream
      def id
        attributes['id']
      end

      ##
      # Set Session ID of this stream
      def id=(s)
        attributes['id'] = s
      end

      ##
      # MIME type of this stream
      def mime_type
        attributes['mime-type']
      end

      ##
      # Set MIME type of this stream
      def mime_type=(s)
        attributes['mime-type'] = s
      end

      ##
      # Stream profile, can indicate file-transfer
      def profile
        attributes['profile']
      end

      ##
      # Set stream profile
      def profile=(s)
        attributes['profile'] = s
      end

      ##
      # <file/> child
      # result:: [IqSiFile]
      def file
        first_element('file')
      end

      ##
      # <feature/> child
      # result:: [IqFeature]
      def feature
        first_element('feature')
      end
    end

    Iq.add_elementclass('si', IqSi)

    ##
    # File-transfer meta-information,
    # may appear as <file/> in IqSi
    class IqSiFile < REXML::Element
      def initialize(fname=nil, size=nil)
        super 'file'
        add_namespace IqSi::PROFILE_FILETRANSFER
        self.fname = fname
        self.size = size
      end

      def typed_add(element)
        if element.kind_of?(REXML::Element) and element.name == 'range'
          super IqSiFileRange.new.import(element)
        else
          super element
        end
      end

      ##
      # Get filename (attribute 'name')
      def fname
        attributes['name']
      end

      ##
      # Set filename (attribute 'name')
      def fname=(s)
        attributes['name'] = s
      end

      ##
      # Get MD5 hash
      def hash
        attributes['hash']
      end

      ##
      # Set MD5 hash
      def hash=(s)
        attributes['hash'] = s
      end

      ##
      # Get file date
      # result:: [Time] or nil
      def date
        begin
          Time.xmlschema(attributes['date'])
        rescue ArgumentError
          nil
        end
      end

      ##
      # Set file date
      # d:: [Time] or nil
      def date=(d)
        attributes['date'] = (d ? d.xmlschema : nil)
      end

      ##
      # File size in bytes
      # result:: [Fixnum]
      def size
        (attributes['size'] =~ /^\d+$/) ? attributes['size'].to_i : nil
      end

      ##
      # Set file size
      def size=(s)
        attributes['size'] = s ? s.to_s : nil
      end

      ##
      # File description
      def description
        first_element_text('desc')
      end

      ##
      # Set file description
      def description=(s)
        replace_element_text('desc', s)
      end

      ##
      # <range/> child
      #
      # A file-transfer offer may contain this with
      # no attributes set, indicating the ability to
      # do ranged transfers.
      # result:: [IqSiFileRange]
      def range
        first_element('range')
      end
    end

    ##
    # Information for ranged transfers
    class IqSiFileRange < REXML::Element
      def initialize(offset=nil, length=nil)
        super('range')

        self.offset = offset
        self.length = length
      end

      ##
      # File offset (for continuing an interrupted transfer)
      def offset
        (attributes['offset'] =~ /^\d+$/) ? attributes['offset'].to_i : nil
      end

      ##
      # Set file offset
      def offset=(o)
        attributes['offset'] = (o ? o.to_s : nil)
      end

      ##
      # File length (if not to transfer whole file)
      def length
        (attributes['length'] =~ /^\d+$/) ? attributes['length'].to_i : nil
      end

      ##
      # Set file length
      def length=(o)
        attributes['length'] = (o ? o.to_s : nil)
      end
    end
  end
end
