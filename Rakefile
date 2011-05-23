require 'rake/clean'
CLEAN.include "**/*.rbc"
CLEAN.include "**/.DS_Store"
CLEAN.include "cache2base-*.gem"

require File.expand_path("../lib/cache2base/version", __FILE__)

NAME = 'cache2base'

# Gem Packaging and Release

desc "Packages cache2base"
task :package=>[:clean] do |p|
  sh %{gem build cache2base.gemspec}
end

desc "Install cache2base gem"
task :install=>[:package] do
  sh %{sudo gem install ./#{NAME}-#{Cache2base::VERSION} --local}
end

desc "Uninstall cache2base gem"
task :uninstall=>[:clean] do
  sh %{sudo gem uninstall #{NAME}}
end

desc "Upload cache2base gem to gemcutter"
task :release=>[:package] do
  sh %{gem push ./#{NAME}-#{Cache2base::VERSION}.gem} 
end