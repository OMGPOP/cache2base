require './lib/cache2base/version'

Gem::Specification.new do |s|
  s.name = %q{cache2base}
  s.version = Cache2base::VERSION

  s.authors = ["Jason Pearlman"]
  s.date = Time.now.utc.strftime("%Y-%m-%d")
  s.description = %q{A ruby orm for memcache and membase}
  s.email = %q{crash2burn@gmail.com}
  s.files = Dir.glob("lib/**/*") + [
     "LICENSE",
     "README.md",
     "History.md",
     "Rakefile",
     "Gemfile",
     "cache2base.gemspec"
  ]
  s.homepage = %q{http://github.com/OMGPOP/cache2base}
  s.has_rdoc = false  
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.summary = %q{A ruby orm for memcache and membase}
  s.test_files = Dir.glob("test/**/*")
  s.add_development_dependency(%q<rspec>, [">= 0"])
end