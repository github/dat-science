require "dat/science/result"

module Dat
  module Science

    # Public: Try things in code.
    class Experiment

      # Public: The name of this experiment.
      attr_reader :name

      # Public: Create a new experiment instance. `self` is yielded to an
      # optional `block` if it's provided.
      def initialize(name, &block)
        @candidate  = nil
        @cleaner    = lambda { |r| r }
        @context    = { :experiment => name }
        @control    = nil
        @name       = name

        yield self if block_given?
      end

      # Public: Declare the candidate behavior `block` for this experiment.
      # Returns `block`.
      def candidate(&block)
        @candidate = block if block
        @candidate
      end

      # Public: Declare a cleaner `block` to scrub the result before it's
      # published. `block` is called twice, once with the result of
      # the control behavior and once with the result of the candidate.
      # Exceptions during cleaning are treated as if they were raised
      # in a candidate or control behavior block: They're reported as part
      # of the result.
      #
      # Returns `block`.
      def cleaner(&block)
        @cleaner = block if block
        @cleaner
      end

      # Public: Add a Hash of `payload` data to be included when events are
      # published or returns the current context if `payload` is `nil`.
      def context(payload = nil)
        @context.merge! payload if payload
        @context
      end

      # Public: Declare the control behavior `block` for this experiment.
      # Returns `block`.
      def control(&block)
        @control = block if block
        @control
      end

      # Public: Run the control and candidate behaviors, timing each and
      # comparing the results. The run order is randomized. Returns the control
      # behavior's result.
      #
      # If the experiment is disabled or candidate behavior isn't provided the
      # control behavior's result will be returned immediately.
      def run
        return run_control unless candidate? && enabled?

        timestamp = Time.now

        if control_runs_first?
          control   = observe_control
          candidate = observe_candidate
        else
          candidate = observe_candidate
          control   = observe_control
        end

        payload = {
          :timestamp => timestamp,
          :candidate => candidate.payload,
          :control   => control.payload,
          :first     => control_runs_first? ? :control : :candidate
        }

        kind = control == candidate ? :match : :mismatch
        publish_with_context kind, payload

        raise control.exception if control.raised?

        control.value
      end

      protected

      # Internal: Does this experiment have candidate behavior?
      def candidate?
        !!candidate
      end

      # Internal: Should the control behavior run first?
      def control_runs_first?
        return @control_runs_first if defined? @control_runs_first
        @control_runs_first = rand(2) == 0
      end

      # Internal: Is this experiment enabled? More specifically, should
      # the candidate behavior be run and compared to the control
      # behavior? The default implementation returns `true`.
      def enabled?
        true
      end

      # Internal: Run `block`, measuring the duration and rescuing any
      # raised exceptions. Returns a Dat::Science::Result.
      def observe(&block)
        start = Time.now

        begin
          value = run_cleaner block.call
        rescue => ex
          raised = ex
        end

        duration = (Time.now - start) * 1000
        Science::Result.new value, duration, raised
      end


      # Internal. Returns a Dat::Science::Result for `candidate`.
      def observe_candidate
        observe { run_candidate }
      end

      # Internal. Returns a Dat::Science::Result for `control`.
      def observe_control
        observe { run_control }
      end

      # Internal: Broadcast an `event` String and `payload` Hash. The
      # default implementation is a no-op. Returns nothing.
      def publish(event, payload)
      end

      # Internal: Call `publish`, merging the `payload` with `context`.
      def publish_with_context(event, payload)
        publish event, context.merge(payload)
      end

      # Internal: Run the candidate behavior and return its result.
      def run_candidate
        candidate.call
      end

      # Internal: Run the cleaner behavior and return its result.
      def run_cleaner(value)
        cleaner.call value
      end

      # Internal: Run the control behavior and return its result.
      def run_control
        control.call
      end
    end
  end
end
