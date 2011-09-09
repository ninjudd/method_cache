require 'test_helper'
require 'dalli'

PORT    = 19112
$client = Dalli::Client.new("localhost:#{PORT}")

class FooBar
  extend MethodCache

  cache_method :foo, :cache => $client 
  def foo
    'bar'
  end
end

class MethodCacheRemoteTest < Test::Unit::TestCase

  should 'work with dalli client' do
    start_memcache(PORT)
    $client.flush

    f = FooBar.new
    assert_equal 'bar', f.foo
  end
end
