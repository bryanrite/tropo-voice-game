class Game < Sequel::Model
  plugin :serialization, :json, :board
  plugin :validation_helpers
  self.raise_on_typecast_failure = false

  def validate
    super
    validates_presence [:phone_number, :board]
    validates_type Array, [:board]
  end

  def won?
    false
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

end
