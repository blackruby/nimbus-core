class TmpUpdateUsuarios < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_usuarios]
    def change
      unless Usuario.column_names.include?('api')
        add_column :usuarios, :api, :boolean
        add_column :h_usuarios, :api, :boolean
      end
    end
  end
end
