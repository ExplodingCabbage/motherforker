#!/usr/bin/env ruby

# Require all gems
require "rubygems"
require "bundler/setup"
Bundler.require

# Add include path to use for all non-gem requires
$LOAD_PATH.unshift File.dirname(__FILE__)