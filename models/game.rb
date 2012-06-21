class Game < Sequel::Model
  plugin :serialization, :json, :guesses
  plugin :validation_helpers
  self.raise_on_typecast_failure = false

  def validate
    super
    validates_presence [:phone_number, :word]
    validates_type Array, [:guesses]
    validates_min_length 4, [:word]
  end
end
