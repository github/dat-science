module Dat
    # Public: Analyze the findings of an Experiment
    #
    # Typically implementors will wish to subclass this to provide their own
    # implementations of the following methods suited to the environment where
    # `dat-science` is being used:  `#read`, `#count`, `#cook`.
    #
    # Example:
    #
    #   class AnalyzeThis < Dat::Analysis
    #     # Read a result out of our redis stash
    #     def read
    #       RedisHandle.rpop "scienceness.#{experiment_name}.results"
    #     end
    #
    #     # Query our redis stash to see how many new results are pending
    #     def count
    #       RedisHandle.llen("scienceness.#{experiment_name}.results")
    #     end
    #
    #     # Deserialize a JSON-encoded result from redis
    #     def cook(raw_result)
    #       return nil unless raw_result
    #       JSON.parse raw_result
    #     end
    #   end
    class Analysis

    # Public: Returns the name of the experiment
    attr_reader   :experiment_name

    # Public: Returns the current science mismatch result
    attr_reader   :current

    # Public: an alias for #current
    alias_method  :result, :current

    # Public: Returns a raw ("un-cooked") version of the current science mismatch result
    attr_reader   :raw

    # Public: Gets/Sets the base path for loading matcher and wrapper classes.
    #         Note that the base path will be appended with the experiment name
    #         before searching for wrappers and matchers.
    attr_accessor :path

    # Public: Create a new Dat::Analysis object.  Will load any matcher and
    #         wrapper classes for this experiment if `#path` is non-nil.
    #
    # experiment_name - The String naming the experiment to analyze.
    #
    # Examples
    #
    #   analyzer = Dat::Analysis.new('bcrypt-passwords')
    #   => #<Dat::Analysis:...>
    def initialize(experiment_name)
      @experiment_name = experiment_name
      @wrappers = []

      load_classes unless path.nil? rescue nil
    end

    # Public: process a raw science mismatch result to make it usable in analysis.
    # This is typically overridden by subclasses to do any sort of unmarshalling
    # or deserialization required.
    #
    # raw_result - a raw science mismatch result, typically, as returned by `#read`
    #
    # Returns a "cooked" science mismatch result.
    def cook(raw_result)
      raw_result
    end

    # Public: fetch and summarize pending science mismatch results until an
    # an unrecognized result is found.  Outputs summaries to STDOUT.  May
    # modify current mismatch result.
    #
    # Returns nil.  Leaves current mismatch result set to first unknown result,
    # if one is found.
    def analyze
      track do
        while true
          unless more?
            fetch # clear current result
            return summarize_unknown_result
          end

          fetch
          break if unknown?
          summarize
          count_as_seen identify
        end

        print "\n"
        summarize_unknown_result
      end
    end

    # Public: skip pending mismatch results not satisfying the provided block.
    # May modify current mismatch result.
    #
    # &block - block accepting a prepared mismatch result and returning true
    #          or false.
    #
    # Examples:
    #
    #   skip do |result|
    #     result.user.staff?
    #   end
    #
    #   skip do |result|
    #     result['group']['id'] > 100 && result['url'] =~ %r{/admin}
    #   end
    #
    #   skip do |result|
    #     result['timestamp'].to_i > 1.hour.ago
    #   end
    #
    # Returns nil if no satisfying results are found.  Current result will be nil.
    # Returns count of remaining results if a satisfying result found.  Leaves
    # current result set to first result for which block returns a truthy value.
    def skip(&block)
      raise ArgumentError, "a block is required" unless block_given?

      while more?
        fetch
        return count if yield(current)
      end

      # clear current result since nothing of interest was found.
      @current = @identified = nil
    end

    # Public: Are additional science mismatch results available?
    #
    # Returns true if more results can be fetched.
    # Returns false if no more results can be fetched.
    def more?
      count != 0
    end

    # Public: retrieve a new science mismatch result, as returned by `#read`.
    #
    # Returns nil if no new science mismatch results are available.
    # Returns a cooked and wrapped science mismatch result if available.
    # Raises NoMethodError if `#read` is not defined on this class.
    def fetch
      @identified = nil
      @raw = read
      @current = raw ? prepare(raw) : nil
    end

    # Public: Return a readable representation of the current science mismatch
    # result.  This will utilize the `#readable` methods declared on a matcher
    # which identifies the current result.
    #
    # Returns a string containing a readable representation of the current
    # science mismatch result.
    # Returns nil if there is no current result.
    def summary
      return nil unless current
      recognizer = identify
      return readable unless recognizer && recognizer.respond_to?(:readable)
      recognizer.readable
    end

    # Public: Print a readable summary for the current science mismatch result
    # to STDOUT.
    #
    # Returns nil.
    def summarize
      puts summary
    end

    # Public: Is the current science mismatch result unidentifiable?
    #
    # Returns nil if current result is nil.
    # Returns true if no matcher can identify current result.
    # Returns false if a single matcher can identify the current result.
    # Raises RuntimeError if multiple matchers can identify the current result.
    def unknown?
      return nil if current.nil?
      !identify
    end

    # Public: Find a matcher which can identify the current science mismatch result.
    #
    # Returns nil if current result is nil.
    # Returns matcher class if a single matcher can identify current result.
    # Returns false if no matcher can identify the current result.
    # Raises RuntimeError if multiple matchers can identify the current result.
    def identify
      return @identified if @identified

      results = registry.identify(current)
      if results.size > 1
        report_multiple_matchers(results)
      end

      @identified = results.first
    end

    # Internal: Output failure message about duplicate matchers for a science
    #           mismatch result.
    #
    # dupes - Array of Dat::Analysis::Matcher instances, initialized with a result
    #
    # Raises RuntimeError.
    def report_multiple_matchers(dupes)
      puts "\n\nMultiple matchers identified result:"
      puts

      dupes.each_with_index do |matcher, i|
        print " #{i+1}. "
        if matcher.respond_to?(:readable)
          puts matcher.readable
        else
          puts readable
        end
      end

      puts
      raise "Result cannot be uniquely identified."
    end

    # Internal: cook and wrap a raw science mismatch result.
    #
    # raw_result - an unmodified result, typically, as returned by `#read`
    #
    # Returns the science mismatch result processed by `#cook` and then by `#wrap`.
    def prepare(raw_result)
      wrap(cook(raw_result))
    end

    # Internal: wrap a "cooked" science mismatch result with any known wrapper methods
    #
    # cooked_result - a "cooked" mismatch result, as returned by `#cook`
    #
    # Returns the cooked science mismatch result, which will now respond to any
    # instance methods found on our known wrapper classes
    def wrap(cooked_result)
      cooked_result.extend Dat::Analysis::Result::DefaultMethods

      if !wrappers.empty?
        cooked_result.send(:instance_variable_set, '@analyzer', self)

        class << cooked_result
          define_method(:method_missing) do |meth, *args|
            found = nil
            @analyzer.wrappers.each do |wrapper|
              next unless wrapper.public_instance_methods.detect {|m| m.to_s == meth.to_s }
              found = wrapper.new(self).send(meth, *args)
              break
            end
            found
          end
        end
      end

      cooked_result
    end

    # Internal:  Return the *default* readable representation of the current science
    # mismatch result. This method is typically overridden by subclasses or defined
    # in matchers which wish to customize the readable representation of a science
    # mismatch result. This implementation is provided as a default.
    #
    # Returns a string containing a readable representation of the current
    # science mismatch result.
    def readable
      synopsis = []

      synopsis << "Experiment %-20s first: %10s @ %s" % [
        "[#{current['experiment']}]", current['first'], current['timestamp']
      ]
      synopsis << "Duration:  control (%6.2f) | candidate (%6.2f)" % [
        current['control']['duration'], current['candidate']['duration']
      ]

      synopsis << ""

      if current['control']['exception']
        synopsis << "Control raised exception:\n\t#{current['control']['exception'].inspect}"
      else
        synopsis << "Control value:   [#{current['control']['value']}]"
      end

      if current['candidate']['exception']
        synopsis << "Candidate raised exception:\n\t#{current['candidate']['exception'].inspect}"
      else
        synopsis << "Candidate value: [#{current['candidate']['value']}]"
      end

      synopsis << ""

      remaining = current.keys - ['control', 'candidate', 'experiment', 'first', 'timestamp']
      remaining.sort.each do |key|
        if current[key].respond_to?(:keys)
          # do ordered sorting of hash keys
          subkeys = key_sort(current[key].keys)
          synopsis << "\t%15s => {" % [ key ]
          subkeys.each do |subkey|
            synopsis << "\t%15s       %15s => %-20s" % [ '', subkey, current[key][subkey].inspect ]
          end
          synopsis << "\t%15s    }" % [ '' ]
        else
          synopsis << "\t%15s => %-20s" % [ key, current[key] ]
        end
      end

      synopsis.join "\n"
    end

    def preferred_fields
      %w(id name title owner description login username)
    end

    def key_sort(keys)
      str_keys = keys.map {|k| k.to_s }
      (preferred_fields & str_keys) + (str_keys - preferred_fields)
    end

    # Public: Which matcher classes are known?
    #
    # Returns: list of Dat::Analysis::Matcher classes known to this analyzer.
    def matchers
      registry.matchers
    end

    # Public: Which wrapper classes are known?
    #
    # Returns: list of Dat::Analysis::Result classes known to this analyzer.
    def wrappers
      registry.wrappers
    end

    # Public: Add a matcher or wrapper class to this analyzer.
    #
    # klass - a subclass of either Dat::Analysis::Matcher or Dat::Analysis::Result
    #         to be registered with this analyzer.
    #
    # Returns the list of known matchers and wrappers for this analyzer.
    def add(klass)
      klass.add_to_analyzer(self)
    end

    # Public: Load matcher and wrapper classes from the library for our experiment.
    #
    # Returns: a list of loaded matcher and wrapper classes.
    def load_classes
      new_classes = library.select_classes do
        experiment_files.each { |file| load file }
      end

      new_classes.map {|klass| add klass }
    end

    # Internal:  Print to STDOUT a readable summary of the current (unknown) science
    # mismatch result, as well a summary of the tally of identified science mismatch
    # results analyzed to this point.
    #
    # Returns nil if there are no pending science mismatch results.
    # Returns the number of pending science mismatch results.
    def summarize_unknown_result
      tally.summarize
      if current
        puts "\nFirst unidentifiable result:\n\n"
        summarize
      else
        puts "\nNo unidentifiable results found. \\m/\n"
      end

      more? ? count : nil
    end

    # Internal: keep a tally of analyzed science mismatch results.
    #
    # &block: block which will presumably call `#count_as_seen` to update
    #         tallies of identified science mismatch results.
    #
    # Returns: value returned by &block.
    def track(&block)
      @tally = Tally.new
      yield
    end

    # Internal: Increment count for an object in an ongoing tally.
    #
    # obj - an Object for which we are recording occurrence counts
    #
    # Returns updated tally count for obj.
    def count_as_seen(obj)
      tally.count(obj.class.name || obj.class.inspect)
    end

    # Internal: The current Tally instance.  Cached between calls to `#track`.
    #
    # Returns the current Tally instance object.
    def tally
      @tally ||= Tally.new
    end

    # Internal: handle to the library, used for collecting newly discovered
    # matcher and wrapper classes.
    #
    # Returns: handle to the library class.
    def library
      Dat::Analysis::Library
    end

    # Internal: registry of wrapper and matcher classes known to this analyzer.
    #
    # Returns a (cached between calls) handle to our registry instance.
    def registry
      @registry ||= Dat::Analysis::Registry.new
    end

    # Internal: which class files are candidates for loading matchers and wrappers
    # for this experiment?
    #
    # Returns: sorted Array of paths to ruby files which may contain declarations
    # of matcher and wrapper classes for this experiment.
    def experiment_files
      Dir[File.join(path, experiment_name, '*.rb')].sort
    end

    # Internal:  Add a matcher class to this analyzer's registry.
    # (Intended to be called only by Dat::Analysis::Matcher and subclasses)
    def add_matcher(matcher_class)
      puts "Loading matcher class [#{matcher_class}]"
      registry.add matcher_class
    end

    # Internal:  Add a wrapper class to this analyzer's registry.
    # (Intended to be called only by Dat::Analysis::Result and its subclasses)
    def add_wrapper(wrapper_class)
      puts "Loading results wrapper class [#{wrapper_class}]"
      registry.add wrapper_class
    end
  end
end

require 'dat/analysis/library'
require 'dat/analysis/matcher'
require 'dat/analysis/result'
require 'dat/analysis/registry'
require 'dat/analysis/tally'
