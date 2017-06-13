class AddUnaccent < ActiveRecord::Migration[5.0]
  def change
    execute "create extension unaccent"
  end
end
