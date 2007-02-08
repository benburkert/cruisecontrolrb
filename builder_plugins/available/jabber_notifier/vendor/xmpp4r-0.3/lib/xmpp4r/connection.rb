# =XMPP4R - XMPP Library for Ruby
# License:: Ruby's license (see the LICENSE file) or GNU GPL, at your option.
# Website::http://home.gna.org/xmpp4r/

require 'openssl'
require 'xmpp4r/stream'
require 'xmpp4r/errorexception'

module Jabber
  ##
  # The connection class manages the TCP connection to the Jabber server
  #
  class Connection  < Stream
    attr_reader :host, :port

    # Allow TLS negotiation? Defaults to true
    attr_accessor :allow_tls

    # How many seconds to wait for <stream:features/>
    # before proceeding
    attr_accessor :features_timeout

    # Optional CA-Path for TLS-handshake
    attr_accessor :ssl_capath

    # Optional callback for verification of SSL peer
    attr_accessor :ssl_verifycb

    ##
    # Create a new connection to the given host and port, using threaded mode
    # or not.
    def initialize(threaded = true)
      super(threaded)
      @host = nil
      @port = nil
      @allow_tls = true
      @tls = false
      @ssl_capath = nil
      @ssl_verifycb = nil
      @features_timeout = 10
    end

    ##
    # Connects to the Jabber server through a TCP Socket and
    # starts the Jabber parser.
    def connect(host, port)
      @host = host
      @port = port
      # Reset is_tls?, so that it works when reconnecting
      @tls = false

      Jabber::debuglog("CONNECTING:\n#{@host}:#{@port}")
      @socket = TCPSocket.new(@host, @port)
      start

      accept_features
    end

    def accept_features
      begin
        Timeout::timeout(@features_timeout) {
          Jabber::debuglog("FEATURES: waiting...")
          @features_lock.lock
          @features_lock.unlock
          Jabber::debuglog("FEATURES: waiting finished")
        }
      rescue Timeout::Error
        Jabber::debuglog("FEATURES: timed out when waiting, stream peer seems not XMPP compliant")
      end

      if @allow_tls and not is_tls? and @stream_features['starttls'] == 'urn:ietf:params:xml:ns:xmpp-tls'
        begin
          starttls
        rescue
          Jabber::debuglog("STARTTLS:\nFailure: #{$!}")
        end
      end
    end

    ##
    # Start the parser on the previously connected socket
    def start
      @features_lock.lock

      super(@socket)
    end

    ##
    # Do a <starttls/>
    # (will be automatically done by connect if stream peer supports this)
    def starttls
      stls = REXML::Element.new('starttls')
      stls.add_namespace('urn:ietf:params:xml:ns:xmpp-tls')

      reply = nil
      send(stls) { |r|
        reply = r
        true
      }
      if reply.name != 'proceed'
        raise ErrorException(reply.first_element('error'))
      end
      # Don't be interrupted
      stop

      begin
        error = nil

        # Context/user set-able stuff
        ctx = OpenSSL::SSL::SSLContext.new('TLSv1')
        if @ssl_capath
          ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
          ctx.ca_path = @ssl_capath
        else
          ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        ctx.verify_callback = @ssl_verifycb

        # SSL connection establishing
        sslsocket = OpenSSL::SSL::SSLSocket.new(@socket, ctx)
        sslsocket.sync_close = true
        Jabber::debuglog("TLSv1: OpenSSL handshake in progress")
        sslsocket.connect

        # Make REXML believe it's a real socket
        class << sslsocket
          def kind_of?(o)
            o == IO ? true : super
          end
        end

        # We're done and will use it
        @tls = true
        @socket = sslsocket
      rescue
        error = $!
      ensure
        Jabber::debuglog("TLSv1: restarting parser")
        start
        accept_features
        raise error if error
      end
    end

    ##
    # Have we gone to TLS mode?
    # result:: [true] or [false]
    def is_tls?
      @tls
    end

    def generate_stream_start(to=nil, from=nil, id=nil, xml_lang="en", xmlns="jabber:client", version="1.0")
      stream_start_string = "<stream:stream xmlns:stream='http://etherx.jabber.org/streams' "
      stream_start_string += "xmlns='#{xmlns}' " unless xmlns.nil?
      stream_start_string += "to='#{to}' " unless to.nil?
      stream_start_string += "from='#{from}' " unless from.nil?
      stream_start_string += "id='#{id}' " unless id.nil?      
      stream_start_string += "xml:lang='#{xml_lang}' " unless xml_lang.nil?
      stream_start_string += "version='#{version}' " unless version.nil?
      stream_start_string += ">"
      stream_start_string
    end
    private :generate_stream_start
    
  end  
end
