require_relative '../microservice'



module Microservice
  module Service
    def self.included(base)
      base.extend ClassMethods
    end

    def read
      return unless dealer
      message = dealer.recv

      req = MessagePack.unpack(message)
      payload = req['payload']

      result =
          case payload['_method']
            when '_methods'
              self.class.rpc_methods
            when nil
              perform(payload)
            when *self.class.rpc_methods
              begin
                self.send payload['_method'], *payload['_args']
              rescue ArgumentError => e
                { _exception: e.message }
              end
            else
              { _exception: 'Method missing' }
          end

      rep = {
          to: req['from'],
          payload: result.nil? ? {} : result
      }

      dealer.send MessagePack.pack(rep)
    end

    def perform

    end

    def dealer
      return @dealer if defined? @dealer
      if self.class.router
        router = self.class.router
        @dealer = Microservice.context.socket(:DEALER)
        @dealer.identity = self.class.identity
        @dealer.connect(router.to_s)
      else
        @dealer = nil
      end
    end

    def run
      Thread.new do
        loop { read }
      end
    end

    module ClassMethods
      def register(router, identity = nil)
        @identity = (identity || name.downcase).to_s
        @router = router

      end

      def router
        @router
      end

      def identity
        @identity
      end

      def rpc_methods
        (self.instance_methods - Object.instance_methods - Microservice::Service.instance_methods).map(&:to_s)
      end
    end
  end
end