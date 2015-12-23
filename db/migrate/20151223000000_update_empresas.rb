class UpdateEmpresas < ActiveRecord::Migration
  def change
    remove_column :empresas, :p_long
    remove_column :empresas, :p_mod_fiscal
    remove_column :empresas, :p_dec_cantidad
    remove_column :empresas, :p_dec_precio_r
    remove_column :empresas, :p_dec_precio_v
    add_column :empresas, :web, :string
    add_column :empresas, :param, :text

    remove_column :h_empresas, :p_long
    remove_column :h_empresas, :p_mod_fiscal
    remove_column :h_empresas, :p_dec_cantidad
    remove_column :h_empresas, :p_dec_precio_r
    remove_column :h_empresas, :p_dec_precio_v
    add_column :h_empresas, :web, :string
    add_column :h_empresas, :param, :text
  end
end
