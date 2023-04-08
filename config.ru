require_relative "app"

configure do
  set :server, :puma
end

run Sinatra::Application
