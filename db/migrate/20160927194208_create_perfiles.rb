class CreatePerfiles < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_perfiles]
    def change
      col = lambda {|t|
          t.string :codigo
          t.string :descripcion
          t.text :data
      }

      create_table(:perfiles) {|t| col.call(t)}

      add_index 'perfiles', ['codigo'], unique: true, name: 'perfiles_nimpk'
    end
  end
end
