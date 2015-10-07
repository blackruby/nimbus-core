class PaisesMod < Pais
  @campos = {
    codigo: {tab: 'pre', gcols: 2, grid:{cellattr: '~fon~'}},
    nombre: {tab: 'pre', gcols: 4, grid:{}},
    tipo: {tab: 'pre', gcols: 2, grid:{}},
    codigo_cr: {tab: 'pre', gcols: 2, grid:{}},

    campo_1: {dlg: 'uno', gcols: 12},
    campo_2: {dlg: 'uno', gcols: 12},
    campo_3: {dlg: 'uno', gcols: 12},
    campo_4: {dlg: 'uno', gcols: 12},
    campo_5: {dlg: 'uno', gcols: 12},
    campo_6: {dlg: 'uno', gcols: 12},
  }

  @grid = {
    height: 250,
    scroll: true,
  }

  @dialogos = [
    {id: 'uno', titulo: 'mytit', botones: [{label: 'si', accion: '', close: false}], menu: 'Mi diálogo'},
  ]

  @menu_r = [
    {label: 'Opción 1', accion: 'mi_funcion'},
    {label: 'Opción 2'},
    {label: 'Opción 3'},
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
  def mi_funcion
    puts '****************** hola *****************'
  end

  def vali_campo_1
    @fact.codigo.size < 2 ? 'Código corto' : nil
  end
  def on_campo_1
    mensaje tit: 'Hola', msg: 'Un texto cualquiera', bot: [{label: 'Ok', accion: 'mi_funcion'}]
  end
end
