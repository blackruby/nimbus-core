class CreateAccesos < ActiveRecord::Migration
  unless Nimbus::Config[:excluir_accesos]
    def change
      col = lambda {|t|
          t.references :usuario
          t.datetime :fecha
          t.string :login
          t.string :ip
          t.string :status
      }

      create_table(:accesos) {|t| col.call(t)}
    end
  end
end
