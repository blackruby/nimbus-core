class CreatePaises < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_paises]
    def change
      col = lambda {|t|
          t.string :codigo
          t.string :nombre
          t.string :tipo
          t.string :codigo_cr
          t.string :codigo_iso3
          t.string :codigo_num
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
end
