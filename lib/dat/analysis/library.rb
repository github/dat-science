module Dat
  # Internal: Keep a registry of Dat::Analysis::Matcher and
  # Dat::Analysis::Result subclasses for use by an Dat::Analysis::Analysis
  # instance.
  class Analysis::Library

    @@known_classes = []

    # Public: Collect matcher and results classes created by the
    #         provided block.
    #
    # &block - Block which instantiates matcher and results classes.
    #
    # Returns the newly-instantiated matcher and results classes.
    def self.select_classes(&block)
      @@known_classes = [] # prepare for registering new classes
      yield
      @@known_classes # return all the newly-registered classes
    end

    # Public: register a matcher or results class.
    #
    # klass - a Dat::Analysis::Matcher or Dat::Analysis::Result subclass.
    #
    # Returns the current list of registered classes.
    def self.add(klass)
      @@known_classes << klass
    end
  end
end
