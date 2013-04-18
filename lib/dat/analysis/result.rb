module Dat
  # Public: Base class for wrappers around science mismatch results.
  #
  # Instance methods defined on subclasses will be added as instance methods
  # on science mismatch results handled by Dat::Analysis instances which
  # add the wrapper subclass via Dat::Analysis#add or Dat::Analysis#load_classes.
  class Analysis::Result

    # Public: return the current science mismatch result
    attr_reader :result

    # Internal: Called at subclass instantiation time to register the subclass
    #           with Dat::Analysis::Library.
    #
    # subclass - The Dat::Analysis::Result subclass being instantiated.
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
    # Returns the analyzer's updated list of known result wrapper classes.
    def self.add_to_analyzer(analyzer)
      analyzer.add_wrapper self
    end

    # Public: create a new Result wrapper.
    #
    # result - a science mismatch result, to be wrapped with our instance methods.
    def initialize(result)
      @result = result
    end
  end
end
