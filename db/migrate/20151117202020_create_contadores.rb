class CreateContadores < ActiveRecord::Migration
  def change
    create_table :contadores do |t|
      t.string :modelo
      t.string :campo
      t.string :clave
      t.integer :valor
    end
  end
end
