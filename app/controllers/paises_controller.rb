unless Nimbus::Config[:excluir_paises]

class PaisesController < ApplicationController
  def api_paises
    render json: {st: 'Ok', dat: Pais.order(:codigo).pluck(:codigo, :nombre)}
  end
end

end
