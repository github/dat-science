require "minitest/autorun"
require "mocha/setup"
require "dat/analysis"
require "time"

# helper class to provide mismatch results
class TestMismatchAnalysis < Dat::Analysis
  attr_accessor :mismatches

  def initialize(experiment_name)
    super
    @mismatches = []  # use a simple array for a mismatch store
  end

  # load data files from our fixtures path
  def path
    File.expand_path(File.join(File.dirname(__FILE__), 'fixtures'))
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
    "experiment-formatter: #{result['extra']}"
  end
end

class DatAnalysisTest < MiniTest::Unit::TestCase
  def setup
    Dat::Analysis::Tally.any_instance.stubs(:puts)
    @experiment_name = 'test-suite-experiment'
    @analyzer = TestMismatchAnalysis.new @experiment_name

    @timestamp = Time.now
    @result = {
      'experiment' => @experiment_name,
      'control'    => {
          'duration'  => 0.03,
          'exception' => nil,
          'value'     => true,
        },
      'candidate'  => {
          'duration'  => 1.03,
          'exception' => nil,
          'value'     => false,
        },
      'first'      => 'candidate',
      'extra'      => 'bacon',
      'timestamp'  => @timestamp.to_s
    }
  end

  def test_preserves_the_experiment_name
    assert_equal @experiment_name, @analyzer.experiment_name
  end

  def test_analyze_returns_nil_if_there_is_no_current_result_and_no_additional_results
    assert_nil @analyzer.analyze
  end

  def test_analyze_leaves_tallies_empty_if_there_is_no_current_result_and_no_additional_results
    @analyzer.analyze
    assert_equal({}, @analyzer.tally.tally)
  end

  def test_analyze_returns_nil_if_there_is_a_current_result_but_no_additional_results
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert @analyzer.current
    assert_nil @analyzer.analyze
  end

  def test_analyze_leaves_tallies_empty_if_there_is_a_current_result_but_no_additional_results
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert @analyzer.current
    @analyzer.analyze
    assert_equal({}, @analyzer.tally.tally)
  end

  def test_analyze_outputs_default_result_summary_and_tally_summary_when_one_unrecognized_result_is_present
    @analyzer.expects(:summarize_unknown_result)
    @analyzer.mismatches.push @result
    @analyzer.analyze
  end

  def test_analyze_returns_nil_when_one_unrecognized_result_is_present
    @analyzer.mismatches.push @result
    assert_nil @analyzer.analyze
  end

  def test_analyze_leaves_current_result_set_to_first_result_when_one_unrecognized_result_is_present
    @analyzer.mismatches.push @result
    @analyzer.analyze
    assert_equal @result, @analyzer.current
  end

  def test_analyze_leaves_tallies_empty_when_one_unrecognized_result_is_present
    @analyzer.mismatches.push @result
    @analyzer.analyze
    assert_equal({}, @analyzer.tally.tally)
  end

  def test_analyze_outputs_default_results_summary_for_first_unrecognized_result_and_tally_summary_when_recognized_and_unrecognized_results_are_present
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        result['extra'] =~ /^known-/
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result.merge('extra' => 'known-1')
    @analyzer.mismatches.push @result.merge('extra' => 'unknown-1')
    @analyzer.mismatches.push @result.merge('extra' => 'known-2')

    @analyzer.expects(:summarize_unknown_result)
    @analyzer.analyze
  end

  def test_analyze_returns_number_of_unanalyzed_results_when_recognized_and_unrecognized_results_are_present
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        result['extra'] =~ /^known-/
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result.merge('extra' => 'known-1')
    @analyzer.mismatches.push @result.merge('extra' => 'unknown-1')
    @analyzer.mismatches.push @result.merge('extra' => 'known-2')

    assert_equal 1, @analyzer.analyze
  end

  def test_analyze_leaves_current_result_set_to_first_unrecognized_result_when_recognized_and_unrecognized_results_are_present
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        result['extra'] =~ /^known/
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result.merge('extra' => 'known-1')
    @analyzer.mismatches.push @result.merge('extra' => 'unknown-1')
    @analyzer.mismatches.push @result.merge('extra' => 'known-2')

    @analyzer.analyze
    assert_equal 'unknown-1', @analyzer.current['extra']
  end

  def test_analyze_leaves_recognized_result_counts_in_tally_when_recognized_and_unrecognized_results_are_present
    matcher1 = Class.new(Dat::Analysis::Matcher) do
      def self.name() "RecognizerOne" end
      def match?
        result['extra'] =~ /^known-1/
      end
    end

    matcher2 = Class.new(Dat::Analysis::Matcher) do
      def self.name() "RecognizerTwo" end
      def match?
        result['extra'] =~ /^known-2/
      end
    end

    @analyzer.add matcher1
    @analyzer.add matcher2

    @analyzer.mismatches.push @result.merge('extra' => 'known-1-last')
    @analyzer.mismatches.push @result.merge('extra' => 'unknown-1')
    @analyzer.mismatches.push @result.merge('extra' => 'known-10')
    @analyzer.mismatches.push @result.merge('extra' => 'known-20')
    @analyzer.mismatches.push @result.merge('extra' => 'known-11')
    @analyzer.mismatches.push @result.merge('extra' => 'known-21')
    @analyzer.mismatches.push @result.merge('extra' => 'known-12')

    @analyzer.analyze

    tally = @analyzer.tally.tally
    assert_equal [ 'RecognizerOne', 'RecognizerTwo' ], tally.keys.sort
    assert_equal 3, tally['RecognizerOne']
    assert_equal 2, tally['RecognizerTwo']
  end

  def test_analyze_proceeds_from_stop_point_when_analyzing_with_more_results
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        result['extra'] =~ /^known-/
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result.merge('extra' => 'known-1')
    @analyzer.mismatches.push @result.merge('extra' => 'unknown-1')
    @analyzer.mismatches.push @result.merge('extra' => 'known-2')
    @analyzer.mismatches.push @result.merge('extra' => 'unknown-2')
    @analyzer.mismatches.push @result.merge('extra' => 'known-3')

    assert_equal 3, @analyzer.analyze
    assert_equal 'unknown-2', @analyzer.current['extra']
    assert_equal 1, @analyzer.analyze
    assert_equal 'unknown-1', @analyzer.current['extra']
    assert_equal @analyzer.readable, @analyzer.last_printed
  end

  def test_analyze_resets_tally_between_runs_when_analyzing_later_results_after_a_stop
    matcher1 = Class.new(Dat::Analysis::Matcher) do
      def self.name() "RecognizerOne" end
      def match?
        result['extra'] =~ /^known-1/
      end
    end

    matcher2 = Class.new(Dat::Analysis::Matcher) do
      def self.name() "RecognizerTwo" end
      def match?
        result['extra'] =~ /^known-2/
      end
    end

    @analyzer.add matcher1
    @analyzer.add matcher2

    @analyzer.mismatches.push @result.merge('extra' => 'known-1-last')
    @analyzer.mismatches.push @result.merge('extra' => 'unknown-1')
    @analyzer.mismatches.push @result.merge('extra' => 'known-10')
    @analyzer.mismatches.push @result.merge('extra' => 'known-20')
    @analyzer.mismatches.push @result.merge('extra' => 'known-11')
    @analyzer.mismatches.push @result.merge('extra' => 'known-21')
    @analyzer.mismatches.push @result.merge('extra' => 'known-12')

    @analyzer.analyze  # proceed to first stop point
    @analyzer.analyze  # and continue analysis

    assert_equal({'RecognizerOne' => 1}, @analyzer.tally.tally)
  end

  def test_skip_fails_if_no_block_is_provided
    assert_raises(ArgumentError) do
      @analyzer.skip
    end
  end

  def test_skip_returns_nil_if_there_is_no_current_result
    remaining = @analyzer.skip do |result|
      true
    end

    assert_nil remaining
  end

  def test_skip_leaves_current_alone_if_the_current_result_satisfies_the_block
    @analyzer.mismatches.push @result

    @analyzer.skip do |result|
      true
    end
  end

  def test_skip_returns_0_if_the_current_result_satisfies_the_block_and_no_other_results_are_available
    @analyzer.mismatches.push @result

    remaining = @analyzer.skip do |result|
      true
    end

    assert_equal 0, remaining
  end

  def test_skip_returns_the_number_of_additional_results_if_the_current_result_satisfies_the_block_and_other_results_are_available
    @analyzer.mismatches.push @result
    @analyzer.mismatches.push @result
    @analyzer.mismatches.push @result

    remaining = @analyzer.skip do |result|
      true
    end

    assert_equal 2, remaining
  end

  def test_skip_returns_nil_if_no_results_are_satisfying
    @analyzer.mismatches.push @result
    @analyzer.mismatches.push @result
    @analyzer.mismatches.push @result

    remaining = @analyzer.skip do |result|
      false
    end

    assert_nil remaining
  end

  def test_skip_skips_all_results_if_no_results_are_satisfying
    @analyzer.mismatches.push @result
    @analyzer.mismatches.push @result
    @analyzer.mismatches.push @result

    remaining = @analyzer.skip do |result|
      false
    end

    assert !@analyzer.more?
  end

  def test_skip_leaves_current_as_nil_if_no_results_are_satisfying
    @analyzer.mismatches.push @result
    @analyzer.mismatches.push @result
    @analyzer.mismatches.push @result

    remaining = @analyzer.skip do |result|
      false
    end

    assert_nil @analyzer.current
  end

  def test_more_is_false_when_there_are_no_mismatches
    assert !@analyzer.more?
  end

  def test_more_is_true_when_there_are_mismatches
    @analyzer.mismatches.push @result
    assert @analyzer.more?
  end

  def test_count_fails
    assert_raises(NoMethodError) do
      Dat::Analysis.new(@experiment_name).count
    end
  end

  def test_fetch_fails_unless_read_is_implemented_by_a_subclass
    assert_raises(NameError) do
      Dat::Analysis.new(@experiment_name).fetch
    end
  end

  def test_current_returns_nil_when_no_mismmatches_have_been_fetched
    assert_nil @analyzer.current
  end

  def test_current_returns_nil_when_last_fetch_returned_no_results
    @analyzer.fetch
    assert_nil @analyzer.current
  end

  def test_current_returns_the_most_recent_mismatch_when_one_has_been_fetched
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_equal @result, @analyzer.current
  end

  def test_current_updates_with_later_fetches
    @analyzer.mismatches.push @result
    @analyzer.mismatches.push @result
    @analyzer.fetch
    result = @analyzer.fetch
    assert_equal result, @analyzer.current
  end

  def test_result_is_an_alias_for_current
    @analyzer.mismatches.push @result
    @analyzer.mismatches.push @result
    @analyzer.fetch
    result = @analyzer.fetch
    assert_equal result, @analyzer.result
  end

  def test_raw_returns_nil_when_no_mismatches_have_been_fetched
    assert_nil @analyzer.raw
  end

  def test_raw_returns_nil_when_last_fetched_returned_no_results
    @analyzer.fetch
    assert_nil @analyzer.raw
  end

  def test_raw_returns_an_unprocessed_version_of_the_most_recent_mismatch
    @analyzer.mismatches.push @result
    result = @analyzer.fetch
    assert_equal @result, @analyzer.raw
  end

  def test_raw_updates_with_later_fetches
    @analyzer.mismatches.push 'mismatch-1'
    @analyzer.mismatches.push 'mismatch-2'
    @analyzer.fetch # discard the first one
    @analyzer.fetch
    assert_equal 'mismatch-1', @analyzer.raw
  end

  def test_when_loading_support_classes_loads_no_matchers_if_no_matcher_files_exist_on_load_path
    analyzer = TestMismatchAnalysis.new('experiment-with-no-classes')
    analyzer.load_classes
    assert_equal [], analyzer.matchers
    assert_equal [], analyzer.wrappers
  end

  def test_when_loading_support_classes_loads_matchers_and_wrappers_if_they_exist_on_load_path
    analyzer = TestMismatchAnalysis.new('experiment-with-classes')
    analyzer.load_classes
    assert_equal ["MatcherA", "MatcherB", "MatcherC"], analyzer.matchers.map(&:name)
    assert_equal ["WrapperA", "WrapperB", "WrapperC"], analyzer.wrappers.map(&:name)
  end

  def test_when_loading_support_classes_ignores_extraneous_classes_on_load_path
    analyzer = TestMismatchAnalysis.new('experiment-with-good-and-extraneous-classes')
    analyzer.load_classes
    assert_equal ["MatcherX", "MatcherY", "MatcherZ"], analyzer.matchers.map(&:name)
    assert_equal ["WrapperX", "WrapperY", "WrapperZ"], analyzer.wrappers.map(&:name)
  end

  def test_when_loading_support_classes_loads_classes_at_initialization_time_if_they_are_available
    analyzer = TestMismatchAnalysis.new('initialize-classes')
    assert_equal ["MatcherM", "MatcherN"], analyzer.matchers.map(&:name)
    assert_equal ["WrapperM", "WrapperN"], analyzer.wrappers.map(&:name)
  end

  def test_when_loading_support_classes_does_not_load_classes_at_initialization_time_if_they_cannot_be_loaded
    analyzer = TestMismatchAnalysis.new('invalid-matcher')
    assert_equal [], analyzer.matchers
  end

  def test_loading_classes_post_initialization_fails_if_loading_has_errors
    # fails at #load_classes time since we define #path later
    analyzer = Dat::Analysis.new('invalid-matcher')
    analyzer.path = File.expand_path(File.join(File.dirname(__FILE__), 'fixtures'))

    assert_raises(Errno::EACCES) do
      analyzer.load_classes
    end
  end

  def test_result_has_an_useful_timestamp
    @analyzer.mismatches.push(@result)
    result = @analyzer.fetch
    assert_equal @timestamp.to_i, result.timestamp.to_i
  end

  def test_result_has_a_method_for_first
    @analyzer.mismatches.push(@result)
    result = @analyzer.fetch
    assert_equal @result['first'], result.first
  end

  def test_result_has_a_method_for_control
    @analyzer.mismatches.push(@result)
    result = @analyzer.fetch
    assert_equal @result['control'], result.control
  end

  def test_result_has_a_method_for_candidate
    @analyzer.mismatches.push(@result)
    result = @analyzer.fetch
    assert_equal @result['candidate'], result.candidate
  end

  def test_result_has_a_method_for_experiment_name
    @analyzer.mismatches.push(@result)
    result = @analyzer.fetch
    assert_equal @result['experiment'], result.experiment_name
  end

  def test_results_helper_methods_are_not_available_on_results_unless_loaded
    @analyzer.mismatches.push @result
    result = @analyzer.fetch

    assert_raises(NoMethodError) do
      result.repository
    end
  end

  def test_results_helper_methods_are_made_available_on_returned_results
    wrapper = Class.new(Dat::Analysis::Result) do
      def repository
        'github/dat-science'
      end
    end

    @analyzer.add wrapper
    @analyzer.mismatches.push @result
    result = @analyzer.fetch
    assert_equal 'github/dat-science', result.repository
  end

  def test_results_helper_methods_can_be_loaded_from_multiple_classes
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
    @analyzer.mismatches.push @result
    result = @analyzer.fetch
    assert_equal 'github/dat-science', result.repository
    assert_equal :rick, result.user
  end

  def test_results_helper_methods_are_made_available_in_the_order_loaded
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
    @analyzer.mismatches.push @result
    result = @analyzer.fetch
    assert_equal 'github/dat-science', result.repository
    assert_equal :rick, result.user
  end

  def test_results_helper_methods_do_not_hide_existing_result_methods
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

  def test_methods_can_access_the_result_using_the_result_method
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

  def test_summarize_returns_nil_and_prints_the_empty_string_if_no_result_is_current
    assert_nil @analyzer.summarize
    assert_equal "", @analyzer.last_printed
  end

  def test_summarize_returns_nil_and_prints_the_default_readable_result_if_a_result_is_current_but_no_matchers_are_known
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_nil @analyzer.summarize
    assert_equal @analyzer.readable, @analyzer.last_printed
  end

  def test_summarize_returns_nil_and_prints_the_default_readable_result_if_a_result_is_current_but_not_matched_by_any_known_matchers
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        false
      end

      def readable
        'this should never run'
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_nil @analyzer.summarize
    assert_equal @analyzer.readable, @analyzer.last_printed
  end

  def test_summarize_returns_nil_and_prints_the_matchers_readable_result_when_a_result_is_current_and_matched_by_a_matcher
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        true
      end

      def readable
        "recognized: #{result['extra']}"
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result.merge('extra' => 'mismatch-1')
    @analyzer.fetch
    assert_nil @analyzer.summarize
    assert_equal "recognized: mismatch-1", @analyzer.last_printed
  end

  def test_summarize_returns_nil_and_prints_the_default_readable_result_when_a_result_is_matched_by_a_matcher_with_no_formatter
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        true
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_nil @analyzer.summarize
    assert_equal @analyzer.readable, @analyzer.last_printed
  end

  def test_summarize_supports_use_of_a_matcher_base_class_for_shared_formatting
    matcher = Class.new(TestSubclassRecognizer) do
      def match?
        true
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result.merge('extra' => 'mismatch-1')
    @analyzer.fetch
    assert_nil @analyzer.summarize
    assert_equal "experiment-formatter: mismatch-1", @analyzer.last_printed
  end

  def test_summary_returns_nil_if_no_result_is_current
    assert_nil @analyzer.summary
  end

  def test_summary_returns_the_default_readable_result_if_a_result_is_current_but_no_matchers_are_known
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_equal @analyzer.readable, @analyzer.summary
  end

  def test_summary_returns_the_default_readable_result_if_a_result_is_current_but_not_matched_by_any_known_matchers
      matcher = Class.new(Dat::Analysis::Matcher) do
        def match?
        false
      end

      def readable
        'this should never run'
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_equal @analyzer.readable, @analyzer.summary
  end

  def test_summary_returns_the_matchers_readable_result_when_a_result_is_current_and_matched_by_a_matcher
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        true
      end

      def readable
        "recognized: #{result['extra']}"
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result.merge('extra' => 'mismatch-1')
    @analyzer.fetch
    assert_equal "recognized: mismatch-1", @analyzer.summary
  end

  def test_summary_formats_with_the_default_formatter_if_a_matching_matcher_does_not_define_a_formatter
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        true
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_equal @analyzer.readable, @analyzer.summary
  end

  def test_summary_supports_use_of_a_matcher_base_class_for_shared_formatting
    matcher = Class.new(TestSubclassRecognizer) do
      def match?
        true
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result.merge('extra' => 'mismatch-1')
    @analyzer.fetch
    assert_equal "experiment-formatter: mismatch-1", @analyzer.summary
  end

  def test_unknown_returns_nil_if_no_result_is_current
    assert_nil @analyzer.unknown?
  end

  def test_unknown_returns_true_if_a_result_is_current_but_no_matchers_are_known
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_equal true, @analyzer.unknown?
  end

  def test_unknown_returns_true_if_current_result_is_not_matched_by_any_known_matchers
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        false
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_equal true, @analyzer.unknown?
  end

  def test_unknown_returns_false_if_a_matcher_class_matches_the_current_result
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        true
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_equal false, @analyzer.unknown?
  end

  def test_identify_returns_nil_if_no_result_is_current
    assert_nil @analyzer.identify
  end

  def test_identify_returns_nil_if_a_result_is_current_but_no_matchers_are_known
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_nil @analyzer.identify
  end

  def test_identify_returns_nil_if_current_result_is_not_matched_by_any_known_matchers
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        false
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_nil @analyzer.identify
  end

  def test_identify_returns_the_matcher_class_which_matches_the_current_result
    matcher = Class.new(Dat::Analysis::Matcher) do
      def match?
        true
      end
    end

    @analyzer.add matcher
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_equal matcher, @analyzer.identify.class
  end

  def test_identify_fails_if_more_than_one_matcher_class_matches_the_current_result
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
    @analyzer.mismatches.push @result
    @analyzer.fetch
    assert_raises(RuntimeError) do
      @analyzer.identify
    end
  end
end
