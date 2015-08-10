class CreateEmpresas < ActiveRecord::Migration
  def change
    col = lambda {|t|
        t.string :codigo
        t.string :nombre
        t.string :cif
        t.string :direccion
        t.string :cod_postal
        t.string :poblacion
        t.string :provincia
        t.string :telefono
        t.string :fax
        t.string :email
        t.integer :p_long
        t.string :p_mod_fiscal
        t.integer :p_dec_cantidad
        t.integer :p_dec_precio_r
        t.integer :p_dec_precio_v
    }

    create_table(:empresas) {|t| col.call(t)}

    add_index 'empresas', ['codigo'], unique: true

    create_table(:h_empresas) {|t|
      col.call(t)
      t.integer :idid
      t.references :created_by
      t.timestamp :created_at
    }
  end
end
