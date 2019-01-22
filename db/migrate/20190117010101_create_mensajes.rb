class CreateMensajes < ActiveRecord::Migration[5.0]
  def change
    col = lambda {|t|
      t.references :from
      t.references :to
      t.timestamp :fecha
      t.text :texto
      t.boolean :leido
    }

    create_table(:mensajes) {|t| col.call(t)}
  end
end
