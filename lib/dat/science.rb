require "dat/science/experiment"

module Dat

  # Public: Include this module if you like science.
  module Science

    # Public: Do some science.
    def science(name, &block)
      Science.experiment.new(name, &block).run
    end

    # Public: The Class to use for all `science` experiments. Default is
    # `Dat::Science::Experiment`.
    def self.experiment
      @experiment ||= Dat::Science::Experiment
    end

    # Public: Set the Class to use for all `science` experiments.
    # Returns `klass`.
    def self.experiment=(klass)
      @experiment = klass
    end

    # Internal: Reset any static configuration (primarily
    # `Dat::Science.experiment`. Returns `self`.
    def self.reset
      @experiment = nil

      self
    end
  end
end
