class Update2Usuarios < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_usuarios]
    def change
      add_column :usuarios, :audit, :boolean
      add_column :h_usuarios, :audit, :boolean
    end
  end
end
