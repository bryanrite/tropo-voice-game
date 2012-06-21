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
  haml :game
end

post '/start_game.json' do
  v = Tropo::Generator.parse request.env["rack.input"].read
  game = Game[v[:session][:parameters][:game]]
  session[:game_id] = game.id
  session[:guesses] = 0

  t = Tropo::Generator.new
  t.call(to: "#{game.phone_number}")
  t.say(value: "Welcome to the voice enabled hang man game.  You have #{settings.number_of_guesses} chances to solve the puzzle.  Please say one letter at a time.")
  t.ask(
    name: "guess",
    attempts: 3,
    say:[
          { value: "Sorry. I didn't hear anything.", event: 'timeout' },
          { value: "Sorry. I didn't understand that." , event: 'nomatch:1 nomatch:2 nomatch:3'},
          { value: "You have #{settings.number_of_guesses - game.guesses.count} guesses left. What is your next guess?" }
        ],
    choices: { value: "a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z" }
  )
  t.on event: 'continue', next: '/next_guess.json'
  t.on event: 'incomplete', next: '/hangup.json'
  t.response
end

post '/hangup.json' do
  t = Tropo::Generator.new
  t.say(value: "I couldn't understand you.  Good bye.")
  t.response
end

post '/next_guess.json' do
  # Get the previous questions response and save it.
  v = Tropo::Generator.parse request.env["rack.input"].read
  game = Game[session[:game_id]]
  response = v[:result][:actions][:guess][:value] rescue nil
  # survey.questions[session[:question]-1].update(response: response) unless response.nil?

  logger.info "Received guess: #{response} from player: #{game.phone_number}"

  # Ask for the next guess.
  t = Tropo::Generator.new
  t.say(value: "Nice guess. I guess.")
  t.response
end

private

  def clean_number(phone_number)
    return "+#{phone_number.gsub(/\D/,'')}"
  end
