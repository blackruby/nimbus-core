unless Nimbus::Config[:excluir_paises]

class PaisesMod < Pais
  @campos = {
    codigo: {tab: 'pre', gcols: 2, grid:{}},
    nombre: {tab: 'pre', gcols: 4, grid:{}},
    tipo: {tab: 'pre', gcols: 2, grid:{}},
    codigo_iso3: {tab: 'pre', gcols: 2},
    separador: {tab: 'pre', gcols: 2, type: :div, br: true},
    divisa_id: {tab: 'pre', gcols: 4, grid:{}},
    codigo_num: {tab: 'pre', gcols: 2},
    codigo_cr: {tab: 'pre', gcols: 2},
  }

  @grid = {
    height: 250,
    scroll: true,
    cellEdit: false,
  }

  @menu_l = [
    {label: 'Listado de Países', url: '/gi/run/nimbus-core/l_paises'},
  ]

  #@hijos = []

  #def ini_campos_ctrl
  #end
end

class PaisesMod
  include MantMod
end

class PaisesController < ApplicationController
end

Nimbus.load_adds __FILE__

end
