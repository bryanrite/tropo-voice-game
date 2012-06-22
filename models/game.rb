class Game < Sequel::Model
  plugin :serialization, :json, :guesses
  plugin :validation_helpers
  self.raise_on_typecast_failure = false

  def current_puzzle
    build_current_puzzle if @current_puzzle.nil?
    @current_puzzle
  end

  def validate
    super
    validates_presence [:phone_number, :word]
    validates_type Array, [:guesses]
    validates_min_length 4, [:word]
  end

  def solved?
    current_puzzle == word
  end

  def over?
    guesses.count > 10
  end

  def build_current_puzzle
    @current_puzzle = ''
    word.each_char do |c|
      @current_puzzle += guesses.include?(c) ? c : '_'
    end
  end

end
