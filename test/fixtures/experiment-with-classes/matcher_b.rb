class MatcherB < Dat::Analysis::Matcher
  def match?
    result =~ /b/
  end
end

class MatcherC < Dat::Analysis::Matcher
  def match?
    result =~ /c/
  end
end
