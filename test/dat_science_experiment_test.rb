require "minitest/autorun"
require "dat/science/experiment"

class DatScienceExperimentTest < MiniTest::Unit::TestCase
  class Experiment < Dat::Science::Experiment
    def self.published
      @published ||= []
    end

    def publish(name, payload)
      Experiment.published << [name, payload]
    end
  end

  def setup
    Experiment.published.clear
  end

  def test_initialize
    in_block   = nil
    experiment = Experiment.new("foo") { |e| in_block = e }

    assert_equal "foo", experiment.name
    assert_equal experiment, in_block
  end

  def test_candidate_default
    assert_nil Experiment.new("foo").candidate
  end

  def test_candidate
    e = Experiment.new "foo"
    b = lambda {}

    e.candidate &b
    assert_same b, e.candidate
  end

  def test_cleaner
    e = Experiment.new "foo"
    e.control   { "bar" }
    e.candidate { "baz" }
    e.cleaner   { |value| value.upcase }

    e.run

    event, payload = Experiment.published.first

    assert_equal "BAR", payload[:control][:value]
    assert_equal "BAZ", payload[:candidate][:value]
  end

  def test_context_default
    e = Experiment.new "foo"

    expected = { :experiment => "foo" }
    assert_equal expected, e.context
  end

  def test_context
    e = Experiment.new "foo"
    e.context :bar => :baz

    assert_equal :baz, e.context[:bar]
  end

  def test_control_default
    assert_nil Experiment.new("foo").control
  end

  def test_control
    e = Experiment.new "foo"
    b = lambda {}

    e.control &b
    assert_same b, e.control
  end

  def test_run_with_no_candidate
    e = Experiment.new "foo"
    e.control { :foo }

    assert_equal :foo, e.run
    assert Experiment.published.empty?
  end

  def test_run_disabled
    e = Experiment.new "foo"
    e.control { :foo }
    e.candidate { :bar }

    def e.enabled?
      false
    end

    assert_equal :foo, e.run
    assert Experiment.published.empty?
  end

  def test_run
    e = Experiment.new "foo"
    e.control { :foo }

    candidate_run = false
    e.candidate { candidate_run = true; :bar }

    def e.control_runs_first?
      true
    end

    assert_equal :foo, e.run
    assert candidate_run

    event, payload = Experiment.published.first
    refute_nil event
    refute_nil payload

    assert_equal :mismatch, event

    assert_equal "foo", payload[:experiment]
    assert_equal :control, payload[:first]

    assert_in_delta Time.now.to_f, payload[:timestamp].to_f, 2.0

    assert payload[:control][:duration]
    assert_nil payload[:control][:exception]
    assert_equal :foo, payload[:control][:value]

    assert payload[:candidate][:duration]
    assert_nil payload[:candidate][:exception]
    assert_equal :bar, payload[:candidate][:value]
  end

  def test_run_candidate_first
    e = Experiment.new "foo"
    e.control { :foo }
    e.candidate { :bar }

    def e.control_runs_first?
      false
    end

    assert_equal :foo, e.run

    event, payload = Experiment.published.first
    refute_nil event
    refute_nil payload

    assert_equal :mismatch, event
    assert_equal :candidate, payload[:first]
  end

  def test_run_match
    e = Experiment.new "foo"
    e.control { :foo }
    e.candidate { :foo }

    assert_equal :foo, e.run

    event, payload = Experiment.published.first
    refute_nil event
    refute_nil payload

    assert_equal :match, event
  end

  def test_run_passes_control_exceptions_through
    e = Experiment.new "foo"
    e.control { raise "bar" }

    candidate_run = false
    e.candidate { candidate_run = true }

    ex = assert_raises RuntimeError do
      e.run
    end

    assert candidate_run
    assert_equal "bar", ex.message

    event, payload = Experiment.published.first
    refute_nil event
    refute_nil payload

    assert_equal :mismatch, event
    refute_nil payload[:control][:exception]
  end

  def test_run_swallows_candidate_exceptions
    e = Experiment.new "foo"
    e.control { :foo }
    e.candidate { raise "bar" }

    assert_equal :foo, e.run

    event, payload = Experiment.published.first
    refute_nil event
    refute_nil payload

    assert_equal :mismatch, event
    refute_nil payload[:candidate][:exception]
  end

  def test_run_similar_exceptions_are_a_match
    e = Experiment.new "foo"
    e.control { raise "foo" }
    e.candidate { raise "foo" }

    assert_raises RuntimeError do
      e.run
    end

    event, payload = Experiment.published.first
    refute_nil event
    refute_nil payload

    assert_equal :match, event
    refute_nil payload[:control][:exception]
    refute_nil payload[:candidate][:exception]
  end

  def test_run_dissimilar_exceptions_are_a_mismatch
    e = Experiment.new "foo"
    e.control { raise "foo" }
    e.candidate { raise "bar" }

    assert_raises RuntimeError do
      e.run
    end

    event, payload = Experiment.published.first
    refute_nil event
    refute_nil payload

    assert_equal :mismatch, event
    refute_nil payload[:control][:exception]
    refute_nil payload[:candidate][:exception]
  end
end
