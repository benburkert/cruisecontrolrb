module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module Grouping
        # Iterate over an array in groups of a certain size, padding any remaining 
        # slots with specified value (<tt>nil</tt> by default) unless it is
        # <tt>false</tt>.
        # 
        # E.g.
        # 
        #   %w(1 2 3 4 5 6 7).in_groups_of(3) {|g| p g}
        #   ["1", "2", "3"]
        #   ["4", "5", "6"]
        #   ["7", nil, nil]
        #
        #   %w(1 2 3).in_groups_of(2, '&nbsp;') {|g| p g}
        #   ["1", "2"]
        #   ["3", "&nbsp;"]
        #
        #   %w(1 2 3).in_groups_of(2, false) {|g| p g}
        #   ["1", "2"]
        #   ["3"]
        def in_groups_of(number, fill_with = nil, &block)
          require 'enumerator'
          collection = dup
          collection << fill_with until collection.size.modulo(number).zero? unless fill_with == false
          grouped_collection = [] unless block_given?
          collection.each_slice(number) do |group|
            block_given? ? yield(group) : grouped_collection << group
          end
          grouped_collection unless block_given?
        end

        # Divide the array into one or more subarrays based on a delimiting +value+
        # or the result of an optional block.
        #
        # ex.
        #
        #   [1, 2, 3, 4, 5].split(3)                # => [[1, 2], [4, 5]]
        #   (1..10).to_a.split { |i| i % 3 == 0 }   # => [[1, 2], [4, 5], [7, 8], [10]]
        def split(value = nil, &block)
          block ||= Proc.new { |e| e == value }
          inject([[]]) do |results, element|
            if block.call(element)
              results << []
            else
              results.last << element
            end
            results
          end
        end
      end
    end
  end
end
