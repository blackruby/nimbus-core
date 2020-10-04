class CreateAuditorias < ActiveRecord::Migration[5.0]
  def change
    create_table(:auditorias) {|t|
      t.references :usuario, index: false
      t.timestamp :fecha
      t.string :controlador
      t.string :accion # (A: Alta, E: Edición, G: Grabación, B: Baja)
      t.integer :rid  # id del registro accedido (caso de ser un mantenimiento)
    }

    add_index 'auditorias', ['usuario_id', 'fecha']
  end
end
