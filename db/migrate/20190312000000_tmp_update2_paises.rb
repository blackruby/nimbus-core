class TmpUpdate2Paises < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_paises]
    def change
      unless Pais.column_names.include?('divisa_id')
        add_column :paises, :divisa_id, :integer
        add_column :h_paises, :divisa_id, :integer
      end
    end
  end
end
