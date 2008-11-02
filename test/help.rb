# Wink test helper file. Most test files require this file before
# anything else.

# if this is the initial run, setup the load path:
root_dir = File.
  expand_path("#{File.dirname(__FILE__)}/..").
  sub(/^#{Dir.getwd}/, '.')
$:.unshift "#{root_dir}/sinatra/lib" if File.exist?("#{root_dir}/sinatra")
$:.unshift "#{root_dir}/lib"
$:.unshift "#{root_dir}/test"

require 'rubygems'
require 'wink'
require 'sinatra/test/unit'
require 'sinatra/test/spec'

Database.configure 'sqlite3::memory:'

Wink.configure do
  set :env, :test
  set :url, 'http://test.local'
  set :author, 'John Doe'
  set :log_stream, File.open('test.log', 'wb')
end

class Test::Unit::TestCase

  def setup_database
    Database.create! :force => true
  end

  def teardown_database
    Database.drop!
  end

  # Assert that the given constant is defined. The const_name may include
  # sub-modules.
  def assert_const_defined(const_name)
    const_name.split('::').inject(Object) do |base,name|
      assert base.const_defined?(name),
        "constant should be defined: #{const_name} (#{name})"
      base.const_get(name)
    end
  end

  def assert_validated(model)
    assert_equal [], model.errors.full_messages
  end

end


class Object
  def truthful?
    !!self
  end
end
