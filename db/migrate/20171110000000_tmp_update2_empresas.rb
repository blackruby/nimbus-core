class TmpUpdate2Empresas < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_empresas]
    def change
      unless Empresa.column_names.include?('pais_id')
        add_column :empresas, :pais_id, :integer
        add_column :h_empresas, :pais_id, :integer
      end
    end
  end
end
