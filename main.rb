#!/usr/bin/env ruby
$VERBOSE = true

# Require all gems
require "rubygems"
require "bundler/setup"
Bundler.require

# Add include path to use for all non-gem requires
$LOAD_PATH.unshift File.dirname(__FILE__)

# Load everything (nicked from http://stackoverflow.com/a/1849985)
# This is just here as a temporary hack to make testing from the REPL easier
Dir["#{File.dirname(__FILE__)}/**/*.rb"].each { |f| require(f) }