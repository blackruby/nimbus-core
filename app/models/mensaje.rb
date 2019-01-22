class Mensaje < ActiveRecord::Base
  belongs_to :from, :class_name => 'Usuario'
  belongs_to :to, :class_name => 'Usuario'

  include Modelo
end

Nimbus.load_adds __FILE__