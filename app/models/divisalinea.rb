unless Nimbus::Config[:excluir_divisas]

class Divisalinea < ActiveRecord::Base
  @propiedades = {
    divisa_id:        {pk: 1},
    divisacambio_id:  {pk: 2},
    fecha:            {pk: 3},
    cambio:           {manti: 6, decim: 6},
  }

  belongs_to :divisa,       :class_name => 'Divisa'
  belongs_to :divisacambio, :class_name => 'Divisa'

end

class Divisalinea
  include Modelo
end

class HDivisalinea < Divisalinea
  include Historico
end

Nimbus.load_adds __FILE__

end
