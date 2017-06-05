class PaisesMod < Pais
  @campos = {
    codigo: {tab: 'pre', gcols: 2, grid:{}},
    nombre: {tab: 'pre', gcols: 4, grid:{}},
    tipo: {tab: 'pre', gcols: 2, grid:{}},
    codigo_iso3: {tab: 'pre', gcols: 2, br: true},
    codigo_num: {tab: 'pre', gcols: 2},
    codigo_cr: {tab: 'pre', gcols: 2},
  }

  @grid = {
    height: 250,
    scroll: true,
  }

  @menu_l = [
    {label: 'Listado de Países', url: '/gi/run/nimbus-core/l_paises'},
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
