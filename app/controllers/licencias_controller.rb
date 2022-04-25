class LicenciasMod
  @campos = {
    sep: {type: :div, tab: 'pre', gcols: 4},
    bot_del: {type: :div, tab: 'pre', gcols: 2},
    bot_ref: {type: :div, tab: 'pre', gcols: 2},
    sep2: {type: :div, tab: 'pre', gcols: 4, br: true},
    licencias: {type: :div, tab: 'pre', gcols: 8},
  }

  @nivel = ''

  include MantMod
end

class LicenciasController < ApplicationController
  def before_edit
    @usu.admin
  end

  def before_envia_ficha
    @titulo = 'Licencias en uso'
    @head = 0

    crea_boton cmp: :bot_del, label: 'Borrar selección', icon: 'delete', accion: :borrar_sel
    crea_boton cmp: :bot_ref, label: 'Refrescar', icon: 'refresh', accion: :lic_grid
    lic_grid
  end

  def lic_grid
    cols = [
      {name: 'fecha', label: nt('fecha'), type: :datetime, width: 150},
      {name: 'usuario_id', label: nt('usuario'), width: 250},
    ]

    crea_grid(
      cmp: :licencias,
      modo: :sel,
      cols: cols,
      grid: {
        multiselect: true,
        altRows: false,
        caption: @titulo,
        height: 800,
      },
      data: Licencia.order('fecha').pluck(:id, :fecha, :usuario_id)
    )
  end

  def borrar_sel
    Licencia.delete_by id: @fact.licencias if @fact.licencias.present?
    lic_grid
  end
end
