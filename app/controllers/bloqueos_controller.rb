class BloqueosMod < Bloqueo
  @campos = {
    controlador: {tab: 'pre', gcols: 2, grid:{}},
    clave: {tab: 'pre', gcols: 3, grid:{}},
    ir_a: {tab: 'pre', gcols: 1, type: :div},
    created_by_id: {tab: 'pre', gcols: 3, label: 'Usuario', grid:{}},
    created_at: {tab: 'pre', gcols: 3, label: 'Fecha', grid:{}},
  }

  @grid = {
    height: 250,
    scroll: true,
  }

  include MantMod
end

class BloqueosController < ApplicationController
  def grid_conf(grid)
    grid[:wh] = "empre_id = #{@dat[:eid].to_i} OR empre_id IS NULL"
  end

  def before_envia_ficha
    status_botones crear: nil, grabar: nil, osp: nil
    disable :clave
    disable :created_by_id
    disable :created_at

    if (@fact.id != 0)
      @ajax << "$('#ir_a').append(creaMdlButton('b-ir-clave', 48, 2, 32, 'exit_to_app', 'Ir a la ficha bloqueada'));"
      #@ajax << "$('#b-ir-clave').click(function(){window.open('/#{@fact.controlador}/#{@fact.ctrlid}/edit')});"
      @ajax << "$('#b-ir-clave').click(function(){window.open('/#{@fact.controlador}?id_edit=#{@fact.ctrlid}')});"
    end
  end
end

Nimbus.load_adds __FILE__