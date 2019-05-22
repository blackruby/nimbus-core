class P2pMod
  @campos = {
    panel: {type: :div, tab: 'pre', gcols: 12},
  }

  include MantMod
end

class P2pController < ApplicationController
  def before_edit
    @usu.admin
  end

  def before_envia_ficha
    @head = 0

    @titulo = 'Procesos en segundo plano'
    p2p_grid
  end

  def p2p_grid
    cols = [
      {name: 'fecha', label: nt('fecha'), type: :datetime, width: 150},
      {name: 'usuario_id', label: nt('usuario'), width: 250},
      {name: 'ctrl', label: nt('controlador'), width: 200},
      {name: 'info', label: nt('info'), width: 250},
      {name: 'tag', label: nt('tag'), width: 60},
      {name: 'pgid', label: 'pgid', type: :integer, width: 60}
    ]

    crea_grid(
      cmp: :panel,
      modo: :ed,
      export: 'p2p',
      cols: cols,
      del: false,
      ins: false,
      sel: :row,
      bsearch: true,
      search: false,
      grid: {
        cellEdit: false,
        multiselect: false,
        altRows: false,
        caption: @titulo,
        height: 800,
        onSelectRow: '~function(r, s){if (s) callFonServer(\'p2p_select\', {id: r})}~'
      },
      data: P2p.order('fecha desc').pluck(:id, :fecha, :usuario_id, :ctrl, :info, :tag, :pgid)
    )
  end

  def p2p_select
    mensaje tit: 'Control del proceso', msg: '¿Desea detener el proceso seleccionado?', bot: [{label: 'Detener', busy: true, accion: :p2p_kill15}, {label: 'Forzar Detención',busy: true,  accion: :p2p_kill9}, {label: 'Cancelar'}]
    @g[:id] = params[:id]
  end

  def p2p_kill(sig)
    stop = false
    p = P2p.find_by id: @g[:id]

    begin
      Process.kill sig, -p.pgid
    rescue
      # El proceso no existía
      stop = true
    end

    # Esperamos un segundo y miramos a ver si sigue existiendo el proceso
    sleep 1
    begin
      Process.getpgid p.pgid
    rescue
      # El proceso ya no existe. Se ha detenido con éxito.
      stop = true
    end

    # Si stop es true hay que eliminar el registro de la tabla y refrescar el grid
    if stop
      P2p.delete(@g[:id])
      p2p_grid
    end
  end

  def p2p_kill9
    p2p_kill 'KILL'
  end

  def p2p_kill15
    p2p_kill 'TERM'
  end
end