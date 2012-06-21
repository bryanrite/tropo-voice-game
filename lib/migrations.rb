migration "create the games table" do
  database.create_table :games do
    primary_key :id
    String      :phone_number
    String      :guesses
    String      :word
  end
end