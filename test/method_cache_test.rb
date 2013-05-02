require File.dirname(__FILE__) + '/test_helper'
require 'memcache'

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

  @@i = 0
  def baz(i)
    @@i += i
  end
  cache_method :baz, :cache => :remote

  cache_class_method :bap
  def self.bap(i)
    @i ||= 0
    @i  += i
  end
  
  cache_class_method :zap, :counter => true
  def self.zap
    0
  end

  attr_accessor :z
  def zang
    self.z ||= 1
    self.z  += 1
    nil
  end
  cache_method :zang
end

module Bar
  extend MethodCache

  cache_method :foo
  def foo(i)
    @i ||= 0
    @i  += i
  end

  cache_method :foo_count, :counter => true, :cache => :default
  def foo_count(key)
    100
  end
end

class Baz
  include Bar
  extend  Bar
end

class TestMethodCache < Test::Unit::TestCase
  should 'cache methods locally' do
    a = Foo.new
    f1 = a.foo(1)
    f2 = a.foo(2)

    assert_equal 1, f1
    assert_equal 3, f2

    assert_equal     f1, a.foo(1)
    assert_not_equal f1, f2
    assert_equal     f2, a.foo(2)

    # b = a.bar
    # assert_equal b, a.bar
    # assert_equal b, a.bar
  end

  should 'disable method_cache' do
    a = Foo.new
    f1 = a.foo(1)

    f2 = a.without_method_cache do
      a.foo(1)
    end

    f3 = MethodCache.disable do
      a.foo(1)
    end

    assert f1 != f2
    assert f1 != f3
    assert f2 != f3
  end

  should 'cache methods remotely' do
    a = Foo.new
    b1 = a.baz(1)
    b2 = a.baz(2)

    assert_equal 1, b1
    assert_equal 3, b2

    assert b1 == a.baz(1)
    assert b1 != b2
    assert b2 == a.baz(2)
  end

  should 'cache class methods' do
    assert_equal 10, Foo.bap(10)
    assert_equal 23, Foo.bap(13)
    assert_equal 10, Foo.bap(10)
    assert_equal 23, Foo.bap(13)
  end

  should 'cache methods for mixins' do
    a = Baz.new

    assert_equal 1, a.foo(1)
    assert_equal 1, a.foo(1)
    assert_equal 3, a.foo(2)
    assert_equal 3, a.foo(2)
  end

  should 'cache class methods for mixins' do
    assert_equal 1, Baz.foo(1)
    assert_equal 1, Baz.foo(1)
    assert_equal 3, Baz.foo(2)
    assert_equal 3, Baz.foo(2)
  end

  should 'invalidate cached method' do
    a = Foo.new

    assert_equal 1, a.foo(1)
    assert_equal 3, a.foo(2)

    a.invalidate_cached_method(:foo, 1)

    assert_equal 4, a.foo(1)
    assert_equal 3, a.foo(2)
  end

  should 'cache counters' do
    b = Baz.new

    assert_equal 100, b.foo_count(:bar)
    b.increment_foo_count(:bar, :by => 42)
    assert_equal 142, b.foo_count(:bar)
    b.decrement_foo_count(:bar, :by => 99)
    assert_equal 43, b.foo_count(:bar)
    b.increment_foo_count(:bar)
    assert_equal 44, b.foo_count(:bar)

    assert_equal 100, b.foo_count(:baz)
    b.increment_foo_count(:baz)
    assert_equal 101, b.foo_count(:baz)
    assert_equal 44,  b.foo_count(:bar) # make sure :bar wasn't affected

    assert_equal 0, Foo.zap
    Foo.increment_zap(:by => 3)
    assert_equal 3, Foo.zap
    Foo.decrement_zap
    assert_equal 2, Foo.zap
  end

  should 'use consistent local keys' do
    a = Foo.new
    o = Object.new
    a_hash = a.hash
    o_hash = o.hash

    5.times do
      key = a.send(:cached_method, :bar, [{'a' => 3, 'b' => [5,6], 'c' => o}, [1,nil,{:o => o}]]).key
      assert_equal "m|:bar|Foo-#{a_hash}|{'a'=3,'b'=[5,6],'c'=Object-#{o_hash}}|[1,nil,{:o=Object-#{o_hash}}]", key
    end
  end

  should 'use consistent remote keys' do
    a = Foo.new
    o = Object.new
    a_hash = Marshal.dump(a).hash
    o_hash = Marshal.dump(o).hash

    5.times do
      key = a.send(:cached_method, :baz, [{:a => 3, :b => [5,6], :c => o}, [false,true,{:o => o}]]).key
      assert_equal "m|:baz|Foo-#{a_hash}|{:a=3,:b=[5,6],:c=Object-#{o_hash}}|[false,true,{:o=Object-#{o_hash}}]", key
    end
  end
  
  should 'cache nil locally' do
    a = Foo.new
    a.zang
    a.zang
    assert_equal 2, a.z
  end
end
