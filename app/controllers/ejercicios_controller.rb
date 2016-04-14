class EjerciciosMod < Ejercicio
  @campos = {
    codigo: {tab: 'pre', grid:{}},
    descripcion: {tab: 'pre', grid:{}},
    ej_anterior_id: {tab: 'pre'},
    ej_siguiente_id: {tab: 'pre'},
    divisa_id: {tab: 'pre', manti: 10},
    fec_inicio: {tab: 'pre', grid:{}},
    fec_fin: {tab: 'pre', grid:{}},
  }

  @grid = {
    height: 100,
    scroll: true,
  }
  #@hijos = []

  #def ini_campos_ctrl
  #end
end

class EjerciciosMod < Ejercicio
  include MantMod
end

class EjerciciosController < ApplicationController
end
