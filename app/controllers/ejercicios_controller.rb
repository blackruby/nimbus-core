unless Nimbus::Config[:excluir_ejercicios]

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
