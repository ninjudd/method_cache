require 'digest/sha1'

class Object
  def metaclass; class << self; self; end; end
end

module MethodCache
  class Proxy
    attr_reader :method_name, :opts, :args, :target
    NULL = 'NULL'

    def initialize(method_name, opts)
      opts[:cache] ||= :counters if opts[:counter]
      @method_name = method_name
      @opts        = opts      
    end

    def bind(target, args)
      self.clone.bind!(target, args)
    end

    def bind!(target, args)
      @target = target
      @args   = args
      @key    = nil
      self
    end

    def invalidate
      if block_given?
        # Only invalidate if the block returns true.
        value = cache[key]
        return if value and not yield(value)
      end
      cache.delete(key)
    end

    def context
      opts[:context]
    end

    def version
      dynamic_opt(:version)
    end

    def cached?
      not cache[key].nil?
    end

    def update
      if block_given?
        old_value = read_from_cache(key)
        return if old_value.nil?

        old_value = nil if old_value == NULL
        new_value = yield(old_value)
        return if old_value == new_value
      else
        new_value = target.send(method_name_without_caching, *args)
      end
      write_to_cache(key, new_value)
      new_value
    end

    def value
      value = read_from_cache(key)
      value = nil unless valid?(:load, value)

      if value.nil?
        value = target.send(method_name_without_caching, *args)
        raise "non-integer value returned by counter method" if opts[:counter] and not value.kind_of?(Fixnum)
        write_to_cache(key, value) if valid?(:save, value)
      end

      if opts[:counter]
        value = [value, opts[:max]].min if opts[:max]
        value = [value, opts[:min]].max if opts[:min]
      end

      value = nil if value == NULL
      if clone? and value
        value.clone
      else
        value
      end
    end

    def method_with_caching
      proxy = self # Need access to the proxy in the closure.

      lambda do |*args|
        proxy.bind(self, args).value
      end
    end

    def counter_method(method_name)
      proxy = self # Need access to the proxy in the closure.

      lambda do |*args|
        if args.last.kind_of?(Hash) and args.last.keys == [:by]
          amount = args.last[:by]
          args.pop
        end
        proxy.bind(self, args).send(method_name, amount || 1)
      end
    end

    def method_name_without_caching
      @method_name_without_caching ||= begin
        base_name, punctuation = method_name.to_s.sub(/([?!=])$/, ''), $1
        "#{base_name}_without_caching#{punctuation}"
      end
    end

    def cache
      if @cache.nil?
        @cache = opts[:cache] || MethodCache.default_cache
        @cache = Memcache.pool[@cache] if @cache.kind_of?(Symbol)
        if not @cache.respond_to?(:[]) and @cache.respond_to?(:get)
          @cache.metaclass.module_eval do
            define_method :[] do |key|
              get(key)
            end
          end
        end
      end
      @cache
    end

    def local?
      cache.kind_of?(LocalCache) or cache.kind_of?(Hash)
    end

    def clone?
      !!opts[:clone]
    end

    def key
      if @key.nil?
        arg_string = ([method_name, target] + args).collect do |arg|
          object_key(arg)
        end.join('|')
        @key = ['m', version, arg_string].compact.join('|')
        @key = "m|#{Digest::SHA1.hexdigest(@key)}" if @key.length > 250
      end
      @key
    end

    def cached_at
      cache.cached_at(key) if cache.respond_to?(:cached_at)
    end

    def expires_at
      cache.expires_at(key) if cache.respond_to?(:expires_at)
    end

  private

    def expiry(value)
      value = dynamic_opt(:expiry, value).to_i
      if defined?(Memcache) and cache.kind_of?(Memcache)
        {:expiry => value}
      else
        value
      end
    end

    def valid?(type, value)
      name = "#{type}_validation".to_sym
      return true unless opts[name]
      return unless value

      dynamic_opt(name, value)
    end

    def dynamic_opt(name, value = nil)
      if opts[name].kind_of?(Proc)
        proc = opts[name]
        case proc.arity
        when 0 then target.instance_exec(&proc)
        when 1 then target.instance_exec(value, &proc)
        else
          meta = {
            :args       => args,
            :cached_at  => cached_at,
            :expires_at => expires_at,
          }
          target.instance_exec(value, meta, &proc)
        end
      else
        opts[name]
      end
    end

    def write_to_cache(key, value)
      unless opts[:counter]
        value = value.nil? ? NULL : value
      end
      if cache.kind_of?(Hash)
        raise 'expiry not permitted when cache is a Hash'        if opts[:expiry]
        raise 'counter cache not permitted when cache is a Hash' if opts[:counter]
        cache[key] = value
      elsif opts[:counter]
        cache.write(key, value.to_s, expiry(value))
      else
        cache.set(key, value, expiry(value))
      end
    end

    def read_from_cache(key)
      return if MethodCache.disabled?
      opts[:counter] ? cache.count(key) : cache[key]
    end

    def increment(amount)
      raise "cannot increment non-counter method" unless opts[:counter]
      cache.incr(key, amount)
    end

    def decrement(amount)
      raise "cannot decrement non-counter method" unless opts[:counter]
      cache.decr(key, amount)
    end

    def object_key(arg)
      return "#{class_key(arg.class)}-#{arg.string_hash}" if arg.respond_to?(:string_hash)

      case arg
      when NilClass      then 'nil'
      when TrueClass     then 'true'
      when FalseClass    then 'false'
      when Numeric       then arg.to_s
      when Symbol        then ":#{arg}"
      when String        then "'#{arg}'"
      when Class, Module then class_key(arg)
      when Hash
        '{' + arg.collect {|key, value| "#{object_key(key)}=#{object_key(value)}"}.sort.join(',') + '}'
      when Array
        '[' + arg.collect {|item| object_key(item)}.join(',') + ']'
      when defined?(ActiveRecord::Base) && ActiveRecord::Base
        "#{class_key(arg.class)}-#{arg.id}"
      else
        if arg.respond_to?(:method_cache_key)
          arg.method_cache_key
        else
          hash = local? ? arg.hash : Marshal.dump(arg).hash
          "#{class_key(arg.class)}-#{hash}"
        end
      end
    end

    def class_key(klass)
      klass.respond_to?(:version) ? "#{klass.name}_#{klass.version(context)}" : klass.name
    end
  end
end
