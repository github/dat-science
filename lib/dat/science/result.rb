module Dat
  module Science

    # Internal. The output of running of an observed behavior.
    class Result
      attr_reader :duration
      attr_reader :exception
      attr_reader :transform
      attr_reader :original_value

      def initialize(value, duration, exception, transform = nil)
        @duration       = duration
        @exception      = exception
        @original_value = value
        @transform      = transform
      end

      def ==(other)
        return false unless other.is_a? Dat::Science::Result

        values_are_equal = other.value == value
        both_raised      = other.raised? && raised?
        neither_raised   = !other.raised? && !raised?

        exceptions_are_equivalent =
          both_raised && other.exception.class == self.exception.class &&
          other.exception.message == self.exception.message

        (values_are_equal && neither_raised) ||
          (both_raised && exceptions_are_equivalent)
      end

      def hash
        exception ^ value
      end

      def payload
        { :duration => duration, :exception => exception, :value => value }
      end

      def raised?
        !!exception
      end

      def value
        @transformed_value = transformed unless defined?(@transformed_value)
        @transformed_value
      end

      def transformed
        return @original_value unless transform

        begin
          return transform.call @original_value
        rescue
          @original_value
        end
      end
    end
  end
end
