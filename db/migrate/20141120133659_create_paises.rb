class CreatePaises < ActiveRecord::Migration
  def change
    col = lambda {|t|
        t.string :codigo
        t.string :nombre
        t.string :tipo
        t.string :codigo_cr
    }

    create_table(:paises) {|t| col.call(t)}

    add_index 'paises', ['codigo'], unique: true

    create_table(:h_paises) {|t|
      col.call(t)
      t.integer :idid
      t.references :created_by
      t.timestamp :created_at
    }
  end
end
