unless Nimbus::Config[:excluir_divisas]

class DivisasMod < Divisa
  @campos = {
    codigo: {tab: 'pre', grid:{}},
    descripcion: {tab: 'pre', grid:{}},
    decimales: {tab: 'pre', grid:{}},
  }

  @grid = {
    scroll: true,
  }

  #@hijos = []

  #def ini_campos_ctrl
  #end
end

class DivisasMod
  include MantMod
end

class DivisasController < ApplicationController
end

Nimbus.load_adds __FILE__

end
