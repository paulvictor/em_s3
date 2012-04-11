class S3Agent < EM::Queue
  include Singleton
  # Refer to http://eventmachine.rubyforge.org/EventMachine/Queue.html for interface details
  # This agent class solves the following problem
  # RMW in S3.
  # It has a pool of (s3) bucket, object names which are right now being processed.
  # When a new request comes, we check if its right now sent out to S3.
  # If yes, add it to the queue and add a pop request which will do the same thing again.
  # If no, process it
  # If a new read request for the same (object, bucket) comes, it will cycle through the push/pop cycle.
  def initialize
    @public_key = nil
    @private_key = nil
    @obj_pools = {}
  end

  def set_keys(public_key, private_key)
    @public_key ||= public_key
    @private_key ||= private_key
    self
  end

  # Called from clients if due to some reason, they skip over the write part
  # @param [String] bucket
  #   The name of the bucket
  # @param [String] object
  #   The name of the object's key
  # @return [true]
  def revoke_service(bucket, object)
    @obj_pools.delete("#{bucket}:#{object}")
    true
  end

  # Requests any of :get or :put from S3.
  # If the object is not being processed now, service it immediately.
  # If not, push it in a queue and wait for the reactor to take it through.
  # @param [Symbol] method
  #   The HTTP method in lower case. Either :get or :put
  # @param [String] bucket
  #   The name of the bucket
  # @param [String] object
  #   The name of the object's key
  # @param [String] value
  #   The object's value
  # @return [true]
  def request_service(method, bucket, object, value = nil, &blk)
    # Allow `put`s to go through.
    # For `get`s, check if the object is not in use and only then, allow to pass though
    if (!@obj_pools["#{bucket}:#{object}"]) || (method == :put)
      # Some client is using the agent.
      @obj_pools["#{bucket}:#{object}"] = true
      s3i = S3Interface.new(@public_key, @private_key)
      s3i.callback{|resp, status|
        # Unblock the other client only if this is a write
        revoke_service(bucket, object) if method == :put
        yield resp, status if block_given?
      }
      method == :get ? s3i.get_object(bucket, object) : s3i.put_object(bucket, object, value)
    else
      push({:bucket => bucket, :object => object, :value => value})
      pop{|request|
        request_service(request[:bucket], request[:object], request[:value]){|resp, status|
          yield resp, status if block_given?
        }
      }
    end
    true
  end
end
