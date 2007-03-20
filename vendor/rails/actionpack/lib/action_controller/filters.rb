module ActionController #:nodoc:
  module Filters #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, ActionController::Filters::InstanceMethods)
    end

    # Filters enable controllers to run shared pre and post processing code for its actions. These filters can be used to do
    # authentication, caching, or auditing before the intended action is performed. Or to do localization or output
    # compression after the action has been performed. Filters have access to the request, response, and all the instance
    # variables set by other filters in the chain or by the action (in the case of after filters).
    #
    # == Filter inheritance
    #
    # Controller inheritance hierarchies share filters downwards, but subclasses can also add or skip filters without
    # affecting the superclass. For example:
    #
    #   class BankController < ActionController::Base
    #     before_filter :audit
    #
    #     private
    #       def audit
    #         # record the action and parameters in an audit log
    #       end
    #   end
    #
    #   class VaultController < BankController
    #     before_filter :verify_credentials
    #
    #     private
    #       def verify_credentials
    #         # make sure the user is allowed into the vault
    #       end
    #   end
    #
    # Now any actions performed on the BankController will have the audit method called before. On the VaultController,
    # first the audit method is called, then the verify_credentials method. If the audit method returns false, then
    # verify_credentials and the intended action are never called.
    #
    # == Filter types
    #
    # A filter can take one of three forms: method reference (symbol), external class, or inline method (proc). The first
    # is the most common and works by referencing a protected or private method somewhere in the inheritance hierarchy of
    # the controller by use of a symbol. In the bank example above, both BankController and VaultController use this form.
    #
    # Using an external class makes for more easily reused generic filters, such as output compression. External filter classes
    # are implemented by having a static +filter+ method on any class and then passing this class to the filter method. Example:
    #
    #   class OutputCompressionFilter
    #     def self.filter(controller)
    #       controller.response.body = compress(controller.response.body)
    #     end
    #   end
    #
    #   class NewspaperController < ActionController::Base
    #     after_filter OutputCompressionFilter
    #   end
    #
    # The filter method is passed the controller instance and is hence granted access to all aspects of the controller and can
    # manipulate them as it sees fit.
    #
    # The inline method (using a proc) can be used to quickly do something small that doesn't require a lot of explanation.
    # Or just as a quick test. It works like this:
    #
    #   class WeblogController < ActionController::Base
    #     before_filter { |controller| false if controller.params["stop_action"] }
    #   end
    #
    # As you can see, the block expects to be passed the controller after it has assigned the request to the internal variables.
    # This means that the block has access to both the request and response objects complete with convenience methods for params,
    # session, template, and assigns. Note: The inline method doesn't strictly have to be a block; any object that responds to call
    # and returns 1 or -1 on arity will do (such as a Proc or an Method object).
    #
    # Please note that around_filters function a little differently than the normal before and after filters with regard to filter
    # types. Please see the section dedicated to around_filters below.
    #
    # == Filter chain ordering
    #
    # Using <tt>before_filter</tt> and <tt>after_filter</tt> appends the specified filters to the existing chain. That's usually
    # just fine, but some times you care more about the order in which the filters are executed. When that's the case, you
    # can use <tt>prepend_before_filter</tt> and <tt>prepend_after_filter</tt>. Filters added by these methods will be put at the
    # beginning of their respective chain and executed before the rest. For example:
    #
    #   class ShoppingController < ActionController::Base
    #     before_filter :verify_open_shop
    #
    #   class CheckoutController < ShoppingController
    #     prepend_before_filter :ensure_items_in_cart, :ensure_items_in_stock
    #
    # The filter chain for the CheckoutController is now <tt>:ensure_items_in_cart, :ensure_items_in_stock,</tt>
    # <tt>:verify_open_shop</tt>. So if either of the ensure filters return false, we'll never get around to see if the shop
    # is open or not.
    #
    # You may pass multiple filter arguments of each type as well as a filter block.
    # If a block is given, it is treated as the last argument.
    #
    # == Around filters
    #
    # Around filters wrap an action, executing code both before and after.
    # They may be declared as method references, blocks, or objects responding
    # to #filter or to both #before and #after.
    #
    # To use a method as an around_filter, pass a symbol naming the Ruby method.
    # Yield (or block.call) within the method to run the action.
    #
    #   around_filter :catch_exceptions
    #
    #   private
    #     def catch_exceptions
    #       yield
    #     rescue => exception
    #       logger.debug "Caught exception! #{exception}"
    #       raise
    #     end
    #
    # To use a block as an around_filter, pass a block taking as args both
    # the controller and the action block. You can't call yield directly from
    # an around_filter block; explicitly call the action block instead:
    #
    #   around_filter do |controller, action|
    #     logger.debug "before #{controller.action_name}"
    #     action.call
    #     logger.debug "after #{controller.action_name}"
    #   end
    #
    # To use a filter object with around_filter, pass an object responding
    # to :filter or both :before and :after. With a filter method, yield to
    # the block as above:
    #
    #   around_filter BenchmarkingFilter
    #
    #   class BenchmarkingFilter
    #     def self.filter(controller, &block)
    #       Benchmark.measure(&block)
    #     end
    #   end
    #
    # With before and after methods:
    #
    #   around_filter Authorizer.new
    #
    #   class Authorizer
    #     # This will run before the action. Returning false aborts the action.
    #     def before(controller)
    #       if user.authorized?
    #         return true
    #       else
    #         redirect_to login_url
    #         return false
    #       end
    #     end
    #
    #     # This will run after the action if and only if before returned true.
    #     def after(controller)
    #     end
    #   end
    #
    # If the filter has before and after methods, the before method will be
    # called before the action. If before returns false, the filter chain is
    # halted and after will not be run. See Filter Chain Halting below for
    # an example.
    #
    # == Filter chain skipping
    #
    # Declaring a filter on a base class conveniently applies to its subclasses,
    # but sometimes a subclass should skip some of its superclass' filters:
    #
    #   class ApplicationController < ActionController::Base
    #     before_filter :authenticate
    #     around_filter :catch_exceptions
    #   end
    #
    #   class WeblogController < ApplicationController
    #     # Will run the :authenticate and :catch_exceptions filters.
    #   end
    #
    #   class SignupController < ApplicationController
    #     # Skip :authenticate, run :catch_exceptions.
    #     skip_before_filter :authenticate
    #   end
    #
    #   class ProjectsController < ApplicationController
    #     # Skip :catch_exceptions, run :authenticate.
    #     skip_filter :catch_exceptions
    #   end
    #
    #   class ClientsController < ApplicationController
    #     # Skip :catch_exceptions and :authenticate unless action is index.
    #     skip_filter :catch_exceptions, :authenticate, :except => :index
    #   end
    #
    # == Filter conditions
    #
    # Filters may be limited to specific actions by declaring the actions to
    # include or exclude. Both options accept single actions (:only => :index)
    # or arrays of actions (:except => [:foo, :bar]).
    #
    #   class Journal < ActionController::Base
    #     # Require authentication for edit and delete.
    #     before_filter :authorize, :only => [:edit, :delete]
    #
    #     # Passing options to a filter with a block.
    #     around_filter(:except => :index) do |controller, action_block|
    #       results = Profiler.run(&action_block)
    #       controller.response.sub! "</body>", "#{results}</body>"
    #     end
    #
    #     private
    #       def authorize
    #         # Redirect to login unless authenticated.
    #       end
    #   end
    #
    # == Filter Chain Halting
    #
    # <tt>before_filter</tt> and <tt>around_filter</tt> may halt the request
    # before controller action is run. This is useful, for example, to deny
    # access to unauthenticated users or to redirect from http to https.
    # Simply return false from the filter or call render or redirect.
    #
    # Around filters halt the request unless the action block is called.
    # Given these filters
    #   after_filter :after
    #   around_filter :around
    #   before_filter :before
    #
    # The filter chain will look like:
    #
    #   ...
    #   . \
    #   .  #around (code before yield)
    #   .  .  \
    #   .  .  #before (actual filter code is run)
    #   .  .  .  \
    #   .  .  .  execute controller action
    #   .  .  .  /
    #   .  .  ...
    #   .  .  /
    #   .  #around (code after yield)
    #   . /
    #   #after (actual filter code is run)
    #
    # If #around returns before yielding, only #after will be run. The #before
    # filter and controller action will not be run.  If #before returns false,
    # the second half of #around and all of #after will still run but the
    # action will not.
    module ClassMethods
      # The passed <tt>filters</tt> will be appended to the filter_chain and
      # will execute before the action on this controller is performed.
      def append_before_filter(*filters, &block)
        append_filter_to_chain(filters, :before, &block)
      end

      # The passed <tt>filters</tt> will be prepended to the filter_chain and
      # will execute before the action on this controller is performed.
      def prepend_before_filter(*filters, &block)
        prepend_filter_to_chain(filters, :before, &block)
      end

      # Shorthand for append_before_filter since it's the most common.
      alias :before_filter :append_before_filter

      # The passed <tt>filters</tt> will be appended to the array of filters
      # that run _after_ actions on this controller are performed.
      def append_after_filter(*filters, &block)
        prepend_filter_to_chain(filters, :after, &block)
      end

      # The passed <tt>filters</tt> will be prepended to the array of filters
      # that run _after_ actions on this controller are performed.
      def prepend_after_filter(*filters, &block)
        append_filter_to_chain(filters, :after, &block)
      end

      # Shorthand for append_after_filter since it's the most common.
      alias :after_filter :append_after_filter


      # If you append_around_filter A.new, B.new, the filter chain looks like
      #
      #   B#before
      #     A#before
      #       # run the action
      #     A#after
      #   B#after
      #
      # With around filters which yield to the action block, #before and #after
      # are the code before and after the yield.
      def append_around_filter(*filters, &block)
        filters, conditions = extract_conditions(filters, &block)
        filters.map { |f| proxy_before_and_after_filter(f) }.each do |filter|
          append_filter_to_chain([filter, conditions])
        end
      end

      # If you prepend_around_filter A.new, B.new, the filter chain looks like:
      #
      #   A#before
      #     B#before
      #       # run the action
      #     B#after
      #   A#after
      #
      # With around filters which yield to the action block, #before and #after
      # are the code before and after the yield.
      def prepend_around_filter(*filters, &block)
        filters, conditions = extract_conditions(filters, &block)
        filters.map { |f| proxy_before_and_after_filter(f) }.each do |filter|
          prepend_filter_to_chain([filter, conditions])
        end
      end

      # Shorthand for append_around_filter since it's the most common.
      alias :around_filter :append_around_filter

      # Removes the specified filters from the +before+ filter chain. Note that this only works for skipping method-reference
      # filters, not procs. This is especially useful for managing the chain in inheritance hierarchies where only one out
      # of many sub-controllers need a different hierarchy.
      #
      # You can control the actions to skip the filter for with the <tt>:only</tt> and <tt>:except</tt> options,
      # just like when you apply the filters.
      def skip_before_filter(*filters)
        skip_filter_in_chain(*filters, &:before?)
      end

      # Removes the specified filters from the +after+ filter chain. Note that this only works for skipping method-reference
      # filters, not procs. This is especially useful for managing the chain in inheritance hierarchies where only one out
      # of many sub-controllers need a different hierarchy.
      #
      # You can control the actions to skip the filter for with the <tt>:only</tt> and <tt>:except</tt> options,
      # just like when you apply the filters.
      def skip_after_filter(*filters)
        skip_filter_in_chain(*filters, &:after?)
      end

      # Removes the specified filters from the filter chain. This only works for method reference (symbol)
      # filters, not procs. This method is different from skip_after_filter and skip_before_filter in that
      # it will match any before, after or yielding around filter.
      #
      # You can control the actions to skip the filter for with the <tt>:only</tt> and <tt>:except</tt> options,
      # just like when you apply the filters.
      def skip_filter(*filters)
        skip_filter_in_chain(*filters)
      end

      # Returns an array of Filter objects for this controller.
      def filter_chain
        read_inheritable_attribute("filter_chain") || []
      end

      # Returns all the before filters for this class and all its ancestors.
      # This method returns the actual filter that was assigned in the controller to maintain existing functionality.
      def before_filters #:nodoc:
        filter_chain.select(&:before?).map(&:filter)
      end

      # Returns all the after filters for this class and all its ancestors.
      # This method returns the actual filter that was assigned in the controller to maintain existing functionality.
      def after_filters #:nodoc:
        filter_chain.select(&:after?).map(&:filter)
      end

      # Returns a mapping between filters and the actions that may run them.
      def included_actions #:nodoc:
        read_inheritable_attribute("included_actions") || {}
      end

      # Returns a mapping between filters and actions that may not run them.
      def excluded_actions #:nodoc:
        read_inheritable_attribute("excluded_actions") || {}
      end

      # Find a filter in the filter_chain where the filter method matches the _filter_ param
      # and (optionally) the passed block evaluates to true (mostly used for testing before?
      # and after? on the filter). Useful for symbol filters.
      #
      # The object of type Filter is passed to the block when yielded, not the filter itself.
      def find_filter(filter, &block) #:nodoc:
        filter_chain.select { |f| f.filter == filter && (!block_given? || yield(f)) }.first
      end

      # Returns true if the filter is excluded from the given action
      def filter_excluded_from_action?(filter,action) #:nodoc:
        if (ia = included_actions[filter]) && !ia.empty?
          !ia.include?(action)
        else
          (excluded_actions[filter] || []).include?(action)
        end
      end

      # Filter class is an abstract base class for all filters. Handles all of the included/excluded actions but
      # contains no logic for calling the actual filters.
      class Filter #:nodoc:
        attr_reader :filter, :included_actions, :excluded_actions

        def initialize(filter)
          @filter = filter
        end

        def before?
          false
        end

        def after?
          false
        end

        def around?
          true
        end

        def call(controller, &block)
          raise(ActionControllerError, 'No filter type: Nothing to do here.')
        end
      end

      # Abstract base class for filter proxies. FilterProxy objects are meant to mimic the behaviour of the old
      # before_filter and after_filter by moving the logic into the filter itself.
      class FilterProxy < Filter #:nodoc:
        def filter
          @filter.filter
        end

        def around?
          false
        end
      end

      class BeforeFilterProxy < FilterProxy #:nodoc:
        def before?
          true
        end

        def call(controller, &block)
          if false == @filter.call(controller) # must only stop if equal to false. only filters returning false are halted.
            controller.halt_filter_chain(@filter, :returned_false)
          else
            yield
          end
        end
      end

      class AfterFilterProxy < FilterProxy #:nodoc:
        def after?
          true
        end

        def call(controller, &block)
          yield
          @filter.call(controller)
        end
      end

      class SymbolFilter < Filter #:nodoc:
        def call(controller, &block)
          controller.send(@filter, &block)
        end
      end

      class ProcFilter < Filter #:nodoc:
        def call(controller)
          @filter.call(controller)
        rescue LocalJumpError # a yield from a proc... no no bad dog.
          raise(ActionControllerError, 'Cannot yield from a Proc type filter. The Proc must take two arguments and execute #call on the second argument.')
        end
      end

      class ProcWithCallFilter < Filter #:nodoc:
        def call(controller, &block)
          @filter.call(controller, block)
        rescue LocalJumpError # a yield from a proc... no no bad dog.
          raise(ActionControllerError, 'Cannot yield from a Proc type filter. The Proc must take two arguments and execute #call on the second argument.')
        end
      end

      class MethodFilter < Filter #:nodoc:
        def call(controller, &block)
          @filter.call(controller, &block)
        end
      end

      class ClassFilter < Filter #:nodoc:
        def call(controller, &block)
          @filter.filter(controller, &block)
        end
      end

      protected
        def append_filter_to_chain(filters, position = :around, &block)
          write_inheritable_array('filter_chain', create_filters(filters, position, &block) )
        end

        def prepend_filter_to_chain(filters, position = :around, &block)
          write_inheritable_attribute('filter_chain', create_filters(filters, position, &block) + filter_chain)
        end

        def create_filters(filters, position, &block) #:nodoc:
          filters, conditions = extract_conditions(filters, &block)
          filters.map! { |filter| find_or_create_filter(filter,position) }
          update_conditions(filters, conditions)
          filters
        end

        def find_or_create_filter(filter,position)
          if found_filter = find_filter(filter) { |f| f.send("#{position}?") }
            found_filter
          else
            f = class_for_filter(filter).new(filter)
            # apply proxy to filter if necessary
            case position
            when :before
              BeforeFilterProxy.new(f)
            when :after
              AfterFilterProxy.new(f)
            else
              f
            end
          end
        end

        # The determination of the filter type was once done at run time.
        # This method is here to extract as much logic from the filter run time as possible
        def class_for_filter(filter) #:nodoc:
          case
          when filter.is_a?(Symbol)
            SymbolFilter
          when filter.respond_to?(:call)
            if filter.is_a?(Method)
              MethodFilter
            elsif filter.arity == 1
              ProcFilter
            else
              ProcWithCallFilter
            end
          when filter.respond_to?(:filter)
            ClassFilter
          else
            raise(ActionControllerError, 'A filters must be a Symbol, Proc, Method, or object responding to filter.')
          end
        end

        def extract_conditions(*filters, &block) #:nodoc:
          filters.flatten!
          conditions = filters.last.is_a?(Hash) ? filters.pop : {}
          filters << block if block_given?
          return filters, conditions
        end

        def update_conditions(filters, conditions)
          return if conditions.empty?
          if conditions[:only]
            write_inheritable_hash('included_actions', condition_hash(filters, conditions[:only]))
          else
            write_inheritable_hash('excluded_actions', condition_hash(filters, conditions[:except])) if conditions[:except]
          end
        end

        def condition_hash(filters, *actions)
          actions = actions.flatten.map(&:to_s)
          filters.inject({}) { |h,f| h.update( f => (actions.blank? ? nil : actions)) }
        end

        def skip_filter_in_chain(*filters, &test) #:nodoc:
          filters, conditions = extract_conditions(filters)
          filters.map! { |f| block_given? ? find_filter(f, &test) : find_filter(f) }
          filters.compact!

          if conditions.empty?
            delete_filters_in_chain(filters)
          else
            remove_actions_from_included_actions!(filters,conditions[:only] || [])
            conditions[:only], conditions[:except] = conditions[:except], conditions[:only]
            update_conditions(filters,conditions)
          end
        end

        def remove_actions_from_included_actions!(filters,*actions)
          actions = actions.flatten.map(&:to_s)
          updated_hash = filters.inject(included_actions) do |hash,filter|
            ia = (hash[filter] || []) - actions
            ia.blank? ? hash.delete(filter) : hash[filter] = ia
            hash
          end
          write_inheritable_attribute('included_actions', updated_hash)
        end

        def delete_filters_in_chain(filters) #:nodoc:
          write_inheritable_attribute('filter_chain', filter_chain.reject { |f| filters.include?(f) })
        end

        def filter_responds_to_before_and_after(filter) #:nodoc:
          filter.respond_to?(:before) && filter.respond_to?(:after)
        end

        def proxy_before_and_after_filter(filter) #:nodoc:
          return filter unless filter_responds_to_before_and_after(filter)
          Proc.new do |controller, action|
            unless filter.before(controller) == false
              begin
                action.call
              ensure
                filter.after(controller)
              end
            end
          end
        end
    end

    module InstanceMethods # :nodoc:
      def self.included(base)
        base.class_eval do
          alias_method_chain :perform_action, :filters
          alias_method_chain :process, :filters
          alias_method_chain :process_cleanup, :filters
        end
      end

      def perform_action_with_filters
        call_filter(self.class.filter_chain, 0)
      end

      def process_with_filters(request, response, method = :perform_action, *arguments) #:nodoc:
        @before_filter_chain_aborted = false
        process_without_filters(request, response, method, *arguments)
      end

      def filter_chain
        self.class.filter_chain
      end

      def call_filter(chain, index)
        return (performed? || perform_action_without_filters) if index >= chain.size
        filter = chain[index]
        return call_filter(chain, index.next) if self.class.filter_excluded_from_action?(filter,action_name)

        halted = false
        filter.call(self) do
          halted = call_filter(chain, index.next)
        end
        halt_filter_chain(filter.filter, :no_yield) if halted == false unless @before_filter_chain_aborted
        halted
      end

      def halt_filter_chain(filter, reason)
        if logger
          case reason
          when :no_yield
            logger.info "Filter chain halted as [#{filter.inspect}] did not yield."
          when :returned_false
            logger.info "Filter chain halted as [#{filter.inspect}] returned false."
          end
        end
        @before_filter_chain_aborted = true
        return false
      end

      private
        def process_cleanup_with_filters
          if @before_filter_chain_aborted
            close_session
          else
            process_cleanup_without_filters
          end
        end
    end
  end
end
