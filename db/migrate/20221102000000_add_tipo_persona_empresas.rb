class AddTipoPersonaEmpresas < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_empresas]
    def change
      add_column :empresas, :tipo_persona, :string
      add_column :h_empresas, :tipo_persona, :string
      Empresa.update_all(tipo_persona: 'j')
      HEmpresa.update_all(tipo_persona: 'j')
    end
  end
end
