require 'test/unit'

rcsid = %w$Id: runner.rb,v 1.5 2004/01/29 12:58:08 nahi Exp $
Version = rcsid[2].scan(/\d+/).collect!(&method(:Integer)).freeze
Release = rcsid[3].freeze

runner = Test::Unit::AutoRunner.new(true)
runner.to_run.concat(ARGV)
runner.to_run << File.dirname(__FILE__) if runner.to_run.empty?
runner.run
