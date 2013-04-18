class MatcherX < Dat::Analysis::Matcher
  def match?
    result =~ /b/
  end
end

class MatcherY < Dat::Analysis::Matcher
  def match?
    result =~ /c/
  end
end
