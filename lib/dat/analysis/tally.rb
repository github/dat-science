module Dat
  # Internal: Track and summarize counts of occurrences of mismatch objects.
  #
  # Examples
  #
  #   tally = Dat::Analysis::Tally.new
  #   tally.count('foo')
  #   => 1
  #   tally.count('bar')
  #   => 1
  #   tally.count('foo')
  #   => 2
  #   puts tally.summary
  #   Summary of known mismatches found:
  #   foo	2
  #   bar	1
  #   TOTAL:	3
  #   => nil
  #
  class Analysis::Tally

    # Public: Returns the hash of recorded mismatches.
    attr_reader :tally

    def initialize
      @tally = {}
    end

    # Public: record an occurrence of a mismatch class.
    def count(klass)
      tally[klass] ||= 0
      tally[klass] += 1
    end

    # Public: Return a String summary of mismatches seen so far.
    #
    # Returns a printable String summarizing the counts of mismatches seen,
    # sorted in descending count order.
    def summary
      return "\nNo results identified.\n" if tally.keys.empty?
      result = [ "\nSummary of identified results:\n" ]
      sum = 0
      tally.keys.sort_by {|k| -1*tally[k] }.each do |k|
        sum += tally[k]
        result << "%30s: %6d" % [k, tally[k]]
      end
      result << "%30s: %6d" % ['TOTAL', sum]
      result.join "\n"
    end

    # Public: prints a summary of mismatches seen so far to STDOUT (see
    # `#summary` above).
    #
    # Returns nil.
    def summarize
      puts summary
    end
  end
end
