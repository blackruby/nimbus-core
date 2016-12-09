class UpdateEjercicios < ActiveRecord::Migration
  def change
    add_column :ejercicios, :param, :text
    add_column :h_ejercicios, :param, :text
  end
end
