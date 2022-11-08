class TmpUpdateDivisas < ActiveRecord::Migration[5.0]
  def change
    unless Divisa.column_names.include?('prefijo')
      add_column :divisas, :prefijo, :string
      add_column :h_divisas, :prefijo, :string
    end

    unless Divisa.column_names.include?('sufijo')
      add_column :divisas, :sufijo, :string
      add_column :h_divisas, :sufijo, :string
    end
  end
end
