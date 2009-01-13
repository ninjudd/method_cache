require File.dirname(__FILE__) + '/test_helper.rb'
require 'pp'

class Foo
  extend MethodCache
  
  def foo(i)
    @i ||= 0
    @i  += i
  end
  cache_method :foo

  cache_method :bar
  def bar
    @i ||= 0
    @i  += 1
  end
end

class TestMethodCache < Test::Unit::TestCase
  def test_cache_method
    a = Foo.new
    f1 = a.foo(1)
    f2 = a.foo(2)
    
    assert_equal 1, f1
    assert_equal 3, f2
    
    assert f1 == a.foo(1)
    assert f1 != f2
    assert f2 == a.foo(2)
    
    b = a.bar
    assert b == a.bar
    assert b == a.bar
  end

  def test_invalidate_cached_method
    a = Foo.new
    
    assert_equal 1, a.foo(1)
    assert_equal 3, a.foo(2)
    
    a.invalidate_cached_method(:foo, 1)

    assert_equal 4, a.foo(1)
    assert_equal 3, a.foo(2)
  end
end
