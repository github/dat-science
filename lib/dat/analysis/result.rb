require "time"

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

  module Analysis::Result::DefaultMethods
    # Public: Get the result data for the 'control' code path.
    #
    # Returns the 'control' field of the result hash.
    def control
      self['control']
    end

    # Public: Get the result data for the 'candidate' code path.
    #
    # Returns the 'candidate' field of the result hash.
    def candidate
      self['candidate']
    end

    # Public: Get the timestamp when the result was recorded.
    #
    # Returns a Time object for the timestamp for this result.
    def timestamp
      @timestamp ||= Time.parse(self['timestamp'])
    end

    # Public: Get which code path was run first.
    #
    # Returns the 'first' field of the result hash.
    def first
      self['first']
    end

    # Public: Get the experiment name
    #
    # Returns the 'experiment' field of the result hash.
    def experiment_name
      self['experiment']
    end
  end
end
