class TmpUpdatePaises < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_paises]
    def change
      unless Pais.column_names.include?('codigo_iso3')
        add_column :paises, :codigo_iso3, :string
        add_column :paises, :codigo_num, :string
        add_column :h_paises, :codigo_iso3, :string
        add_column :h_paises, :codigo_num, :string
      end
    end
  end
end
