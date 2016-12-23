class CreatePerfiles < ActiveRecord::Migration
  def change
    col = lambda {|t|
        t.string :codigo
        t.string :descripcion
        t.text :data
    }

    create_table(:perfiles) {|t| col.call(t)}

    add_index 'perfiles', ['codigo'], unique: true, name: 'perfiles_nimpk'
  end
end