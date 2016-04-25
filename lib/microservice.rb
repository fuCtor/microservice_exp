module Microservice
  def self.context
    @context ||= ZMQ::Context.new
  end
end