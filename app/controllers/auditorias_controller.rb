class AuditoriasController < ApplicationController
  def before_index
    status_botones crear: nil, grabar: nil, osp: nil, borrar: nil
    Nimbus::Config[:audit] && @usu.admin
  end

  def set_permiso
    @dat[:prm] = 'c'
  end

  def before_envia_ficha
    return if @fact.id == 0

    case @fact.accion
    when 'E'
      if @fact.rid
        texto = 'Debajo se muestra el registro editado'
        url = "/#{@fact.controlador}/#{@fact.rid}/edit?lock=1"
      else
        texto = 'Debajo se muestra el proceso al que se accedió'
        url = "/#{@fact.controlador}"
      end
    when 'G'
      if @fact.rid
        texto = 'Debajo se muestra el registro grabado'
        url = "/#{@fact.controlador}/#{@fact.rid}/edit?lock=1"
      else
        texto = 'Debajo se muestra el proceso que se ejecutó'
        url = "/#{@fact.controlador}"
      end
    when 'A'
      texto = 'Debajo se muestra el mantenimiento en el que se comenzó un nuevo registro'
      url = "/#{@fact.controlador}"
    when 'B'
      texto = 'Debajo se muestra el histórico del registro borrado'
      url = "/histo/#{@fact.controlador}/#{@fact.rid}"
      #http://127.0.0.1:3000/histo/paises/269?idb=555&eid=4&jid=3
    else
      texto = 'Acción desconocida'
      url = nil
    end

    @ajax << "$(texto).css('background-color', 'yellow').css('text-align', 'center').append('#{texto}');"
    @ajax << "$(hijo_0).attr('src', '#{url}');" if url
  end
end
