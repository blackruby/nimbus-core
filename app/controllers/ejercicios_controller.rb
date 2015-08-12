class EjerciciosMod < Ejercicio
  @campos = {
    codigo: {div: 'g1', grid:{}},
    descripcion: {div: 'g1', grid:{}},
    ej_anterior_id: {div: 'g1'},
    ej_siguiente_id: {div: 'g1'},
    divisa_id: {div: 'g1', manti: 10},
    fec_inicio: {div: 'g1', grid:{}},
    fec_fin: {div: 'g1', grid:{}},
  }

  #@hijos = []

  #after_initialize :ini_campos_ctrl

  #def ini_campos_ctrl
  #end
end

class EjerciciosMod < Ejercicio
  include MantMod
end

class EjerciciosController < ApplicationController
end
