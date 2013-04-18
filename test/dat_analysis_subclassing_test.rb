require "minitest/autorun"
require "mocha/setup"
require "dat/analysis"

# helper class to provide mismatch results
class TestCookedAnalyzer < Dat::Analysis
  attr_accessor :mismatches

  def initialize(experiment_name)
    super
    @mismatches = []  # use a simple array for a mismatch store
  end

  # load data files from our fixtures path
  def path
    File.expand_path('fixtures/', __FILE__)
  end

  def cook(raw_result)
    return "cooked" unless raw_result
    "cooked-#{raw_result}"
  end

  def count
    mismatches.size
  end

  def read
    mismatches.pop
  end

  # neuter formatter to take simple non-structured results
  def readable
    current.inspect
  end

  # neuter calls to `puts`, make it possible to test them.
  def puts(*args)
    @last_printed = args.join('')
    nil
  end
  attr_reader :last_printed # for tests: last call to puts

  # neuter calls to 'print' to eliminate test output clutter
  def print(*args) end
end

class DatAnalysisSubclassingTest < MiniTest::Unit::TestCase

  def setup
    @experiment_name = 'test-suite-experiment'
    @analyzer = ::TestCookedAnalyzer.new @experiment_name
  end

  def test_is_0_when_count_is_overridden_and_there_are_no_mismatches
    assert_equal 0, @analyzer.count
  end

  def test_returns_the_count_of_mismatches_when_count_is_overridden
    @analyzer.mismatches.push 'mismatch'
    @analyzer.mismatches.push 'mismatch'
    assert_equal 2, @analyzer.count
  end

  def test_fetch_returns_nil_when_read_is_overridden_and_read_returns_no_mismatches
    assert_nil @analyzer.fetch
  end

  def test_fetch_returns_the_cooked_version_of_the_next_mismatch_from_read_when_read_is_overridden
    @analyzer.mismatches.push 'mismatch'
    assert_equal 'cooked-mismatch', @analyzer.fetch
  end

  def test_raw_returns_nil_when_no_mismatches_have_been_fetched_and_cook_is_overridden
    assert_nil @analyzer.raw
  end

  def test_current_returns_nil_when_no_mismatches_have_been_fetch_and_cook_is_overridden
    assert_nil @analyzer.current
  end

  def test_raw_returns_nil_when_last_fetched_returns_no_results_and_cook_is_overridden
    @analyzer.fetch
    assert_nil @analyzer.raw
  end

  def test_current_returns_nil_when_last_fetched_returns_no_results_and_cook_is_overridden
    @analyzer.fetch
    assert_nil @analyzer.current
  end

  def test_raw_returns_unprocess_mismatch_when_cook_is_overridden
    @analyzer.mismatches.push 'mismatch-1'
    result = @analyzer.fetch
    assert_equal 'mismatch-1', @analyzer.raw
  end

  def test_current_returns_a_cooked_mismatch_when_cook_is_overridden
    @analyzer.mismatches.push 'mismatch-1'
    result = @analyzer.fetch
    assert_equal 'cooked-mismatch-1', @analyzer.current
  end

  def test_raw_updates_with_later_fetches_when_cook_is_overridden
    @analyzer.mismatches.push 'mismatch-1'
    @analyzer.mismatches.push 'mismatch-2'
    @analyzer.fetch # discard the first one
    @analyzer.fetch
    assert_equal 'mismatch-1', @analyzer.raw
  end

  def test_current_updates_with_later_fetches_when_cook_is_overridden
    @analyzer.mismatches.push 'mismatch-1'
    @analyzer.mismatches.push 'mismatch-2'
    @analyzer.fetch # discard the first one
    @analyzer.fetch
    assert_equal 'cooked-mismatch-1', @analyzer.current
  end
end
