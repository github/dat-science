Gem::Specification.new do |gem|
  gem.name          = "dat-science"
  gem.version       = "1.4.0"
  gem.authors       = ["John Barnette", "Rick Bradley"]
  gem.email         = ["jbarnette@github.com"]
  gem.description   = "Gradually test, measure, and track refactored code."
  gem.summary       = "SO BRAVE WITH SCIENCE."
  gem.homepage      = "https://github.com/github/dat-science"

  gem.files         = `git ls-files`.split $/
  gem.executables   = []
  gem.test_files    = gem.files.grep /^test/
  gem.require_paths = ["lib"]

  gem.add_development_dependency "minitest"
  gem.add_development_dependency "mocha"
end
