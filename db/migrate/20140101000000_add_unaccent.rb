class AddUnaccent < ActiveRecord::Migration
  def change
    execute "create extension unaccent"
  end
end
