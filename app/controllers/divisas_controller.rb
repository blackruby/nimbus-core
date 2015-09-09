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

  #after_initialize :ini_campos_ctrl

  #def ini_campos_ctrl
  #end
end

class DivisasMod < Divisa
  include MantMod
end

class DivisasController < ApplicationController
end
