class MatcherN < Dat::Analysis::Matcher
  def match?
    result =~ /n/
  end
end

class MatcherO
  def match?
    true
  end
end
