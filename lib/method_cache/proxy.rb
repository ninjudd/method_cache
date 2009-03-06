module MethodCache
  class Proxy
    attr_reader :method_name

    def initialize(method_name, opts)
      @method_name = method_name
      @opts        = opts
    end

    def invalidate(*args)
      key = cache_key(*args)

      if block_given?
        # Only invalidate if the block returns true.
        value = cache[key]
        return if value and not yield(value)
      end
      cache.delete(key)
    end

    def cached?(*args)
      key = cache_key(*args)
      not cache[key].nil?
    end
    
    def update(*args)
      key   = cache_key(*args)
      value = block_given? ? yield(cache[key]) : args.first.send(:method_name_without_caching, *args)
      write_to_cache(key, value)
      value
    end

    def value(target, *args)
      key   = cache_key(target, *args)
      value = cache[key]
      value = nil if value and validation and not validation.call(value)

      if value.nil?
        value = target.send(method_name_without_caching, *args)
        write_to_cache(key, value)
      end
          
      value = nil if value == NULL
      if clone? and value
        value.clone
      else
        value
      end
    end

    NULL = 'NULL'
    def method_with_caching
      proxy = self # Need access to the proxy in the closure.

      lambda do |*args|
        proxy.value(self, *args)
      end
    end

    def method_name_without_caching
      "#{method_name}_without_caching"
    end

    def cache
      if @cache.nil?
        @cache = @opts[:cache] || MethodCache.default_cache
        @cache = MemCache.pool[@cache] if @cache.kind_of?(Symbol)
      end
      @cache
    end

    def expiry
      @opts[:expiry]
    end

    def validation
      @opts[:validation]
    end

    def clone?
      !!@opts[:clone]
    end

    def write_to_cache(key, value)
      if cache.kind_of?(Hash)
        raise 'expiry not permitted when cache is a Hash' if expiry
        cache[key] = value
      else
        expiry = expiry.kind_of?(Proc) ? expiry.call(value) : expiry
        value  = value.nil? ? NULL : value
        cache.set(key, value, expiry)
      end
    end

    def cache_key(target, *args)
      args.unshift(method_name)
      args.unshift(target)

      arg_string = args.collect do |arg|
        case arg
        when Class
          class_key(arg)
        when defined?(ActiveRecord::Base) && ActiveRecord::Base
          "#{class_key(arg.class)}-#{arg.id}"
        when Symbol, String, Numeric
          arg.to_s
        else
          hash = arg.respond_to?(:string_hash) ? arg.string_hash : arg.hash
          "#{class_key(arg.class)}-#{hash}"
        end
      end.join(',')
      "m:#{arg_string}"
    end

    def class_key(klass)
      key = klass.respond_to?(:version) ? "#{klass.name}_#{klass.version}" : klass.name
      if MethodCache.partition_environments and RAILS_ENV != 'production'
        key << "_#{RAILS_ENV}"
      end
      key
    end
  end
end
