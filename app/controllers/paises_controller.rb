class PaisesMod < Pais
  @campos = {
    codigo: {div: 'g1', grid:{cellattr: '~fon~'}},
    nombre: {div: 'g1', grid:{}},
    tipo: {div: 'g1', grid:{}},
    codigo_cr: {div: 'g1', grid:{}},
  }

  #@hijos = []

  #after_initialize :ini_campos_ctrl

  #def ini_campos_ctrl
  #end
end

class PaisesMod < Pais
  include MantMod
end

class PaisesController < ApplicationController
end
