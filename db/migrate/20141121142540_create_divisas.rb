class CreateDivisas < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_divisas]
    def change
      col = lambda {|t|
          t.string :codigo
          t.string :descripcion
          t.integer :decimales
      }

      create_table(:divisas) {|t| col.call(t)}

      add_index 'divisas', ['codigo'], unique: true

      create_table(:h_divisas) {|t|
        col.call(t)
        t.integer :idid
        t.references :created_by
        t.timestamp :created_at
      }
    end
  end
end
