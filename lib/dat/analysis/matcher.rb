module Dat
  # Public: Base class for science mismatch results matchers.  Subclasses
  #         implement the `#match?` instance method, which returns true when
  #         a provided science mismatch result is recognized by the matcher.
  #
  # Subclasses are expected to define `#match?`.
  #
  # Subclasses may optionally define `#readable` to return an alternative
  # readable String representation of a cooked science mismatch result.  The
  # default implementation is defined in Dat::Analysis#readable.
  class Analysis::Matcher

    # Public: The science mismatch result to be matched.
    attr_reader :result

    # Internal: Called at subclass instantiation time to register the subclass
    #           with Dat::Analysis::Library.
    #
    # subclass - The Dat::Analysis::Matcher subclass being instantiated.
    #
    # Not intended to be called directly.
    def self.inherited(subclass)
      Dat::Analysis::Library.add subclass
    end

    # Internal: Add this class to a Dat::Analysis instance.  Intended to be
    #           called from Dat::Analysis to dispatch registration.
    #
    # analyzer - a Dat::Analysis instance for an experiment
    #
    # Returns the analyzer's updated list of known matcher classes.
    def self.add_to_analyzer(analyzer)
      analyzer.add_matcher self
    end

    # Public: create a new Matcher.
    #
    # result - a science mismatch result, to be tested via `#match?`
    def initialize(result)
      @result = result
    end
  end
end
