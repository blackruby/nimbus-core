class UpdateVistas < ActiveRecord::Migration[5.0]
  def change
    remove_column :vistas, :updated_at
    add_column :vistas, :data, :binary
  end
end
