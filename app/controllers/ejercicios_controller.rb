unless Nimbus::Config[:excluir_ejercicios]

class EjerciciosMod < Ejercicio
  @campos = {
    codigo: {tab: 'pre', grid:{}},
    descripcion: {tab: 'pre', grid:{}},
    ej_anterior_id: {tab: 'pre'},
    ej_siguiente_id: {tab: 'pre'},
    divisa_id: {tab: 'pre', manti: 10, req: true},
    fec_inicio: {tab: 'pre', grid:{}, req: true},
    fec_fin: {tab: 'pre', grid:{}, req: true},
  }

  @grid = {
    height: 100,
    scroll: true,
    cellEdit: false,
  }
  #@hijos = []

  #def ini_campos_ctrl
  #end
end

class EjerciciosMod
  include MantMod
end

class EjerciciosController < ApplicationController
  def before_envia_ficha
    if @fact.id.nil?
      @fact.divisa_id = @fact.empresa.try(:pais).try(:divisa_id)
    end
  end

  def vali_save
    "La fecha final debe de ser mayor a la inicial" if @fact.fec_fin < @fact.fec_inicio
  end
end

Nimbus.load_adds __FILE__

end
