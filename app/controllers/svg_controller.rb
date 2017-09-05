class SvgMod
  @campos = {
    fecha: {type: :date, tab: 'pre'},
  }
end

class SvgMod
  include MantMod
end

class SvgController < ApplicationController
  def after_save
    dep = [{id: 1, x: 0, y: 0, litros: 20}, {id: 2, x: 100, y: 20, litros: 60}]

    @ajax << "pintaDepositos(#{dep.to_json});"
  end

  def op_menu
    mensaje "Has pulsado la opción #{params[:op]} en el depósito #{params[:id]}"
  end
end