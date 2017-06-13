class CreateContadores < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_contadores]
    def change
      create_table :contadores do |t|
        t.string :modelo
        t.string :campo
        t.string :clave
        t.integer :valor
      end

      add_index 'contadores', ['modelo', 'campo', 'clave'], unique: true, name: 'contadores_nimpk'
    end
  end
end
