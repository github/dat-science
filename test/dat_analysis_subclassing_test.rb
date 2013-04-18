require "minitest/autorun"
require "mocha/setup"
require "dat/analysis"

# helper class to provide mismatch results
class TestMismatchAnalysis < Dat::Analysis
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

context "Dat::Analysis when subclassed" do
  setup do
    @experiment_name = 'test-suite-experiment'
    @analyzer = TestCookedAnalyzer.new @experiment_name
  end

  context "when count is overridden" do
    test "is 0 when there are no mismatches" do
      assert_equal 0, @analyzer.count
    end

    test "returns the count of mismatches" do
      @analyzer.mismatches.push 'mismatch'
      @analyzer.mismatches.push 'mismatch'
      assert_equal 2, @analyzer.count
    end
  end

  context "fetch, when read is overridden" do
    test "returns nil when there are no mismatches returned from read" do
      assert_nil @analyzer.fetch
    end

    test "returns the cooked version of the next mismatch returned from read" do
      @analyzer.mismatches.push 'mismatch'
      assert_equal 'cooked-mismatch', @analyzer.fetch
    end
  end

  context "when cook is overridden" do
    test "raw returns nil when no mismatches have been fetched" do
      assert_nil @analyzer.raw
    end

    test "current returns nil result when no mismatches have been fetched" do
      assert_nil @analyzer.current
    end

    test "raw returns nil when last fetched returned no results" do
      @analyzer.fetch
      assert_nil @analyzer.raw
    end

    test "current returns nil result when last fetched returned no results" do
      @analyzer.fetch
      assert_nil @analyzer.current
    end

    test "raw returns an unprocessed version of the most recent mismatch" do
      @analyzer.mismatches.push 'mismatch-1'
      result = @analyzer.fetch
      assert_equal 'mismatch-1', @analyzer.raw
    end

    test "current returns a cooked version of the most recent mismatch" do
      @analyzer.mismatches.push 'mismatch-1'
      result = @analyzer.fetch
      assert_equal 'cooked-mismatch-1', @analyzer.current
    end

    test "raw updates with later fetches" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.mismatches.push 'mismatch-2'
      @analyzer.fetch # discard the first one
      @analyzer.fetch
      assert_equal 'mismatch-1', @analyzer.raw
    end

    test "current updates with later fetches" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.mismatches.push 'mismatch-2'
      @analyzer.fetch # discard the first one
      @analyzer.fetch
      assert_equal 'cooked-mismatch-1', @analyzer.current
    end
  end
end
