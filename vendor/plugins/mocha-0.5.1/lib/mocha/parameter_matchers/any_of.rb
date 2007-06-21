module Mocha
  
  module ParameterMatchers

    # :call-seq: any_of -> parameter_matcher
    #
    # Matches if any +matchers+ match.
    #   object = mock()
    #   object.expects(:method_1).with(any_of(1, 3))
    #   object.method_1(1)
    #   # no error raised
    #
    #   object = mock()
    #   object.expects(:method_1).with(any_of(1, 3))
    #   object.method_1(3)
    #   # no error raised
    #
    #   object = mock()
    #   object.expects(:method_1).with(any_of(1, 3))
    #   object.method_1(2)
    #   # error raised, because method_1 was not called with 1 or 3
    def any_of(*matchers)
      AnyOf.new(*matchers)
    end
    
    class AnyOf # :nodoc:
      
      def initialize(*matchers)
        @matchers = matchers
      end
    
      def ==(parameter)
        @matchers.any? { |matcher| matcher == parameter }
      end
      
      def mocha_inspect
        "any_of(#{@matchers.map { |matcher| matcher.mocha_inspect }.join(", ") })"
      end
      
    end
    
  end
  
end