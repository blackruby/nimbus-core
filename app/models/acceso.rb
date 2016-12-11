class Acceso < ActiveRecord::Base
  @propiedades = {
    usuario_id: {},
    login: {manti: 14},
    fecha: {},
    ip: {manti: 16},
    status: {manti: 2},
  }

  belongs_to :usuario, :class_name => 'Usuario'

  include Modelo
end
