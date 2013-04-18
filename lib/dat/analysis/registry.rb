module Dat
  # Internal: Registry of Dat::Analysis::Matcher and Dat::Analysis::Result
  #           classes.  This is used to maintain the mapping of matchers and
  #           results wrappers for a particular Dat::Analysis instance.
  class Analysis::Registry

    # Public: Create a new Registry instance.
    def initialize
      @known_classes = []
    end

    # Public: Add a matcher or results wrapper class to the registry
    #
    # klass - a Dat::Analysis::Matcher subclass or a Dat::Analysis::Result
    #         subclass, to be added to the registry.
    #
    # Returns the list of currently registered classes.
    def add(klass)
      @known_classes << klass
    end

    # Public: Get the list of known Dat::Analysis::Matcher subclasses
    #
    # Returns the list of currently known matcher classes.
    def matchers
      @known_classes.select {|c| c <= ::Dat::Analysis::Matcher }
    end

    # Public: Get the list of known Dat::Analysis::Result subclasses
    #
    # Returns the list of currently known result wrapper classes.
    def wrappers
      @known_classes.select {|c| c <= ::Dat::Analysis::Result }
    end

    # Public: Get list of Dat::Analysis::Matcher subclasses for which
    #         `#match?` is truthy for the given result.
    #
    # result - a cooked science mismatch result
    #
    # Returns a list of matchers initialized with the provided result.
    def identify(result)
      matchers.inject([]) do |hits, matcher|
        instance = matcher.new(result)
        hits << instance if instance.match?
        hits
      end
    end
  end
end
