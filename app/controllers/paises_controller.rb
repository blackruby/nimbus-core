class PaisesMod < Pais
  @campos = {
    codigo: {tab: 'pre', gcols: 2, grid:{}},
    nombre: {tab: 'pre', gcols: 4, grid:{}},
    tipo: {tab: 'pre', gcols: 2, grid:{}},
    codigo_cr: {tab: 'pre', gcols: 2, grid:{}},
  }

  @grid = {
    height: 250,
    scroll: true,
  }

  @menu_l = [
    {label: 'Listado de Países', url: '/gi/run/nimbus-core/paises'},
  ]

  #@hijos = []

  #def ini_campos_ctrl
  #end
end

class PaisesMod < Pais
  include MantMod
end

class PaisesController < ApplicationController
end

Nimbus.load_adds __FILE__
