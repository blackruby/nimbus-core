class CreateVistas < ActiveRecord::Migration
  def change
    create_table :vistas do |t|

      t.timestamps
    end
  end
end
