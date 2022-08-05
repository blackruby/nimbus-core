class CreateTemas < ActiveRecord::Migration[5.0]
  def change
    col = lambda {|t|
        t.string :codigo
        t.string :descripcion
        t.references :usuario
        t.boolean :privado
        t.text :params
    }

    create_table(:temas) {|t| col.call(t)}
  end
end
