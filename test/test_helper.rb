require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'pp'

$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"
$LOAD_PATH.unshift File.dirname(__FILE__) + "/../../memcache/lib"
$LOAD_PATH.unshift File.dirname(__FILE__) + "/../../cache_version/lib"
require 'method_cache'

class Test::Unit::TestCase
end
