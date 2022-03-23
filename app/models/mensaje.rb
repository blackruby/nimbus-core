class Mensaje < ActiveRecord::Base
  belongs_to :from, :class_name => 'Usuario'
  belongs_to :to, :class_name => 'Usuario'
end
