class CreateUsuarios < ActiveRecord::Migration
  unless Nimbus::Config[:excluir_usuarios]
    def change
      col = lambda {|t|
        t.string :codigo
        t.string :nombre
        t.string :email
        t.string :password_salt
        t.string :password_hash
        t.timestamp :password_fec_mod
        t.boolean :admin
        t.integer :timeout
        t.references :empresa_def
        t.references :ejercicio_def
        t.text :pref
        t.date :fecha_baja
        t.integer :num_dias_validez_pass
        t.string :ips
        t.references :ldapservidor
      }

      create_table(:usuarios) {|t| col.call(t)}

      add_index 'usuarios', ['codigo'], unique: true

      create_table(:h_usuarios) {|t|
        col.call(t)
        t.integer :idid
        t.references :created_by
        t.timestamp :created_at
      }
    end
  end
end
