class Auditoria < ActiveRecord::Base
  belongs_to :usuario, :class_name => 'Usuario'

  include Modelo
end