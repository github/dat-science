require "minitest/autorun"
require "dat/science/experiment"

class DatScienceExperimentTest < MiniTest::Unit::TestCase
  def test_sanity
    assert Dat::Science::Experiment
  end
end
