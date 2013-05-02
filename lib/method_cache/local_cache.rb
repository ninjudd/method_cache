module MethodCache
  class LocalCache
    def initialize
      clear
    end

    def clear
      @data       = {}
      @cached_at  = {}
      @expires_at = {}
    end

    def get(key)
      if expires = expires_at(key)
        delete(key) if expires <= Time.now
      end
      @data[key]
    end
    alias [] get

    def count(key)
      get(key).to_i
    end

    def set(key, value, expiry)
      @cached_at[key]  = Time.now
      @expires_at[key] = expiry_to_time(expiry)
      @data[key]       = value
    end
    alias []= set
    alias write set

    def delete(key)
      @cached_at.delete(key)
      @expires_at.delete(key)
      @data.delete(key)
    end

    def incr(key, amount)
      @data[key] = count(key) + amount
    end

    def decr(key, amount)
      incr(key, -amount)
    end

    def expires_at(key)
      @expires_at[key]
    end

    def cached_at(key)
      @cached_at[key]
    end

  private

    def expiry_to_time(expiry)
      expiry = Time.at(expiry) if expiry > 60*60*24*30
      if expiry.kind_of?(Time)
        expiry
      else
        expiry = expiry.to_i
        expiry == 0 ? nil : Time.now + expiry
      end
    end
  end
end
