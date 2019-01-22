unless Nimbus::Config[:excluir_paises]

class Pais < ActiveRecord::Base
  @propiedades = {
    codigo: {manti: 2, pk: true},
    nombre: {manti: 30},
    tipo: {manti: 8, sel: {N: 'nacional', C: 'cee', R: 'resto'}},
    codigo_iso3: {manti: 3},
    codigo_num: {manti: 3, mask: '999'},
    codigo_cr: {manti: 3},
  }

  after_initialize :ini_campos

  @auto_comp_data = {campos: ['codigo', 'nombre', 'codigo_cr']}

  def ini_campos
    self.tipo ||= 'R' if self.new_record?
  end
end

class Pais
  include Modelo
end

class HPais < Pais
  include Historico
end

Nimbus.load_adds __FILE__

end
