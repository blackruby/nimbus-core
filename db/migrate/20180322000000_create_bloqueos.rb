class CreateBloqueos < ActiveRecord::Migration[5.0]
  def change
    create_table :bloqueos do |t|
      t.string :controlador
      t.integer :ctrlid
      t.references :empre
      t.string :clave
      t.references :created_by
      t.timestamp :created_at
    end

    add_index 'bloqueos', ['controlador', 'ctrlid'], unique: true
  end
end
