class PaisesMod < Pais
  @campos = {
    codigo: {div: 'g1', gcols: 1, grid:{cellattr: '~fon~'}},
    nombre: {div: 'g1', gcols: 4, grid:{}},
    tipo: {div: 'g1', gcols: 2, grid:{}},
    codigo_cr: {div: 'g1', gcols: 2, grid:{}},
  }

  #@hijos = []

  #after_initialize :ini_campos_ctrl

  #def ini_campos_ctrl
  #end

  def vali_codigo_cr
    return 'El código no puede tener dos caracteres' if codigo_cr.size == 2
  end
end

class PaisesMod < Pais
  include MantMod
end

class PaisesController < ApplicationController
end
