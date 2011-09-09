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
  def start_memcache(port)
    system("memcached -p #{port} -U 0 -d -P /tmp/memcached_#{port}.pid")
    sleep 1
    File.read("/tmp/memcached_#{port}.pid")
  end
end
