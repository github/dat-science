module Dat

  # Internal. The value of a watched behavior.
  module Science
    class Result
      attr_reader :duration
      attr_reader :exception
      attr_reader :value

      def initialize(value, duration, exception)
        @duration  = duration
        @exception = exception
        @value     = value
      end

      def ==(other)
        return false unless other.is_a? Science::Result

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
    end
  end
end
