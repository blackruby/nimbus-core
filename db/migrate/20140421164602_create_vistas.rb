class CreateVistas < ActiveRecord::Migration[5.0]
  def change
    create_table :vistas do |t|

      t.timestamps
    end
  end
end
