unless Nimbus::Config[:excluir_divisas]

class DivisasMod < Divisa
  @campos = {
    codigo: {tab: 'pre', grid:{}},
    descripcion: {tab: 'pre', grid:{}},
    decimales: {tab: 'pre', grid:{}},
    prefijo: {tab: 'pre', grid:{}, br: true},
    sufijo: {tab: 'pre', grid:{}},
  }

  @grid = {
    scroll: true,
    cellEdit: false,
  }

  @hijos = [{url: 'divisalineas', tab: 'post'}]

  include MantMod
end

class DivisasController < ApplicationController
end

end
