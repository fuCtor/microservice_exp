require 'bundler'
Bundler.require

require_relative './lib/microservice/service'
require_relative './lib/microservice/router'
require_relative './lib/microservice/service_proxy'

thrs = []

ROOT_ROUTER = Microservice::Router.new
MID_ROUTER = Microservice::Router.new(ROOT_ROUTER.url, 'mid')

class Echo
  include Microservice::Service
  register MID_ROUTER.url

  def sum(a,b)
    a + b
  end

  def ping
    'pong'
  end
end

echo_service = Echo.new

thrs << echo_service.run
thrs << ROOT_ROUTER.run
thrs << MID_ROUTER.run


thrs << Thread.new do
  echo = Microservice::ServiceProxy.new(ROOT_ROUTER.url, 'mid.echo')

  500.times do
    puts echo.ping
    puts echo.sum 1, 2
    sleep 0.1
  end

end

thrs.each { |thr| thr.join }






