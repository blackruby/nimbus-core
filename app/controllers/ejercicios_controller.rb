unless Nimbus::Config[:excluir_ejercicios]

class EjerciciosMod < Ejercicio
  @campos = {
    codigo: {tab: 'pre', grid:{}},
    descripcion: {tab: 'pre', grid:{}},
    ej_anterior_id: {tab: 'pre'},
    ej_siguiente_id: {tab: 'pre'},
    divisa_id: {tab: 'pre', manti: 10},
    fec_inicio: {tab: 'pre', grid:{}, req: true},
    fec_fin: {tab: 'pre', grid:{}, req: true},
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
  def vali_save
    "La fecha final debe de ser mayor a la inicial" if @fact.fec_fin < @fact.fec_inicio
  end
end

Nimbus.load_adds __FILE__

end
