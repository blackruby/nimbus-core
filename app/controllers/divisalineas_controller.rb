unless Nimbus::Config[:excluir_divisas]

class DivisalineasMod < Divisalinea
  @campos = {
    divisacambio_id:  {tab: 'pre', grid:{}, req: true, label: nt('divisa')}, 
    fecha:            {tab: 'pre', grid:{}, req: true, br: true},
    cambio:           {tab: 'pre', grid:{}, req: true},
  }
end

class DivisalineasMod
  include MantMod
end

class DivisalineasController < ApplicationController
end

Nimbus.load_adds __FILE__

end