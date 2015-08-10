class DivisasMod < Divisa
  @campos = {
    codigo: {div: 'g1', grid:{}},
    descripcion: {div: 'g1', grid:{}},
    decimales: {div: 'g1', grid:{}},
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
