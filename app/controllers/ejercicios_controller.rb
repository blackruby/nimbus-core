unless Nimbus::Config[:excluir_ejercicios]

class EjerciciosMod < Ejercicio
  @campos = {
    codigo: {tab: 'pre', gcols: 3, grid:{}},
    descripcion: {tab: 'pre', gcols: 5, grid:{}},
    fec_inicio: {tab: 'general', gcols: 3, br: true, grid:{}, req: true},
    fec_fin: {tab: 'general', gcols: 3, grid:{}, req: true},
    ej_anterior_id: {tab: 'general', gcols: 3},
    ej_siguiente_id: {tab: 'general', gcols: 3},
    divisa_id: {tab: 'general', gcols: 6, br: true, req: true},
  }

  @grid = {
    height: 100,
    scroll: true,
    cellEdit: false,
  }

  before_save :graba_param

  def ini_campos_ctrl
    self.campos.each {|c, v|
      self[c] = self.param[c] if v[:param]
    }
  end

  def graba_param
    self.campos.each {|c, v|
      self.param[c] = self[c] if v[:param]
    }
  end
  
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

end
