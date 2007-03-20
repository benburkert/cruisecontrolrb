require 'observer'

module ActiveRecord
  # Callbacks are hooks into the lifecycle of an Active Record object that allows you to trigger logic
  # before or after an alteration of the object state. This can be used to make sure that associated and
  # dependent objects are deleted when destroy is called (by overwriting before_destroy) or to massage attributes
  # before they're validated (by overwriting before_validation). As an example of the callbacks initiated, consider
  # the Base#save call:
  #
  # * (-) save
  # * (-) valid?
  # * (1) before_validation
  # * (2) before_validation_on_create
  # * (-) validate
  # * (-) validate_on_create
  # * (3) after_validation
  # * (4) after_validation_on_create
  # * (5) before_save
  # * (6) before_create
  # * (-) create
  # * (7) after_create
  # * (8) after_save
  #
  # That's a total of eight callbacks, which gives you immense power to react and prepare for each state in the
  # Active Record lifecycle.
  #
  # Examples:
  #   class CreditCard < ActiveRecord::Base
  #     # Strip everything but digits, so the user can specify "555 234 34" or
  #     # "5552-3434" or both will mean "55523434"
  #     def before_validation_on_create
  #       self.number = number.gsub(/[^0-9]/, "") if attribute_present?("number")
  #     end
  #   end
  #
  #   class Subscription < ActiveRecord::Base
  #     before_create :record_signup
  #
  #     private
  #       def record_signup
  #         self.signed_up_on = Date.today
  #       end
  #   end
  #
  #   class Firm < ActiveRecord::Base
  #     # Destroys the associated clients and people when the firm is destroyed
  #     before_destroy { |record| Person.destroy_all "firm_id = #{record.id}"   }
  #     before_destroy { |record| Client.destroy_all "client_of = #{record.id}" }
  #   end
  #
  # == Inheritable callback queues
  #
  # Besides the overwriteable callback methods, it's also possible to register callbacks through the use of the callback macros.
  # Their main advantage is that the macros add behavior into a callback queue that is kept intact down through an inheritance
  # hierarchy. Example:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy :destroy_author
  #   end
  #
  #   class Reply < Topic
  #     before_destroy :destroy_readers
  #   end
  #
  # Now, when Topic#destroy is run only +destroy_author+ is called. When Reply#destroy is run both +destroy_author+ and
  # +destroy_readers+ is called. Contrast this to the situation where we've implemented the save behavior through overwriteable
  # methods:
  #
  #   class Topic < ActiveRecord::Base
  #     def before_destroy() destroy_author end
  #   end
  #
  #   class Reply < Topic
  #     def before_destroy() destroy_readers end
  #   end
  #
  # In that case, Reply#destroy would only run +destroy_readers+ and _not_ +destroy_author+. So use the callback macros when
  # you want to ensure that a certain callback is called for the entire hierarchy and the regular overwriteable methods when you
  # want to leave it up to each descendent to decide whether they want to call +super+ and trigger the inherited callbacks.
  #
  # *IMPORTANT:* In order for inheritance to work for the callback queues, you must specify the callbacks before specifying the
  # associations. Otherwise, you might trigger the loading of a child before the parent has registered the callbacks and they won't
  # be inherited.
  #
  # == Types of callbacks
  #
  # There are four types of callbacks accepted by the callback macros: Method references (symbol), callback objects,
  # inline methods (using a proc), and inline eval methods (using a string). Method references and callback objects are the
  # recommended approaches, inline methods using a proc are sometimes appropriate (such as for creating mix-ins), and inline
  # eval methods are deprecated.
  #
  # The method reference callbacks work by specifying a protected or private method available in the object, like this:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy :delete_parents
  #
  #     private
  #       def delete_parents
  #         self.class.delete_all "parent_id = #{id}"
  #       end
  #   end
  #
  # The callback objects have methods named after the callback called with the record as the only parameter, such as:
  #
  #   class BankAccount < ActiveRecord::Base
  #     before_save      EncryptionWrapper.new("credit_card_number")
  #     after_save       EncryptionWrapper.new("credit_card_number")
  #     after_initialize EncryptionWrapper.new("credit_card_number")
  #   end
  #
  #   class EncryptionWrapper
  #     def initialize(attribute)
  #       @attribute = attribute
  #     end
  #
  #     def before_save(record)
  #       record.credit_card_number = encrypt(record.credit_card_number)
  #     end
  #
  #     def after_save(record)
  #       record.credit_card_number = decrypt(record.credit_card_number)
  #     end
  #
  #     alias_method :after_find, :after_save
  #
  #     private
  #       def encrypt(value)
  #         # Secrecy is committed
  #       end
  #
  #       def decrypt(value)
  #         # Secrecy is unveiled
  #       end
  #   end
  #
  # So you specify the object you want messaged on a given callback. When that callback is triggered, the object has
  # a method by the name of the callback messaged.
  #
  # The callback macros usually accept a symbol for the method they're supposed to run, but you can also pass a "method string",
  # which will then be evaluated within the binding of the callback. Example:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy 'self.class.delete_all "parent_id = #{id}"'
  #   end
  #
  # Notice that single plings (') are used so the #{id} part isn't evaluated until the callback is triggered. Also note that these
  # inline callbacks can be stacked just like the regular ones:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy 'self.class.delete_all "parent_id = #{id}"',
  #                    'puts "Evaluated after parents are destroyed"'
  #   end
  #
  # == The after_find and after_initialize exceptions
  #
  # Because after_find and after_initialize are called for each object found and instantiated by a finder, such as Base.find(:all), we've had
  # to implement a simple performance constraint (50% more speed on a simple test case). Unlike all the other callbacks, after_find and
  # after_initialize will only be run if an explicit implementation is defined (<tt>def after_find</tt>). In that case, all of the
  # callback types will be called.
  #
  # == before_validation* returning statements
  #
  # If the returning value of a before_validation callback can be evaluated to false, the process will be aborted and Base#save will return false.
  # If Base#save! is called it will raise a RecordNotSave error.
  # Nothing will be appended to the errors object.
  #
  # == Cancelling callbacks
  #
  # If a before_* callback returns false, all the later callbacks and the associated action are cancelled. If an after_* callback returns
  # false, all the later callbacks are cancelled. Callbacks are generally run in the order they are defined, with the exception of callbacks
  # defined as methods on the model, which are called last.
  module Callbacks
    CALLBACKS = %w(
      after_find after_initialize before_save after_save before_create after_create before_update after_update before_validation
      after_validation before_validation_on_create after_validation_on_create before_validation_on_update
      after_validation_on_update before_destroy after_destroy
    )

    def self.included(base) #:nodoc:
      base.extend(ClassMethods)
      base.class_eval do
        class << self
          include Observable
          alias_method_chain :instantiate, :callbacks
        end

        [:initialize, :create_or_update, :valid?, :create, :update, :destroy].each do |method|
          alias_method_chain method, :callbacks
        end
      end

      CALLBACKS.each do |method|
        base.class_eval <<-"end_eval"
          def self.#{method}(*callbacks, &block)
            callbacks << block if block_given?
            write_inheritable_array(#{method.to_sym.inspect}, callbacks)
          end
        end_eval
      end
    end

    module ClassMethods #:nodoc:
      def instantiate_with_callbacks(record)
        object = instantiate_without_callbacks(record)

        if object.respond_to_without_attributes?(:after_find)
          object.send(:callback, :after_find)
        end

        if object.respond_to_without_attributes?(:after_initialize)
          object.send(:callback, :after_initialize)
        end

        object
      end
    end

    # Is called when the object was instantiated by one of the finders, like Base.find.
    #def after_find() end

    # Is called after the object has been instantiated by a call to Base.new.
    #def after_initialize() end

    def initialize_with_callbacks(attributes = nil) #:nodoc:
      initialize_without_callbacks(attributes)
      result = yield self if block_given?
      callback(:after_initialize) if respond_to_without_attributes?(:after_initialize)
      result
    end

    # Is called _before_ Base.save (regardless of whether it's a create or update save).
    def before_save() end

    # Is called _after_ Base.save (regardless of whether it's a create or update save).
    #
    #  class Contact < ActiveRecord::Base
    #    after_save { logger.info( 'New contact saved!' ) }
    #  end
    def after_save()  end
    def create_or_update_with_callbacks #:nodoc:
      return false if callback(:before_save) == false
      result = create_or_update_without_callbacks
      callback(:after_save)
      result
    end

    # Is called _before_ Base.save on new objects that haven't been saved yet (no record exists).
    def before_create() end

    # Is called _after_ Base.save on new objects that haven't been saved yet (no record exists).
    def after_create() end
    def create_with_callbacks #:nodoc:
      return false if callback(:before_create) == false
      result = create_without_callbacks
      callback(:after_create)
      result
    end

    # Is called _before_ Base.save on existing objects that have a record.
    def before_update() end

    # Is called _after_ Base.save on existing objects that have a record.
    def after_update() end

    def update_with_callbacks #:nodoc:
      return false if callback(:before_update) == false
      result = update_without_callbacks
      callback(:after_update)
      result
    end

    # Is called _before_ Validations.validate (which is part of the Base.save call).
    def before_validation() end

    # Is called _after_ Validations.validate (which is part of the Base.save call).
    def after_validation() end

    # Is called _before_ Validations.validate (which is part of the Base.save call) on new objects
    # that haven't been saved yet (no record exists).
    def before_validation_on_create() end

    # Is called _after_ Validations.validate (which is part of the Base.save call) on new objects
    # that haven't been saved yet (no record exists).
    def after_validation_on_create()  end

    # Is called _before_ Validations.validate (which is part of the Base.save call) on
    # existing objects that have a record.
    def before_validation_on_update() end

    # Is called _after_ Validations.validate (which is part of the Base.save call) on
    # existing objects that have a record.
    def after_validation_on_update()  end

    def valid_with_callbacks? #:nodoc:
      return false if callback(:before_validation) == false
      if new_record? then result = callback(:before_validation_on_create) else result = callback(:before_validation_on_update) end
      return false if result == false

      result = valid_without_callbacks?

      callback(:after_validation)
      if new_record? then callback(:after_validation_on_create) else callback(:after_validation_on_update) end

      return result
    end

    # Is called _before_ Base.destroy.
    #
    # Note: If you need to _destroy_ or _nullify_ associated records first,
    # use the _:dependent_ option on your associations.
    def before_destroy() end

    # Is called _after_ Base.destroy (and all the attributes have been frozen).
    #
    #  class Contact < ActiveRecord::Base
    #    after_destroy { |record| logger.info( "Contact #{record.id} was destroyed." ) }
    #  end
    def after_destroy()  end
    def destroy_with_callbacks #:nodoc:
      return false if callback(:before_destroy) == false
      result = destroy_without_callbacks
      callback(:after_destroy)
      result
    end

    private
      def callback(method)
        notify(method)

        callbacks_for(method).each do |callback|
          result = case callback
            when Symbol
              self.send(callback)
            when String
              eval(callback, binding)
            when Proc, Method
              callback.call(self)
            else
              if callback.respond_to?(method)
                callback.send(method, self)
              else
                raise ActiveRecordError, "Callbacks must be a symbol denoting the method to call, a string to be evaluated, a block to be invoked, or an object responding to the callback method."
              end
          end
          return false if result == false
        end

        result = send(method) if respond_to_without_attributes?(method)

        return result
      end

      def callbacks_for(method)
        self.class.read_inheritable_attribute(method.to_sym) or []
      end

      def invoke_and_notify(method)
        notify(method)
        send(method) if respond_to_without_attributes?(method)
      end

      def notify(method) #:nodoc:
        self.class.changed
        self.class.notify_observers(method, self)
      end
  end
end
