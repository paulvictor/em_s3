class S3Agent
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
    setup
  end

  def setup
    @obj_pools = {}
  end

  def set_keys(public_key, private_key)
    @public_key ||= public_key
    @private_key ||= private_key
    self
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
  def request_service(method, *args)
    setup
    self.send(method.to_sym, *args)
  end

  def method_missing(method, *args)
    params = args[0]
    q = (@obj_pools["#{params[:bucket]}:#{params[:object]}"] ||= EM::Queue.new)
    q.push({:method => method, :params => params})
    q.pop{|request|
      s3i = S3Interface.new(@public_key, @private_key)
      s3i.send(method, params)
    }
  end
end
