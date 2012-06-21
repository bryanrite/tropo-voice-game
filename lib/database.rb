configure :development do
  set :database, "sqlite://db/voice_game_#{Sinatra::Base.environment}.db"
end
