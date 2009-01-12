module MethodCache
  VERSION = '0.5.0'

  def self.extended(mod)
    mod.send(:extend,  self::ClassMethods)
    mod.send(:include, self::InstanceMethods)
  end

  def self.included(mod)
    mod.send(:extend,  self::ClassMethods)
    mod.send(:include, self::InstanceMethods)
  end

  def self.cache(name = nil)
    if name
      cache[name.to_sym]
    else
      @cache_pool ||= { :default => MemCacheMock.new }
    end
  end

  module ClassMethods
    def method_added(method_name)
      if opts = cached_methods(method_name)
        cache_method(method_name, opts)
      end
      super
    end

    def singleton_method_added(method_name)
      if opts = cached_class_methods(method_name)
        cache_class_method(method_name, opts)
      end
      super      
    end
    
    def cache_method(method_name, opts = {})
      method_name = method_name.to_sym
      cached_methods[method_name] = nil
      begin
        opts[:cache]  ||= :default
        opts[:method] ||= method_with_caching(method_name, opts)

        alias_method "#{method_name}_without_caching", method_name
        define_method method_name, &opts[:method]
      rescue NameError => e
        # The method has not been defined yet. We will cache it in method_added.
      end
      cached_methods[method_name] = opts
    end

    def cache_class_method(method_name, opts = {})
      # We need invalidate_cached_method.
      self.extend(InstanceMethods) if cached_class_methods.empty?

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
        # The method has not been defined yet. We will cache it in method_added.
      end
      cached_class_methods[method_name] = opts
    end
        
  private
    
    NULL = 'NULL'
    def method_with_caching(method_name, opts)     
      lambda do |*args|
        key   = cached_key(method_name, *args)
        cache = MethodCache.cache(opts[:cache])
        value = cache.get(key)
        if value.nil?
          value = self.send("#{method_name}_without_caching", *args)
          expiry = opts[:expiry].kind_of?(Proc) ? opts[:expiry].call(value) : opts[:expiry]
          cache.set(key, value.nil? ? NULL : value, expiry)
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
  end

  module InstanceMethods
    def invalidate_cached_method(method_name, *args)
      if self.kind_of?(Class)
        opts = cached_class_methods(method_name)
      else
        opts = self.class.send(:cached_methods, method_name)
      end

      raise "#{method_name} not cached; cannot invalidate" unless opts
      key = cached_key(method_name, *args)
      MethodCache.cache(opts[:cache]).delete(key)
      nil
    end

  private

    def cached_key(*args)
      args.unshift(self)

      arg_string = args.collect do |arg|
        case arg
        when Class
          arg.respond_to?(:version) ? "#{arg}_#{arg.version}" : arg.to_s
        when ActiveRecord::Base
          arg.id.to_s
        when Symbol, String, Numeric
          arg.to_s
        else
          "#{arg.class}-#{arg.hash}"
        end
      end.join(',')
      "m:#{arg_string}"
    end
  end
end
