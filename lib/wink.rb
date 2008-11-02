require 'sinatra'

gem 'dm-core'
gem 'dm-validations'
gem 'dm-ar-finders'
# For Atom feeds
gem 'builder'

require 'wink/core_extensions'
require 'wink/schema'

# Tell Sinatra to not automatically start a server.
set :run, false

unless reloading?
  load 'wink/defaults.rb'
end


module Wink
  extend self

  VERSION = '0.2'

  # An OpenStruct with all application options.
  def options
    Sinatra.application.options
  end

  # Get an option value.
  def [](option_name)
    options.send(option_name)
  end

  # Set an option value.
  def []=(option_name, value)
    options.send("#{option_name}=", value)
  end

  # Respond to any option attributes defined on the underlying #options
  # object and also to all setter messages.
  def respond_to?(name, include_private=false)
    super ||
      options.respond_to?(name, include_private) ||
      name.to_s[-1] == ?=
  end

  # Delegate all messages to the underlying #options object.
  def method_missing(name, *args, &block)
    options.__send__(name, *args, &block)
  end

  private :method_missing


  # Options ====================================================================

  def akismet_url
    self[:url]
  end


  # Configuration ==============================================================

  # Load configuration from the file specified and/or by executing the block. If
  # both a file and block are given, the config file is loaded first and then
  # the block is executed.
  #
  # Database configuration must be in place once the config file and block are
  # processed.
  def configure(file=nil)
    Kernel::load(file) if file
    yield options if block_given?
    require 'wink/models'
    self
  end

  # Load configuration from the file and/or block as specified in Wink#configure
  # and setup Sinatra to start a server instance.
  def run!(config_file=nil, &block)
    configure(config_file, &block)
    require 'wink/web'
    Sinatra.application.options.run = true
  end

  # Rackup compatible constructor. Use in Rackup files as follows:
  #
  #   require 'wink'
  #   run Wink do |config|
  #     config.env = :production
  #     config.url = 'http://example.com'
  #   end
  #
  # If neither a config_file or a block is given, load the default
  # config file: 'wink.conf'.
  def new(config_file=nil, &block)
    config_file ||= 'wink.conf' unless block_given?
    configure(config_file, &block)
    require 'wink/web'
    Sinatra.application
  end

end
