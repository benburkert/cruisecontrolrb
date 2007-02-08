# =XMPP4R - XMPP Library for Ruby
# License:: Ruby's license (see the LICENSE file) or GNU GPL, at your option.
# Website::http://home.gna.org/xmpp4r/

module Jabber
  ##
  # A class used to build/parse <error/> elements.
  # Look at JEP 0086 for explanation.
  class Error < REXML::Element
    ##
    # errorcondition:: [nil] or [String] of the following:
    # * "bad-request"
    # * "conflict"
    # * "feature-not-implemented"
    # * "forbidden"
    # * "gone"
    # * "internal-server-error"
    # * "item-not-found"
    # * "jid-malformed"
    # * "not-acceptable"
    # * "not-allowed"
    # * "not-authorized"
    # * "payment-required"
    # * "recipient-unavailable"
    # * "redirect"
    # * "registration-required"
    # * "remote-server-not-found"
    # * "remote-server-timeout"
    # * "resource-constraint"
    # * "service-unavailable"
    # * "subscription-required"
    # * "undefined-condition"
    # * "unexpected-request"
    # Will raise an [Exception] if not [nil] and none of the above
    #
    # Does also set type and code to appropriate values according to errorcondition
    #
    # text: [nil] or [String] Error text
    def initialize(errorcondition=nil, text=nil)
      if errorcondition.nil?
        super('error')
        set_text(text) unless text.nil?
      else
        errortype = nil
        errorcode = nil
        @@Errors.each { |cond,type,code|
          if errorcondition == cond
            errortype = type
            errorcode = code
          end
        }

        if errortype.nil? || errorcode.nil?
          raise("Unknown error condition when initializing Error")
        end
        
        super("error")
        set_error(errorcondition)
        set_type(errortype)
        set_code(errorcode)
        set_text(text) unless text.nil?
      end
    end

    ##
    # Create a new <error/> element and import from existing
    # element:: [REXML::Element] to import
    def Error.import(element)
      Error::new.import(element)
    end
    
    ##
    # Get the 'Legacy error code' or nil
    # result:: [Integer] Error code
    def code
      if attributes['code']
        attributes['code'].to_i
      else
        nil
      end
    end

    ##
    # Set the 'Legacy error code' or nil
    # i:: [Integer] Error code
    def code=(i)
      if i.nil?
        attributes['code'] = nil
      else
        attributes['code'] = i.to_s
      end
    end

    ##
    # Set the 'Legacy error code' (chaining-friendly)
    def set_code(i)
      self.code = i
      self
    end

    ##
    # Get the 'XMPP error condition'
    #
    # This can be anything that possess the specific namespace,
    # checks don't apply here
    def error
      name = nil
      each_element { |e| name = e.name if (e.namespace == 'urn:ietf:params:xml:ns:xmpp-stanzas') && (e.name != 'text') }
      name
    end

    ##
    # Set the 'XMPP error condition'
    #
    # One previous element with that namespace will be deleted before
    #
    # s:: [String] Name of the element to be added,
    # namespace will be added automatically, checks don't apply here
    def error=(s)
      xe = nil
      each_element { |e| xe = e if (e.namespace == 'urn:ietf:params:xml:ns:xmpp-stanzas') && (e.name != 'text') }
      unless xe.nil?
        delete_element(xe)
      end

      add_element(s).add_namespace('urn:ietf:params:xml:ns:xmpp-stanzas')
    end

    ##
    # Set the 'XMPP error condition' (chaining-friendly)
    def set_error(s)
      self.error = s
      self
    end

    ##
    # Get the errors <text/> element text
    # result:: [String] or nil
    def text
      first_element_text('text') || super
    end

    ##
    # Set the errors <text/> element text
    # (Previous <text/> elements will be deleted first)
    # s:: [String] <text/> content or [nil] if no <text/> element
    def text=(s)
      delete_elements('text')

      unless s.nil?
        e = add_element('text')
        e.add_namespace('urn:ietf:params:xml:ns:xmpp-stanzas')
        e.text = s
      end
    end

    ##
    # Set the errors <text/> element text (chaining-friendly)
    def set_text(s)
      self.text = s
      self
    end
    
    ##
    # Get the type of error
    # (meaning how to proceed)
    # result:: [Symbol] or [nil] as following:
    # * :auth
    # * :cancel
    # * :continue
    # * :modify
    # * :wait
    def type
      case attributes['type']
        when 'auth' then :auth
        when 'cancel' then :cancel
        when 'continue' then :continue
        when 'modify' then :modify
        when 'wait' then :wait
        else nil
      end
    end

    ##
    # Set the type of error (see Error#type)
    def type=(t)
      case t
        when :auth then attributes['type'] = 'auth'
        when :cancel then attributes['type'] = 'cancel'
        when :continue then attributes['type'] = 'continue'
        when :modify then attributes['type'] = 'modify'
        when :wait then attributes['type'] = 'wait'
        else attributes['type'] = nil
      end
    end

    ##
    # Set the type of error (chaining-friendly)
    def set_type(t)
      self.type = t
      self
    end

    ##
    # Possible XMPP error conditions, types and codes
    # (JEP 0086)
    @@Errors = [['bad-request', :modify, 400],
                ['conflict', :cancel, 409],
                ['feature-not-implemented', :cancel, 501],
                ['forbidden', :auth, 403],
                ['gone', :modify, 302],
                ['internal-server-error', :wait, 500],
                ['item-not-found', :cancel, 404],
                ['jid-malformed', :modify, 400],
                ['not-acceptable', :modify, 406],
                ['not-allowed', :cancel, 405],
                ['not-authorized', :auth, 401],
                ['payment-required', :auth, 402],
                ['recipient-unavailable', :wait, 404],
                ['redirect', :modify, 302],
                ['registration-required', :auth, 407],
                ['remote-server-not-found', :cancel, 404],
                ['remote-server-timeout', :wait, 504],
                ['resource-constraint', :wait, 500],
                ['service-unavailable', :cancel, 503],
                ['subscription-required', :auth, 407],
                ['undefined-condition', nil, 500],
                ['unexpected-request', :wait, 400]]
  end
end
