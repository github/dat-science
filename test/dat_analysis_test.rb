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

# for testing that a non-registered Recognizer class can still
# supply a default `#readable` method to subclasses
class TestSubclassRecognizer < Dat::Analysis::Matcher
  def readable
    "experiment-formatter: #{result}"
  end
end

context Dat::Analysis do
  setup do
    Dat::Analysis::Tally.any_instance.stubs(:puts)
    @experiment_name = 'test-suite-experiment'
    @analyzer = TestMismatchAnalysis.new @experiment_name
  end

  test "preserves the experiment name" do
    assert_equal @experiment_name, @analyzer.experiment_name
  end

  context "analyze" do
    test "returns nil if there is no current result and no additional results" do
      assert_nil @analyzer.analyze
    end

    test "leaves tallies empty if there is no current result and no additional results" do
      @analyzer.analyze
      assert_equal({}, @analyzer.tally.tally)
    end

    test "returns nil if there is a current result but no additional results" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert @analyzer.current
      assert_nil @analyzer.analyze
    end

    test "leaves tallies empty if there is a current result but no additional results" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert @analyzer.current
      @analyzer.analyze
      assert_equal({}, @analyzer.tally.tally)
    end

    test "outputs default result summary and tally summary when one unrecognized result is present" do
      @analyzer.expects(:summarize_unknown_result)
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.analyze
    end

    test "returns nil when one unrecognized result is present" do
      @analyzer.mismatches.push 'mismatch-1'
      assert_nil @analyzer.analyze
    end

    test "leaves current result set to first result when one unrecognized result is present" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.analyze
      assert_equal 'mismatch-1', @analyzer.current
    end

    test "leaves tallies empty when one unrecognized result is present" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.analyze
      assert_equal({}, @analyzer.tally.tally)
    end

    test "outputs default results summary for first unrecognized result, and tally summary when recognized and unrecognized results are present" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          result =~ /^known-/
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'known-1'
      @analyzer.mismatches.push 'unknown-1'
      @analyzer.mismatches.push 'known-2'

      @analyzer.expects(:summarize_unknown_result)
      @analyzer.analyze
    end

    test "returns number of un-analyzed results when recognized and unrecognized results are present" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          result =~ /^known-/
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'known-1'
      @analyzer.mismatches.push 'unknown-1'
      @analyzer.mismatches.push 'known-2'

      assert_equal 1, @analyzer.analyze
    end

    test "leaves current result set to first unrecognized result when recognized and unrecognized results are present" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          result =~ /^known/
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'known-1'
      @analyzer.mismatches.push 'unknown-1'
      @analyzer.mismatches.push 'known-2'

      @analyzer.analyze
      assert_equal 'unknown-1', @analyzer.current
    end

    test "leaves recognized result counts in tally when recognized and unrecognized results are present" do
      matcher1 = Class.new(Dat::Analysis::Matcher) do
        def self.name() "RecognizerOne" end
        def match?
          result =~ /^known-1/
        end
      end

      matcher2 = Class.new(Dat::Analysis::Matcher) do
        def self.name() "RecognizerTwo" end
        def match?
          result =~ /^known-2/
        end
      end

      @analyzer.add matcher1
      @analyzer.add matcher2

      @analyzer.mismatches.push 'known-1-last'
      @analyzer.mismatches.push 'unknown-1'
      @analyzer.mismatches.push 'known-10'
      @analyzer.mismatches.push 'known-20'
      @analyzer.mismatches.push 'known-11'
      @analyzer.mismatches.push 'known-21'
      @analyzer.mismatches.push 'known-12'

      @analyzer.analyze

      tally = @analyzer.tally.tally
      assert_equal [ 'RecognizerOne', 'RecognizerTwo' ], tally.keys.sort
      assert_equal 3, tally['RecognizerOne']
      assert_equal 2, tally['RecognizerTwo']
    end

    test "proceeds from stop point when analyzing with more results" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          result =~ /^known-/
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'known-1'
      @analyzer.mismatches.push 'unknown-1'
      @analyzer.mismatches.push 'known-2'
      @analyzer.mismatches.push 'unknown-2'
      @analyzer.mismatches.push 'known-3'

      assert_equal 3, @analyzer.analyze
      assert_equal 'unknown-2', @analyzer.current
      assert_equal 1, @analyzer.analyze
      assert_equal 'unknown-1', @analyzer.current
      assert_equal @analyzer.readable, @analyzer.last_printed
    end

    test "resets tally between runs when analyzing later results after a stop" do
      matcher1 = Class.new(Dat::Analysis::Matcher) do
        def self.name() "RecognizerOne" end
        def match?
          result =~ /^known-1/
        end
      end

      matcher2 = Class.new(Dat::Analysis::Matcher) do
        def self.name() "RecognizerTwo" end
        def match?
          result =~ /^known-2/
        end
      end

      @analyzer.add matcher1
      @analyzer.add matcher2

      @analyzer.mismatches.push 'known-1-last'
      @analyzer.mismatches.push 'unknown-1'
      @analyzer.mismatches.push 'known-10'
      @analyzer.mismatches.push 'known-20'
      @analyzer.mismatches.push 'known-11'
      @analyzer.mismatches.push 'known-21'
      @analyzer.mismatches.push 'known-12'

      @analyzer.analyze  # proceed to first stop point
      @analyzer.analyze  # and continue analysis

      assert_equal({'RecognizerOne' => 1}, @analyzer.tally.tally)
    end
  end

  context "jump_to" do
    test "fails if no block is provided" do
      assert_raises(ArgumentError) do
        @analyzer.jump_to
      end
    end

    test "returns nil if there is no current result" do
      remaining = @analyzer.jump_to do |result|
        true
      end

      assert_nil remaining
    end

    test "leaves current alone if the current result satisfies the block" do
      @analyzer.mismatches.push 'known-1'

      @analyzer.jump_to do |result|
        true
      end
    end

    test "returns 0 if the current result satisfies the block and no other results are available" do
      @analyzer.mismatches.push 'known-1'

      remaining = @analyzer.jump_to do |result|
        true
      end

      assert_equal 0, remaining
    end

    test "returns the number of additional results if the current result satisfies the block and other results are available" do
      @analyzer.mismatches.push 'known-1'
      @analyzer.mismatches.push 'known-2'
      @analyzer.mismatches.push 'known-3'

      remaining = @analyzer.jump_to do |result|
        true
      end

      assert_equal 2, remaining
    end

    test "returns nil if no results are satisfying" do
      @analyzer.mismatches.push 'known-1'
      @analyzer.mismatches.push 'known-2'
      @analyzer.mismatches.push 'known-3'

      remaining = @analyzer.jump_to do |result|
        false
      end

      assert_nil remaining
    end

    test "skips all results if no results are satisfying" do
      @analyzer.mismatches.push 'known-1'
      @analyzer.mismatches.push 'known-2'
      @analyzer.mismatches.push 'known-3'

      remaining = @analyzer.jump_to do |result|
        false
      end

      assert !@analyzer.more?
    end

    test "leaves current as nil if no results are satisfying" do
      @analyzer.mismatches.push 'known-1'
      @analyzer.mismatches.push 'known-2'
      @analyzer.mismatches.push 'known-3'

      remaining = @analyzer.jump_to do |result|
        false
      end

      assert_nil @analyzer.current
    end
  end

  context "more?" do
    test "is false when there are no mismatches" do
      assert !@analyzer.more?
    end

    test "is true when there are mismatches" do
      @analyzer.mismatches.push 'a mismatch'
      assert @analyzer.more?
    end
  end

  context "count" do
    test "fails" do
      assert_raises(NoMethodError) do
        Dat::Analysis.new(@experiment_name).count
      end
    end
  end

  context "fetch" do
    test "fails unless #read is implemented by a subclass" do
      assert_raises(NameError) do
        Dat::Analysis.new(@experiment_name).fetch
      end
    end
  end

  context "current" do
    test "returns nil when no mismmatches have been fetched" do
      assert_nil @analyzer.current
    end

    test "returns nil when last fetch returned no results" do
      @analyzer.fetch
      assert_nil @analyzer.current
    end

    test "returns the most recent mismatch when one has been fetched" do
      @analyzer.mismatches.push 'mismatch'
      @analyzer.fetch
      assert_equal 'mismatch', @analyzer.current
    end

    test "updates with later fetches" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.mismatches.push 'mismatch-2'
      @analyzer.fetch
      result = @analyzer.fetch
      assert_equal result, @analyzer.current
    end

    test "result is an alias for current" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.mismatches.push 'mismatch-2'
      @analyzer.fetch
      result = @analyzer.fetch
      assert_equal result, @analyzer.result
    end
  end

  context "raw" do
    test "returns nil when no mismatches have been fetched" do
      assert_nil @analyzer.raw
    end

    test "returns nil when last fetched returned no results" do
      @analyzer.fetch
      assert_nil @analyzer.raw
    end

    test "returns an unprocessed version of the most recent mismatch" do
      @analyzer.mismatches.push 'mismatch-1'
      result = @analyzer.fetch
      assert_equal 'mismatch-1', @analyzer.raw
    end

    test "updates with later fetches" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.mismatches.push 'mismatch-2'
      @analyzer.fetch # discard the first one
      @analyzer.fetch
      assert_equal 'mismatch-1', @analyzer.raw
    end
  end

  context "loading per-experiment support classes" do
    test "loads no matchers if no matcher files exist on load path" do
      analyzer = TestMismatchAnalysis.new('experiment-with-no-classes')
      analyzer.load_classes
      assert_equal [], analyzer.matchers
      assert_equal [], analyzer.wrappers
    end

    test "loads matchers and wrappers if they exist on load path" do
      analyzer = TestMismatchAnalysis.new('experiment-with-classes')
      analyzer.load_classes
      assert_equal ["MatcherA", "MatcherB", "MatcherC"], analyzer.matchers.map(&:name)
      assert_equal ["WrapperA", "WrapperB", "WrapperC"], analyzer.wrappers.map(&:name)
    end

    test "ignores extraneous classes on load path" do
      analyzer = TestMismatchAnalysis.new('experiment-with-good-and-extraneous-classes')
      analyzer.load_classes
      assert_equal ["MatcherX", "MatcherY", "MatcherZ"], analyzer.matchers.map(&:name)
      assert_equal ["WrapperX", "WrapperY", "WrapperZ"], analyzer.wrappers.map(&:name)
    end

    test "loads classes at initialization time if they are available" do
      analyzer = TestMismatchAnalysis.new('initialize-classes')
      assert_equal ["MatcherM", "MatcherN"], analyzer.matchers.map(&:name)
      assert_equal ["WrapperM", "WrapperN"], analyzer.wrappers.map(&:name)
    end

    test "does not load classes at initialization time if they cannot be loaded" do
      analyzer = TestMismatchAnalysis.new('invalid-matcher')
      assert_equal [], analyzer.matchers
    end

    test "loading classes post-initialization fails if loading has errors" do
      # fails at #load_classes time since we define #path later
      analyzer = Dat::Analysis.new('invalid-matcher')
      analyzer.path = File.expand_path('../../../fixtures/misc/dat', __FILE__)

      assert_raises(Errno::EACCES) do
        analyzer.load_classes
      end
    end
  end

  context "results helper methods" do
    test "are not available on results unless loaded" do
      @analyzer.mismatches.push 'mismatch-1'
      result = @analyzer.fetch

      assert_raises(NoMethodError) do
        result.repository
      end
    end

    test "are made available on returned results" do
      wrapper = Class.new(Dat::Analysis::Result) do
        def repository
          'github/dat-science'
        end
      end

      @analyzer.add wrapper
      @analyzer.mismatches.push 'mismatch-1'
      result = @analyzer.fetch
      assert_equal 'github/dat-science', result.repository
    end

    test "can be loaded from multiple classes" do
      wrapper1 = Class.new(Dat::Analysis::Result) do
        def repository
          'github/dat-science'
        end
      end

      wrapper2 = Class.new(Dat::Analysis::Result) do
        def user
          :rick
        end
      end

      @analyzer.add wrapper1
      @analyzer.add wrapper2
      @analyzer.mismatches.push 'mismatch-1'
      result = @analyzer.fetch
      assert_equal 'github/dat-science', result.repository
      assert_equal :rick, result.user
    end

    test "are made available in the order loaded" do
      wrapper1 = Class.new(Dat::Analysis::Result) do
        def repository
          'github/dat-science'
        end
      end

      wrapper2 = Class.new(Dat::Analysis::Result) do
        def repository
          'github/linguist'
        end

        def user
          :rick
        end
      end

      @analyzer.add wrapper1
      @analyzer.add wrapper2
      @analyzer.mismatches.push 'mismatch-1'
      result = @analyzer.fetch
      assert_equal 'github/dat-science', result.repository
      assert_equal :rick, result.user
    end

    test "do not hide existing result methods" do
      wrapper = Class.new(Dat::Analysis::Result) do
        def size
          'huge'
        end
      end

      @analyzer.add wrapper
      @analyzer.mismatches.push 'mismatch-1'
      result = @analyzer.fetch
      assert_equal 10, result.size
    end

    test "methods can access the result using the `result` method" do
      wrapper = Class.new(Dat::Analysis::Result) do
        def esrever
          result.reverse
        end
      end

      @analyzer.add wrapper
      @analyzer.mismatches.push 'mismatch-1'
      result = @analyzer.fetch
      assert_equal 'mismatch-1'.reverse, result.esrever
    end
  end

  context "summarize" do
    test "returns nil and prints the empty string if no result is current" do
      assert_nil @analyzer.summarize
      assert_equal "", @analyzer.last_printed
    end

    test "returns nil and prints the default readable result if a result is current but no matchers are known" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_nil @analyzer.summarize
      assert_equal @analyzer.readable, @analyzer.last_printed
    end

    test "returns nil and prints the default readable result if a result is current but not matched by any known matchers" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          false
        end

        def readable
          'this should never run'
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_nil @analyzer.summarize
      assert_equal @analyzer.readable, @analyzer.last_printed
    end

    test "returns nil and prints the matcher's readable result when a result is current and matched by a matcher" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          true
        end

        def readable
          "recognized: #{result}"
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_nil @analyzer.summarize
      assert_equal "recognized: mismatch-1", @analyzer.last_printed
    end

    test "returns nil and prints the default readable result when a result is matched by a matcher with no formatter" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          true
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_nil @analyzer.summarize
      assert_equal @analyzer.readable, @analyzer.last_printed
    end

    test "supports use of a matcher base class for shared formatting" do
      matcher = Class.new(TestSubclassRecognizer) do
        def match?
          true
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_nil @analyzer.summarize
      assert_equal "experiment-formatter: mismatch-1", @analyzer.last_printed
    end
  end

  context "summary" do
    test "returns nil if no result is current" do
      assert_nil @analyzer.summary
    end

    test "returns the default readable result if a result is current but no matchers are known" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_equal @analyzer.readable, @analyzer.summary
    end

    test "returns the default readable result if a result is current but not matched by any known matchers" do
        matcher = Class.new(Dat::Analysis::Matcher) do
          def match?
          false
        end

        def readable
          'this should never run'
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_equal @analyzer.readable, @analyzer.summary
    end

    test "returns the matcher's readable result when a result is current and matched by a matcher" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          true
        end

        def readable
          "recognized: #{result}"
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_equal "recognized: mismatch-1", @analyzer.summary
    end

    test "formats with the default formatter if a matching matcher does not define a formatter" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          true
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_equal @analyzer.readable, @analyzer.summary
    end

    test "supports use of a matcher base class for shared formatting" do
      matcher = Class.new(TestSubclassRecognizer) do
        def match?
          true
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_equal "experiment-formatter: mismatch-1", @analyzer.summary
    end
  end

  context "unknown" do
    test "returns nil if no result is current" do
      assert_nil @analyzer.unknown?
    end

    test "returns true if a result is current but no matchers are known" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_equal true, @analyzer.unknown?
    end

    test "returns true if current result is not matched by any known matchers" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          false
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_equal true, @analyzer.unknown?
    end

    test "returns false if a matcher class matches the current result" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          true
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_equal false, @analyzer.unknown?
    end
  end

  context "identify" do
    test "returns nil if no result is current" do
      assert_nil @analyzer.identify
    end

    test "returns nil if a result is current but no matchers are known" do
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_nil @analyzer.identify
    end

    test "returns nil if current result is not matched by any known matchers" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          false
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_nil @analyzer.identify
    end

    test "returns the matcher class which matches the current result" do
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
          true
        end
      end

      @analyzer.add matcher
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_equal matcher, @analyzer.identify.class
    end

    test "fails if more than one matcher class matches the current result" do
      matcher1 = Class.new(Dat::Analysis::Matcher) do
        def match?
          true
        end
      end

      matcher2 = Class.new(Dat::Analysis::Matcher) do
        def match?
          true
        end
      end

      @analyzer.add matcher1
      @analyzer.add matcher2
      @analyzer.mismatches.push 'mismatch-1'
      @analyzer.fetch
      assert_raises(RuntimeError) do
        @analyzer.identify
      end
    end
  end
end
