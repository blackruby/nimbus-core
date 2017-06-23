class CreateEmpresas < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_empresas]
    def change
      col = lambda {|t|
          t.string :codigo
          t.string :nombre
          t.string :nombre_comercial
          t.string :cif
          t.string :direccion
          t.string :cod_postal
          t.string :poblacion
          t.string :provincia
          t.string :telefono
          t.string :fax
          t.string :email
          t.string :web
          t.text :param
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
end
