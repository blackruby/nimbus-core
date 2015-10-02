class PaisesMod < Pais
  @campos = {
    codigo: {tab: 'pre', gcols: 2, grid:{cellattr: '~fon~'}},
    nombre: {tab: 'pre', gcols: 4, grid:{}},
    tipo: {tab: 'pre', gcols: 2, grid:{}},
    codigo_cr: {tab: 'pre', gcols: 2, grid:{}},

    campo_1: {diag: 'uno', gcols: 12},
    campo_2: {diag: 'uno', gcols: 12},
    campo_3: {diag: 'uno', gcols: 12},
    campo_4: {diag: 'uno', gcols: 12},
    campo_5: {diag: 'uno', gcols: 12},
    campo_6: {diag: 'uno', gcols: 12},
    campo_7: {diag: 'uno', gcols: 12},
    campo_8: {diag: 'uno', gcols: 12},
    campo_9: {diag: 'uno', gcols: 12},
    campo_10: {diag: 'uno', gcols: 12},
    campo_11: {diag: 'uno', gcols: 12},
    campo_12: {diag: 'uno', gcols: 12},
    campo_13: {diag: 'uno', gcols: 12},
    campo_14: {diag: 'uno', gcols: 12},
  }

  @grid = {
    height: 250,
    scroll: true,
  }

  @dialogos = [
    {id: 'uno', titulo: 'mytit', botones: [{label: 'si', accion: ''}]}
  ]

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
