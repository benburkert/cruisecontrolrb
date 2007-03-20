module ActiveRecord
  # Active Record automatically timestamps create and update if the table has fields
  # created_at/created_on or updated_at/updated_on.
  #
  # Timestamping can be turned off by setting
  #   <tt>ActiveRecord::Base.record_timestamps = false</tt>
  #
  # Keep in mind that, via inheritance, you can turn off timestamps on a per
  # model basis by setting <tt>record_timestamps</tt> to false in the desired
  # models.
  #
  #   class Feed < ActiveRecord::Base
  #     self.record_timestamps = false
  #     # ...
  #   end
  #
  # Timestamps are in the local timezone by default but can use UTC by setting
  #   <tt>ActiveRecord::Base.default_timezone = :utc</tt>
  module Timestamp
    def self.included(base) #:nodoc:
      super

      base.alias_method_chain :create, :timestamps
      base.alias_method_chain :update, :timestamps

      base.cattr_accessor :record_timestamps, :instance_writer => false
      base.record_timestamps = true
    end

    def create_with_timestamps #:nodoc:
      if record_timestamps
        t = self.class.default_timezone == :utc ? Time.now.utc : Time.now
        write_attribute('created_at', t) if respond_to?(:created_at) && created_at.nil?
        write_attribute('created_on', t) if respond_to?(:created_on) && created_on.nil?

        write_attribute('updated_at', t) if respond_to?(:updated_at)
        write_attribute('updated_on', t) if respond_to?(:updated_on)
      end
      create_without_timestamps
    end

    def update_with_timestamps #:nodoc:
      if record_timestamps
        t = self.class.default_timezone == :utc ? Time.now.utc : Time.now
        write_attribute('updated_at', t) if respond_to?(:updated_at)
        write_attribute('updated_on', t) if respond_to?(:updated_on)
      end
      update_without_timestamps
    end
  end
end
