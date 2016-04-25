require_relative '../microservice'

module Microservice
  class Router
    attr_reader :peer, :dealer, :router, :identity

    def initialize(peer = nil, identity = nil)
      @identity = identity || 'root'
      @peer = peer
    end

    def to_s
      url
    end

    def root?
      !dealer
    end

    def url
      "ipc://#{identity}.router"
    end

    def run
      Thread.new do

        poller = ZMQ::Poller.new
        poller.register_readable(dealer) unless root?
        poller.register_readable(router)

        puts 'Start router'

        loop do
          poller.poll(0)

          poller.readables.each do |socket|

            data = nil
            id = nil
            from = nil
            message = nil

            case socket
              when dealer
                data = socket.recv
                id = identity
                message = MessagePack.unpack data
                from =  message['from']
              when router
                id =  socket.recv
                data =  socket.recv
                message = MessagePack.unpack data
                from = ([id.to_s] + message['from'].to_s.split('.')).join('.') if id
            end

            left, (next_step, *_) = message['to'].split('.').slice_when {|step| step == id } .to_a

            message['from'] = from
            data = MessagePack.pack message

            #puts "[ROUTER #{identity}] from #{message['from']} to #{message['to']}"

            if next_step || root?
              router.sendm root? ? left.first : next_step
              router.send data
            else
              dealer.send data
            end
          end
        end
      end
    end

    def dealer
      return @dealer if defined? @dealer
      if peer
        @dealer = Microservice.context.socket(:DEALER)
        @dealer.identity = self.identity
        @dealer.connect(peer)
      else
        @dealer = nil
      end
    end

    def router
      @router ||= Microservice.context.bind(:ROUTER, url)
    end

  end
end