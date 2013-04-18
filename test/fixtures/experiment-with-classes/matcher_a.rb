class MatcherA < Dat::Analysis::Matcher
  def match?
    result =~ /^known/
  end
end
