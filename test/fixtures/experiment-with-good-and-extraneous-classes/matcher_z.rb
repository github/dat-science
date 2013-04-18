class MatcherZ < Dat::Analysis::Matcher
  def match?
    result =~ /^known/
  end
end

class MatcherV
  def match?
    true
  end
end
