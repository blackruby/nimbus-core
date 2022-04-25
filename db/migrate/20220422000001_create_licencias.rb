class CreateLicencias < ActiveRecord::Migration[5.0]
  unless Nimbus::Config[:excluir_accesos]
    def change
      col = lambda {|t|
          t.references :usuario
          t.datetime :fecha
          t.string :sid
      }

      create_table(:licencias) {|t| col.call(t)}
    end
  end
end
