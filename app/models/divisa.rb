unless Nimbus::Config[:excluir_divisas]

class Divisa < ActiveRecord::Base
  @propiedades = {
    codigo: {pk: true, manti: 3, may: true, req: true},
    descripcion: {},
    decimales: {manti: 1},
  }

  has_many :divisalineas, dependent: :destroy
  has_many :paises, -> {order(:codigo)}

  #after_initialize :ini_campos

  #def ini_campos
  #end

  def self.convertir_a_divisa(divisaorigen, divisadestino, ejercicio, importe, fecha, decimales_extra = 0)
    return 0.00 if importe.to_f.zero?
    divisaorigen = divisaorigen.present? ? divisaorigen : ejercicio.divisa
    divisadestino = divisadestino.present? ? divisadestino : ejercicio.divisa
    return importe if (divisaorigen == divisadestino)
    return (importe * self.cambio_a_fecha(divisaorigen, divisadestino, fecha)).round(2 + decimales_extra)
  end

  #Devuelve el cambio mas cercano analizando divisaorigen y divisadestino
  def self.cambio_a_fecha(divisaorigen, divisadestino, fecha)
    cambio_origen = divisaorigen.divisalineas.where(:divisacambio_id => divisadestino.id).where("fecha < ?", fecha).order(:fecha => :desc).first
    cambio_destino = divisadestino.divisalineas.where(:divisacambio_id => divisaorigen.id).where("fecha < ?", fecha).order(:fecha => :desc).first

    if cambio_origen.present?
      if cambio_destino.present? #existe cambio_origen y cambio_destino, devolver el mas actual
        return (cambio_origen.fecha >= cambio_destino.fecha) ? cambio_origen.cambio : (1 / cambio_destino.cambio)
      else #solo existe origen
        return cambio_origen.cambio
      end
    else #solo podría haber cambio_destino
      return cambio_destino.present? ? (1 / cambio_destino.cambio) : 1
    end
  end
end

class Divisa
  include Modelo
end

class HDivisa < Divisa
  include Historico
end

Nimbus.load_adds __FILE__

end
