class Game < Sequel::Model
  plugin :serialization, :json, :board
  plugin :validation_helpers
  self.raise_on_typecast_failure = false

  @@wins = [0b111_000_000,
            0b000_111_000,
            0b000_000_111,
            0b100_100_100,
            0b010_010_010,
            0b001_001_001,
            0b100_010_001,
            0b001_010_100]

  def validate
    super
    validates_presence [:phone_number, :board]
    validates_type Array, [:board]
  end

  def won? player
    # bit-map based tic tac toe winner algorithm.
    @@wins.any? do |win|
      moves = board.inject(0) { |accum, position| (accum * 2) + ((position == player) ? 1 : 0) }
      (win ^ moves) & win == 0
    end
  end

  def over?
    board.count{ |x| x =~ /\d/}.zero?
  end

  def make_move move, player
    board[move-1] = player
    save
  end

  def valid_move?(move)
    (1..9).include?(move) && board[move-1] =~ /\d/
  end

  def make_computers_choice
    choice = board.select{ |x| x =~ /\d/}.sample.to_i
    make_move choice, 'O'
    choice
  end

end
