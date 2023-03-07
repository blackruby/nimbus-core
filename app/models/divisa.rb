unless Nimbus::Config[:excluir_divisas]

class Divisa < ActiveRecord::Base
  @propiedades = {
    codigo: {pk: true, manti: 3, may: true, req: true},
    descripcion: {},
    decimales: {manti: 1},
    prefijo: {},
    sufijo: {},
  }

  has_many :divisalineas, dependent: :destroy
  has_many :paises, -> {order(:codigo)}

  @auto_comp_data = { campos: %w[codigo descripcion], orden: 'codigo' }
  def auto_comp_label(tipo)
    codigo + ' - ' + descripcion
  end

  def auto_comp_value(tipo)
    codigo + ' - ' + descripcion
  end

  def self.convertir_a_divisa(divisaorigen_id, divisadestino_id, importe, fecha, decimales_extra = 0, masa_array = nil)
    return importe if divisaorigen_id == divisadestino_id
    es_array = importe.is_a?(Array)
    return 0.00 if !es_array && importe.to_f.zero?
    cambio = 1
    if masa_array.present?
      #Buscar las divisas que tocan
      if divisaorigen_id.present? && divisadestino_id.present?
        aux = masa_array.select{|x| x[0] == divisaorigen_id && x[2] <= fecha}.last
        cambio = aux[1].to_f.round(6) if aux.present?
      end
    else
      cambio = self.cambio_a_fecha(divisaorigen_id, divisadestino_id, fecha)
    end
    #Le suma 2 de las divisas
    decimales_extra = decimales_extra.to_i + 2
    if es_array
      return importe.map{|imp| (imp * cambio).round(decimales_extra)}
    else
      return (importe * cambio).round(decimales_extra)  
    end  
  end

  #Devuelve el cambio mas cercano analizando divisaorigen_id y divisadestino_id
  def self.cambio_a_fecha(divisaorigen_id, divisadestino_id, fecha)
    return 1 if divisaorigen_id == divisadestino_id || divisaorigen_id.to_i == 0 || divisadestino_id.to_i == 0
    divisas = [divisaorigen_id, divisadestino_id]
    aux = sql_exe("SELECT case when divisacambio_id = #{divisadestino_id} then dl.cambio else 1 / dl.cambio end
                  FROM divisas d
                  JOIN divisalineas dl ON dl.divisa_id = d.id and dl.fecha = (
										SELECT MAX(f.fecha) 
                    FROM divisalineas f
                    WHERE d.id <> dl.divisacambio_id and fecha <= '#{fecha}'
                    and (f.divisa_id = d.id or f.divisa_id = dl.divisacambio_id)
                  )
                  WHERE dl.cambio <> 0 and dl.cambio <> 1 and fecha <= '#{fecha}'
                  and d.id in (#{divisas.join(",")}) and dl.divisacambio_id in (#{divisas.join(",")})").values
    return aux.present? ? aux[0][0].to_f.round(6) : 1 
  end

  #Devuelve el cambio respecto a la divisa que se le pase
  def self.cambio_a_fecha_masa(divisadestino_id)
    return sql_exe("SELECT case when d.id <> #{divisadestino_id} then d.id else dl.divisacambio_id end, case when divisacambio_id = #{divisadestino_id} then dl.cambio else 1 / dl.cambio end, dl.fecha
                  FROM divisas d
                  JOIN divisalineas dl ON dl.divisa_id = d.id
                  WHERE dl.cambio <> 0 and dl.cambio <> 1").values
  end
end

end
