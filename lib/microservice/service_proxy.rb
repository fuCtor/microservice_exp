require_relative '../microservice'

module Microservice
  class ServiceProxy
    attr_reader :name
    def initialize(url, service)
      @dealer = Microservice.context.socket(:DEALER)
      @dealer.identity =  [service.split('.').last, 'proxy', SecureRandom.hex].join('-')
      puts @dealer.connect(url)
      @name = service
      @methods_loaded = nil
    end

    def perform(message)
      req = {
          to: name,
          payload: message
      }
      @dealer.send MessagePack.pack(req)
      payload = MessagePack.unpack(@dealer.recv)['payload']

      if payload.is_a?(Hash) && payload.key?('_exception')
        fail payload['_exception']
      end
      payload
    end

    def call(method, *args)
      perform _method: method, _args: args
    end

    def method_missing(name, *args, &block)
      return super if @methods_loaded
      @methods_loaded = self.call('_methods')
      @methods_loaded.each do |method|
        self.class.send :define_method, method do |*args|
          self.call method, *args
        end
      end
      self.send name, *args
    end
  end
end
