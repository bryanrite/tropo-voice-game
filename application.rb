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
  game = Game.create(word: word.downcase, guesses: %w(), phone_number: phone)

  logger.info "Starting a game with the word: #{word} to phone number: #{phone}"

  # Make the outbound call and start the game.
  HTTParty.get "http://api.tropo.com/1.0/sessions?action=create&token=#{settings.tropo_app_token}&game=#{game.id}"

  redirect "/hang_man/#{game.id}"
end

get '/hang_man/:id' do
  @game = Game[params[:id]]
  error(404, "Couldn't find game") if @game.nil?
  haml :game
end

post '/start_game.json' do
  v = Tropo::Generator.parse request.env["rack.input"].read
  game = Game[v[:session][:parameters][:game]]
  session[:game_id] = game.id

  t = Tropo::Generator.new
  t.call(to: "#{game.phone_number}")
  t.say(value: "Welcome to the voice enabled hang man game.  You have #{settings.number_of_guesses} chances to solve the puzzle.  Please say one letter at a time.")
  ask_for_guess(t, game)
end

post '/hangup.json' do
  t = Tropo::Generator.new
  t.say(value: "I couldn't understand you.  Good bye.")
  t.response
end

post '/next_guess.json' do
  # Get the previous guess response and save it.
  v = Tropo::Generator.parse request.env["rack.input"].read
  game = Game[session[:game_id]]
  response = v[:result][:actions][:guess][:value] rescue nil

  game.guesses << response unless response.nil? || response.empty?
  game.save

  logger.info "Received guess: #{response} from player: #{game.phone_number}"

  # What to do now.
  t = Tropo::Generator.new
  if game.solved?
    t.say "You win.  You guessed the word, #{game.word}, in #{game.guesses.count} guesses."
  elsif game.over?
    t.say "You are out of guesses. Sorry, you lost."
  else
    ask_for_guess t, game
  end
end

private

  def ask_for_guess(tropo, game)
  tropo.ask name: "guess",
      attempts: 3,
      mode: 'speech',
      say:[
            { value: "Sorry. I didn't hear anything.", event: 'timeout' },
            { value: "Sorry. I didn't understand that." , event: 'nomatch:1 nomatch:2 nomatch:3'},
            { value: "You have #{settings.number_of_guesses - game.guesses.count} guesses left. What is your next guess?" }
          ],
      choices: { value: "a(eh, a, alpha), b(b, bee, bea, bravo), c(c, cee, sea, charlie), d(d, dee, delta), e(e, echo), f(f, ef, foxtrot), g(g, gee, golf), h(h, hotel), i(i, eye, india), j(j, jay, juliet), k(k, cay, kay, kilo), l(l, elle, lima), m(m, em, mike), n(n, enn, november), o(o, oh, ohh, oscar), p(p, pee, papa), q(q, queue, quebec), r(r, arr, romeo), s(s, sierra), t(t, tee, tea, tango), u(u, you, yew, uniform), v(v, vee, victor), w(w, whiskey), x(x, xray), y(y, why, yankee), z(z, zee, zulu)" }

    tropo.on event: 'continue', next: '/next_guess.json'
    tropo.on event: 'incomplete', next: '/hangup.json'
    tropo.response
  end

  def clean_number(phone_number)
    return "+#{phone_number.gsub(/\D/,'')}"
  end
