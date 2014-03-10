Gem::Specification.new do |gem|
  gem.name          = "dat-science"
  gem.version       = "1.2.1"
  gem.authors       = ["John Barnette", "Rick Bradley"]
  gem.email         = ["jbarnette@github.com"]
  gem.description   = "Gradually test, measure, and track refactored code."
  gem.summary       = "SO BRAVE WITH SCIENCE."
  gem.homepage      = "https://github.com/github/dat-science"

  gem.files         = `git ls-files`.split $/
  gem.executables   = []
  gem.test_files    = gem.files.grep /^test/
  gem.require_paths = ["lib"]

  gem.add_development_dependency "minitest", "~> 5.0.8"
  gem.add_development_dependency "mocha",    "~> 0.14.0"
end
