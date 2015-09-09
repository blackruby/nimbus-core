class PaisesMod < Pais
  @campos = {
    codigo: {tab: 'pre', gcols: 2, grid:{cellattr: '~fon~'}},
    nombre: {tab: 'pre', gcols: 4, grid:{}},
    tipo: {tab: 'pre', gcols: 2, grid:{}},
    codigo_cr: {tab: 'pre', gcols: 2, grid:{}},
  }

  @grid = {
    height: 250,
    scroll: true,
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
