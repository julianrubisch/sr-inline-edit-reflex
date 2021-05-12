ActiveRecord::Schema.define(version: 2021_04_29_143800) do
  create_table "books", force: :cascade do |t|
    t.string "title"
    t.string "author"
  end
end