class CreateEjercicios < ActiveRecord::Migration
  def change
    col = lambda {|t|
        t.references :empresa
        t.string :codigo
        t.string :descripcion
        t.references :ej_anterior
        t.references :ej_siguiente
        t.references :divisa
        t.date :fec_inicio
        t.date :fec_fin
        t.text :param
    }

    create_table(:ejercicios) {|t| col.call(t)}

    add_index 'ejercicios', ['empresa_id','codigo'], unique: true

    create_table(:h_ejercicios) {|t|
      col.call(t)
      t.integer :idid
      t.references :created_by
      t.timestamp :created_at
    }
  end
end
