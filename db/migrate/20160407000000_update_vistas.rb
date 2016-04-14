class UpdateVistas < ActiveRecord::Migration
  def change
    remove_column :vistas, :updated_at
    add_column :vistas, :data, :binary
  end
end
