class P2p < ActiveRecord::Base
  @propiedades = {
  }

  belongs_to :usuario, :class_name => 'Usuario'

  include Modelo
end
