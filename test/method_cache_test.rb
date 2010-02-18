require File.dirname(__FILE__) + '/test_helper'

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
end

module Bar
  extend MethodCache

  cache_method :foo
  def foo(i)
    @i ||= 0
    @i  += i
  end
end

class Baz
  include Bar
end

class TestMethodCache < Test::Unit::TestCase
  should 'cache methods locally' do
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

  should 'cache methods for mixins' do
    a = Baz.new

    assert_equal 1, a.foo(1)
    assert_equal 1, a.foo(1)
    assert_equal 3, a.foo(2)
    assert_equal 3, a.foo(2)
  end

  should 'invalidate cached method' do
    a = Foo.new

    assert_equal 1, a.foo(1)
    assert_equal 3, a.foo(2)

    a.invalidate_cached_method(:foo, 1)

    assert_equal 4, a.foo(1)
    assert_equal 3, a.foo(2)
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
end
