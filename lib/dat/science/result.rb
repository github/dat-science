module Dat
  module Science

    # Internal. The output of running of an observed behavior.
    class Result
      attr_reader :duration
      attr_reader :exception
      attr_reader :experiment
      attr_reader :value

      def initialize(experiment, value, duration, exception)
        @duration   = duration
        @exception  = exception
        @experiment = experiment
        @value      = value
      end

      def ==(other)
        return false unless other.is_a? Dat::Science::Result

        values_are_equal = experiment.compare(other.value, value)
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
        {
          :duration  => duration,
          :exception => serialized_exception,
          :value     => experiment.clean(value)
        }
      end

      def serialized_exception
        return nil unless exception
        { :class => exception.class.name, :message => exception.message }
      end

      def raised?
        !!exception
      end
    end
  end
end
