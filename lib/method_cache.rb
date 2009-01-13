#require 'memcache'
require File.dirname(__FILE__) + '/../../memcache/lib/memcache'

module MethodCache
  VERSION = '0.5.1'

  def cache_method(method_name, opts = {})
    if self.class == Class
      if cached_methods.empty?
        include(InvalidationMethods)
        extend(MethodAdded)
      end
      
      method_name = method_name.to_sym
      cached_methods[method_name] = nil
      begin
        opts[:cache]  ||= :default
        opts[:method] ||= method_with_caching(method_name, opts)
        
        alias_method "#{method_name}_without_caching", method_name
        define_method method_name, &opts[:method]
      rescue NameError => e
        # The method has not been defined yet. We will alias it in method_added.
      end
      cached_methods[method_name] = opts
    elsif self.class == Module
      # We will alias all methods when the module is mixed-in.
      extend(ModuleAdded) if cached_module_methods.empty?
      cached_module_methods[method_name.to_sym] = opts
    end
  end

  def cache_class_method(method_name, opts = {})
    if cached_class_methods.empty?
      extend(InvalidationMethods)
      extend(SingletonMethodAdded)
    end

    method_name = method_name.to_sym
    cached_class_methods[method_name] = nil
    begin
      opts[:cache]  ||= :default
      opts[:method] ||= method_with_caching(method_name, opts)

      (class << self; self; end).module_eval do
        alias_method "#{method_name}_without_caching", method_name
        define_method method_name, &opts[:method]
      end
    rescue NameError => e
      # The method has not been defined yet. We will alias it in singleton_method_added.
    end
    cached_class_methods[method_name] = opts
  end

private
  
  NULL = 'NULL'
  def method_with_caching(method_name, opts)     
    lambda do |*args|
      key   = method_cache_key(method_name, *args)
      cache = MemCache.pool[opts[:cache]]
      value = cache.get(key)
      if value.nil?
        value  = self.send("#{method_name}_without_caching", *args)
        expiry = opts[:expiry].kind_of?(Proc) ? opts[:expiry].call(value) : opts[:expiry]
        value  = value.nil? ? NULL : value
        cache.set(key, value, expiry)
      end
      
      value = nil if value == NULL
      if opts[:clone] and value
        value.clone
      else
        value
      end
    end
  end

  def cached_methods(method_name = nil)
    if method_name
      cached_methods[method_name.to_sym]
    else
      @cached_methods ||= {}
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
    def invalidate_cached_method(method_name, *args)
      opts = cached_method_opts(method_name)
      key  = method_cache_key(method_name, *args)
      MemCache.pool[opts[:cache]].delete(key)
    end

    def method_value_cached?(method_name, *args)
      opts = cached_method_opts(method_name)
      key  = method_cache_key(method_name, *args)
      not MemCache.pool[opts[:cache]].get(key).nil?
    end

  private

    def cached_method_opts(method_name)
      if self.kind_of?(Class)
        opts = cached_class_methods(method_name)
      else
        opts = self.class.send(:cached_methods, method_name)
      end
      raise "method '#{method_name}' not cached" unless opts
      opts
    end

    def method_cache_key(*args)
      args.unshift(self)

      arg_string = args.collect do |arg|
        case arg
        when Class
          arg.respond_to?(:version) ? "#{arg.name}_#{arg.version}" : arg.name
        when defined?(ActiveRecord::Base) && ActiveRecord::Base
          "#{arg.class}-#{arg.id}"
        when Symbol, String, Numeric
          arg.to_s
        else
          hash = arg.respond_to?(:string_hash) ? arg.string_hash : arg.hash
          "#{arg.class}-#{hash}"
        end
      end.join(',')
      "m:#{arg_string}"
    end
  end

  module MethodAdded
    def method_added(method_name)
      if opts = cached_methods(method_name)
        cache_method(method_name, opts)
      end
      super
    end
  end

  module SingletonMethodAdded
    def singleton_method_added(method_name)
      if opts = cached_class_methods(method_name)
        cache_class_method(method_name, opts)
      end
      super
    end
  end

  module ModuleAdded
    def extended(mod)
      cached_module_methods.each do |method_name, opts|
        mod.cache_class_method(method_name, opts)
      end
    end

    def included(mod)
      cached_module_methods.each do |method_name, opts|
        mod.cache_method(method_name, opts)
      end
    end
  end
end
