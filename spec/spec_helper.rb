require 'rubygems'
require 'rspec'
require 'dalli'
#MEMBASE = Dalli::Client.new('localhost:11222')

unless Object.const_defined?('Cache2base')
  require File.join(File.dirname(__FILE__), "../lib/cache2base.rb")
end

