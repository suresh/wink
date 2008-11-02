require 'rubygems'
require 'sinatra'
Sinatra::Application.default_options.merge!(
  :run => false,
  :env => ENV['RACK_ENV'],
  :raise_errors => true
)

log = File.new("sinatra.log", "a")
STDOUT.reopen(log)
STDERR.reopen(log)

root_dir = File.dirname(__FILE__)
$:.unshift "#{root_dir}/lib"
$:.unshift "#{root_dir}"

require 'wink'

run Wink.new('wink.conf')

# vim: ft=ruby
