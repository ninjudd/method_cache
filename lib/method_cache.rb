$:.unshift(File.dirname(__FILE__))
require 'method_cache/local_cache'
require 'method_cache/proxy'

module Ifttt
module MethodCache
  def cache_method(method_name, opts = {})
    method_name = method_name.to_sym
    (opts[:version] ||= self.to_s) if self.class == Module # maybe in other cases too?
    proxy = opts.kind_of?(Proxy) ? opts : Proxy.new(method_name, opts)

    if self.class == Class
      return if instance_methods.include?(proxy.method_name_without_caching)

      if cached_instance_methods.empty?
        include(HelperMethods)
        extend(MethodAdded)
      end

      cached_instance_methods[method_name] = nil
      if method_defined?(method_name) or private_method_defined?(method_name)
        if proxy.opts[:counter]
          define_method "increment_#{method_name}", proxy.counter_method(:increment)
          define_method "decrement_#{method_name}", proxy.counter_method(:decrement)
        end

        # Replace instance method.
        alias_method proxy.method_name_without_caching, method_name
        define_method method_name, proxy.method_with_caching
      end
      cached_instance_methods[method_name] = proxy

    elsif self.class == Module
      # We will alias all methods when the module is mixed-in.
      extend(ModuleAdded) if cached_module_methods.empty?
      cached_module_methods[method_name.to_sym] = proxy
    end
  end

  def cache_class_method(method_name, opts = {})
    method_name = method_name.to_sym
    proxy = opts.kind_of?(Proxy) ? opts : Proxy.new(method_name, opts)

    return if methods.include?(proxy.method_name_without_caching)

    if cached_class_methods.empty?
      extend(HelperMethods)
      extend(SingletonMethodAdded)
    end

    method_name = method_name.to_sym
    cached_class_methods[method_name] = nil
    if class_method_defined?(method_name)
      (class << self; self; end).module_eval do
        if proxy.opts[:counter]
          define_method "increment_#{method_name}", proxy.counter_method(:increment)
          define_method "decrement_#{method_name}", proxy.counter_method(:decrement)
        end

        # Replace class method.
        alias_method proxy.method_name_without_caching, method_name
        define_method method_name, proxy.method_with_caching
      end
    end
    cached_class_methods[method_name] = proxy
  end

  def class_method_defined?(method_name)
    method(method_name)
    true
  rescue NameError
    false
  end

  def self.default_cache
    @default_cache ||= LocalCache.new
  end

  def get_ancestors
    if self.respond_to?(:ancestors)
      self.ancestors
    else
      self.class.ancestors
    end
  end

  def cached_instance_methods(method_name = nil)
    if method_name
      method_name = method_name.to_sym
      get_ancestors.each do |klass|
        next unless klass.kind_of?(MethodCache)
        proxy = klass.cached_instance_methods[method_name]
        return proxy if proxy
      end
      nil
    else
      @cached_instance_methods ||= {}
    end
  end

  def cached_class_methods(method_name = nil)
    if method_name
      method_name = method_name.to_sym
      get_ancestors.each do |klass|
        next unless klass.kind_of?(MethodCache)
        proxy = klass.cached_class_methods[method_name]
        return proxy if proxy
      end
      nil
    else
      @cached_class_methods ||= {}
    end
  end

  def cached_module_methods(method_name = nil)
    if method_name
      cached_module_methods[method_name.to_sym]
    else
      @cached_module_methods ||= {}
    end
  end

  def self.disable(value = true, &block)
    @disabled, old = true, @disabled
    yield
  ensure
    @disabled = old
  end

  def self.disabled?
    @disabled
  end

  module HelperMethods
    def invalidate_cached_method(method_name, *args, &block)
      cached_method(method_name, args).invalidate(&block)
    end

    def method_value_cached?(method_name, *args)
      cached_method(method_name, args).cached?
    end

    def update_cached_method(method_name, *args, &block)
      cached_method(method_name, args).update(&block)
    end

    def method_cached_at(method_name, *args)
      cached_method(method_name, args).cached_at
    end

    def method_expires_at(method_name, *args)
      cached_method(method_name, args).expires_at
    end

    def without_method_cache(&block)
      MethodCache.disable(&block)
    end

  private

    def cached_method(method_name, args)
      if self.kind_of?(Class) or self.kind_of?(Module)
        proxy = cached_class_methods(method_name)
      else
        proxy = self.class.send(:cached_instance_methods, method_name)
      end
      raise "method '#{method_name}' not cached" unless proxy
      proxy.bind(self, args)
    end
  end

  module MethodAdded
    def method_added(method_name)
      if proxy = cached_instance_methods(method_name)
        cache_method(method_name, proxy)
      end
      super
    end
  end

  module SingletonMethodAdded
    def singleton_method_added(method_name)
      if proxy = cached_class_methods(method_name)
        cache_class_method(method_name, proxy)
      end
      super
    end
  end

  module ModuleAdded
    def extended(mod)
      mod.extend(MethodCache)
      cached_module_methods.each do |method_name, proxy|
        mod.cache_class_method(method_name, proxy)
      end
    end

    def included(mod)
      mod.extend(MethodCache)
      cached_module_methods.each do |method_name, proxy|
        mod.cache_method(method_name, proxy)
      end
    end
  end
end
end
