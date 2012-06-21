require 'sinatra'
require 'sinatra/json'
require 'sinatra/sequel'
require "sinatra/config_file"
require 'tropo-webapi-ruby'
require 'httparty'
require 'haml'

config_file 'config/config.yml'
use Rack::Session::Pool

# Autoload Directories
autoload = %w(lib models)
autoload.each do |directory|
  Dir[File.dirname(__FILE__) + "/#{directory}/*.rb"].each { |file| require file }
end

get '/' do
  haml :index
end

post '/start_game.json' do
  v = Tropo::Generator.parse request.env["rack.input"].read
  game = Game[v[:session][:parameters][:game]]
  session[:game_id] = game.id

  t = Tropo::Generator.new
  t.call(to: "+#{game.phone_number}")
  t.say(value: 'Starting game.')
  t.response
end