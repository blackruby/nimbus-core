class UpdateUsuarios < ActiveRecord::Migration
  def change
    add_column :usuarios, :fecha_baja, :date
    add_column :usuarios, :num_dias_validez_pass, :integer
    add_column :usuarios, :ips, :string
    add_column :usuarios, :ldapservidor_id, :integer

    add_column :h_usuarios, :fecha_baja, :date
    add_column :h_usuarios, :num_dias_validez_pass, :integer
    add_column :h_usuarios, :ips, :string
    add_column :h_usuarios, :ldapservidor_id, :integer
  end
end
