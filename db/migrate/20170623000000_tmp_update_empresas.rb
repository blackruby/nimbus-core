class TmpUpdateEmpresas < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_empresas]
    def change
      unless Empresa.column_names.include?('nombre_comercial')
        add_column :empresas, :nombre_comercial, :string
        add_column :h_empresas, :nombre_comercial, :string
      end
    end
  end
end
