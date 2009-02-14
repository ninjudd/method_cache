#require 'memcache'
require File.dirname(__FILE__) + '/../../memcache/lib/memcache'

$:.unshift(File.dirname(__FILE__))
require 'method_cache/proxy'

module MethodCache
  VERSION = '0.6.0'

  def cache_method(method_name, opts = {})
    method_name = method_name.to_sym
    proxy = opts.kind_of?(Proxy) ? opts : Proxy.new(method_name, opts)
    
    if self.class == Class
      if cached_instance_methods.empty?
        include(InvalidationMethods)
        extend(MethodAdded)
      end
      
      cached_instance_methods[method_name] = nil
      begin
        # Replace instance method.
        alias_method proxy.method_name_without_caching, method_name
        define_method method_name, proxy.method_with_caching
      rescue NameError => e
        # The method has not been defined yet. We will alias it in method_added.
        # pp e, e.backtrace
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

    if cached_class_methods.empty?
      extend(InvalidationMethods)
      extend(SingletonMethodAdded)
    end

    method_name = method_name.to_sym
    cached_class_methods[method_name] = nil
    begin
      # Replace class method.
      (class << self; self; end).module_eval do
        alias_method proxy.method_name_without_caching, method_name
        define_method method_name, proxy.method_with_caching
      end
    rescue NameError => e
      # The method has not been defined yet. We will alias it in singleton_method_added.
      # pp e, e.backtrace
    end
    cached_class_methods[method_name] = proxy
  end

  def self.default_cache
    @default_cache ||= {}
  end

  class << self
    attr_accessor :partition_environments
  end

private
  
  def cached_instance_methods(method_name = nil)
    if method_name
      cached_instance_methods[method_name.to_sym]
    else
      @cached_instance_methods ||= {}
    end
  end

  def cached_class_methods(method_name = nil)
    if method_name
      cached_class_methods[method_name.to_sym]
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

  module InvalidationMethods
   def invalidate_cached_method(method_name, *args, &block)
      cached_method(method_name).invalidate(self, *args, &block)
    end

    def method_value_cached?(method_name, *args)
      cached_method(method_name).cached?(self, *args)
    end
    
    def update_cached_method(method_name, *args, &block)
      cached_method(method_name).update(self, *args, &block)
    end

  private

    def cached_method(method_name)
      if self.kind_of?(Class)
        proxy = cached_class_methods(method_name)
      else
        proxy = self.class.send(:cached_instance_methods, method_name)
      end
      raise "method '#{method_name}' not cached" unless proxy
      proxy
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
