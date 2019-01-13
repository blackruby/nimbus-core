class TmpUpdateBloqueos < ActiveRecord::Migration[5.0]
  def change
    unless Bloqueo.column_names.include?('idindex')
      add_column :bloqueos, :idindex, :integer
      add_column :bloqueos, :activo, :boolean
    end
  end
end
