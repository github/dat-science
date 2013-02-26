require "minitest/autorun"
require "mocha/setup"
require "dat/science"

class DatScienceTest < MiniTest::Unit::TestCase
  def teardown
    Dat::Science.reset
  end

  def test_experiment_default
    assert_equal Dat::Science::Experiment, Dat::Science.experiment
  end

  def test_experiment
    Dat::Science.experiment = :foo
    assert_equal :foo, Dat::Science.experiment
  end

  def test_science
    experiment = mock do
      expects(:run).returns 42
    end

    Dat::Science.experiment.expects(:new).with("foo").returns experiment

    obj = Object.new
    obj.extend Dat::Science

    ret = obj.science "foo"
    assert_equal 42, ret
  end
end
