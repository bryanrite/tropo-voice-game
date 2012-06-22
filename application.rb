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
  game = Game.create(phone_number: phone, board: ("1".."9").to_a)

  logger.info "Starting a new game with phone number: #{phone}"

  # Make the outbound call and start the game.
  HTTParty.get "http://api.tropo.com/1.0/sessions?action=create&token=#{settings.tropo_app_token}&game=#{game.id}"

  redirect "/game/#{game.id}"
end

get '/game/:id' do
  @game = Game[params[:id]]
  error(404, "Couldn't find game") if @game.nil?

  if request.xhr?
    haml :board, layout: false
  else
    haml :game
  end
end

post '/start_game.json' do
  v = Tropo::Generator.parse request.env["rack.input"].read
  game = Game[v[:session][:parameters][:game]]
  session[:game_id] = game.id

  t = Tropo::Generator.new
  t.call(to: "#{game.phone_number}")
  t.say(value: "Welcome to the voice enabled tic tac toe game. Choose a square by saying its number. You will be playing against #{%w(ruby beth allison susan veronica kate).sample}", voice: 'Simon')
  t.say(value: "Hello. Nice to meet you.", voice: 'Veronica')
  t.say(value: "You get to go first.", voice: 'Simon')
  ask_for_move(t, game)
end

post '/hangup.json' do
  t = Tropo::Generator.new
  t.say(value: "I couldn't understand you.  Good bye.", voice: 'Simon')
  t.response
end

post '/next_guess.json' do
  v = Tropo::Generator.parse request.env["rack.input"].read
  game = Game[session[:game_id]]
  move = v[:result][:actions][:move][:value].to_i rescue nil

  logger.info "Received move: #{move} from player: #{game.phone_number} for the board: #{game.board}"

  t = Tropo::Generator.new

  # Your move.
  if game.valid_move?(move)
    game.make_move move, 'X'
  else
    t.say(value: "Sorry, that is not a valid square.", voice: 'Simon')
    return ask_for_move t, game
  end

  # Check win conditions
  if game.won? 'X'
    t.say(value: "#{%w(shucks darn drat humbug).sample}, you win. I'll get you next time.", voice: 'Veronica')
    t.say(value: "Good moves. Congratulations.", voice: 'Simon')
    return t.response
  elsif game.over?
    return game_over_response t
  end

  # Computers turn.
  computers_choice = game.make_computers_choice
  t.say(value: "I choose #{computers_choice}", voice: 'Veronica')

  logger.info "Computer chooses: #{computers_choice} for the board: #{game.board}"

  # Check win conditions again
  if game.won? 'O'
    t.say(value: "I win.  Better luck next time.", voice: 'Veronica')
    t.response
  elsif game.over?
    game_over_response t
  else
    ask_for_move t, game
  end
end

private

  def ask_for_move(tropo, game)
  tropo.ask name: "move",
      attempts: 3,
      voice: 'Simon',
      say:[
            { value: "Sorry. I didn't hear anything.", event: 'timeout' },
            { value: "Sorry. I didn't understand that." , event: 'nomatch:1 nomatch:2 nomatch:3'},
            { value: "Which square would you like." }
          ],
      choices: { value: "[1 DIGIT]" }

    tropo.on event: 'continue', next: '/next_guess.json'
    tropo.on event: 'incomplete', next: '/hangup.json'
    tropo.response
  end

  def game_over_response tropo
    tropo.say(value: "Looks like nobody wins this game.  Isn't Tic Tac Toe fun.", voice: 'Simon')
    tropo.say(value: "what a #{%w(great good boring exciting).sample} game. till next time.", voice: 'Veronica')
    tropo.response
  end

  def clean_number(phone_number)
    return "+#{phone_number.gsub(/\D/,'')}"
  end
