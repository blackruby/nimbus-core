class CreateP2p < ActiveRecord::Migration[5.0]
  def change
    col = lambda {|t|
        t.references :usuario
        t.datetime :fecha
        t.string :ctrl
        t.string :info
        t.string :tag
        t.integer :pgid
    }

    create_table(:p2p) {|t| col.call(t)}
  end
end
