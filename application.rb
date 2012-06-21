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

post '/start_game' do
  phone = clean_number params[:phone]
  word = WORD_LIST.sample
  game = Game.create(word: word, guesses: %w(), phone_number: phone)

  logger.info "Starting a game with the word: #{word} to phone number: #{phone}"

  # Make the outbound call and start the game.
  HTTParty.get "http://api.tropo.com/1.0/sessions?action=create&token=#{settings.tropo_app_token}&game=#{game.id}"

  redirect "/hang_man/#{game.id}"
end

get '/hang_man/:id' do
  puts params[:id]
  haml :game
end

post '/start_game.json' do
  v = Tropo::Generator.parse request.env["rack.input"].read
  game = Game[v[:session][:parameters][:game]]
  session[:game_id] = game.id
  session[:guesses] = 0

  t = Tropo::Generator.new
  t.call(to: "#{game.phone_number}")
  t.say(value: 'Starting game.')
  t.response
end

private
  def clean_number(phone_number)
    return "+#{phone_number.gsub(/\D/,'')}"
  end
