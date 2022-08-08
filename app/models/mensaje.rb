class Mensaje < ActiveRecord::Base
  @propiedades = {
    texto: {rich: true}
  }

  belongs_to :from, :class_name => 'Usuario'
  belongs_to :to, :class_name => 'Usuario'

  def self.bus_filter(h)
    "(mensajes.from_id = #{h[:usu].id} OR mensajes.to_id = #{h[:usu].id})" unless h[:usu].admin
  end
end
