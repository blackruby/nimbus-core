class CreateDivisalineas < ActiveRecord::Migration[5.0]
  def change
    col = lambda {|t|
        t.references :divisa, index: false
        t.references :divisacambio, index: false
        t.date :fecha
        t.decimal :cambio
    }

    create_table(:divisalineas) {|t| col.call(t)}

    add_index 'divisalineas', ['divisa_id','divisacambio_id','fecha'], unique: true, name: 'divisalineas_nimpk'

    create_table(:h_divisalineas) {|t|
      col.call(t)
      t.integer :idid
      t.references :created_by, index: false
      t.timestamp :created_at
    }
  end
end
