SESSION_EXPIRATION_TIME = 30.minutes

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  include ActionView::Helpers::NumberHelper

  before_action :ini_controller
  skip_before_action :ini_controller, only: [:destroy_vista]

  def self.nimbus_hook(h)
    @nimbus_hooks ||= {}
    h.each {|k, v|
      k = k.to_sym
      v = v.to_sym
      @nimbus_hooks[k] ? @nimbus_hooks[k] << v : @nimbus_hooks[k] = [v]
    }
  end

  def self.nimbus_hooks
    @nimbus_hooks
  end

  def self.set_nimbus_views(tipo, path)
    @nimbus_views ||= {}
    @nimbus_views[tipo] = path
  end

  def self.nimbus_views
    @nimbus_views
  end

  def call_nimbus_hook(fun)
    fun = fun.to_sym
    method(fun).call if self.respond_to?(fun)
    if self.class.nimbus_hooks and self.class.nimbus_hooks[fun]
      self.class.nimbus_hooks[fun].each {|f| method(f).call}
    end
  end

  def sesion_invalida
    ahora = Time.now
    @usu = Usuario.find_by id: session[:uid]

    return(true) unless @usu

    fex = @usu.timeout.nil? ? SESSION_EXPIRATION_TIME : @usu.timeout.minutes

    @usu.password_fec_mod.nil? or
    session[:fec] < @usu.password_fec_mod or
    (@usu.num_dias_validez_pass.to_i != 0 and (ahora - @usu.password_fec_mod)/86400 > @usu.num_dias_validez_pass) or
    (@usu.fecha_baja and @usu.fecha_baja <= Date.today) or
    (fex != 0 and session[:fem].to_time + fex < ahora)
  end

  def ini_controller
    if sesion_invalida
      #session[:uid] = nil
      if request.xhr? # Si la petición es Ajax...
        case params[:action]
        when 'noticias'
          render js: 'session_out();'
        when 'auto'
          #render json: [{error: 1}]
          render json: [{error: 'no_session'}]
        when 'list'
          render json: {error: 'no_session'}
        when 'validar'
          @ajax = 'alert(js_t("no_session"));'
          c = params[:campo]
          d = Vista.find_by({id: params[:vista].to_i}).try(:data)
          if d
            @fact = d[:fact]
            envia_campo(c, @fact[c]) if @fact
          end
          render js: @ajax
        else
          render js: 'alert(js_t("no_session"))'
        end
      else
        render file: '/public/401.html', status: 401, layout: false
      end

      return
    end

    session[:fem] = Time.now unless params[:action] == 'noticias'    #Actualizar fecha de último uso
    I18n.locale = session[:locale]

    if params[:vista]
      @v = Vista.find_by id: params[:vista].to_i
      if @v
        @dat = @v.data
      else
        case params[:action]
          when 'auto'
            render json: [{error: 'no_vista'}]
          when 'list'
            render json: {error: 'no_vista'}
          else
            render js: 'alert(js_t("no_vista"))'
        end
      end
    end
  end

=begin
  # Elegir layout

  layout :choose_layout

  def choose_layout
    params[:lay].nil? ? 'application' : params[:lay]
  end
=end

  #$h = {}

  # Clase del modelo ampliado para este mantenimiento (con campos X etc.)
  def class_mant
    if self.class.superclass.to_s == 'GiController'
      GiMod
    else
      (self.class.to_s[0..-11] + 'Mod').constantize
    end
  end

  # Clase del modelo original
  def class_modelo
    cm = class_mant.superclass
    cm.modelo_base || cm
  end

  def noticias
    render js: ''
  end

  def eval_cad(cad)
    cad.is_a?(String) ? eval('%~' + cad.gsub('~', '\~') + '~') : cad
  end

  # Funciones para interactuar con el cliente

  ##nim-doc {sec: 'Métodos de usuario', met: 'mensaje(arg)'}
  # Saca una ventana flotante modal mostrando un mensaje
  ##

  def mensaje(h)
    h = {msg: h} if h.is_a? String
    h[:tit] ||= nt('aviso')
    h[:bot] ||= []
    h[:close] = true if h[:close].nil?

=begin
    @ajax << '$("#dialog-nim-alert").html(' + h[:msg].to_json + ')'
    @ajax << '.dialog("option", "title", "' + h[:tit] + '")'
    @ajax << '.dialog("option", "buttons", {'
    h[:bot].each {|b|
      b[:close] = h[:close] if b[:close].nil?
      @ajax << '"' + nt(b[:label]) + '": function(){'
      @ajax << 'ponBusy();' if b[:busy]
      @ajax << 'callFonServer("' + b[:accion] + '", {}, quitaBusy);'
      @ajax << '$("#dialog-nim-alert").dialog("close");' if b[:close]
      @ajax << '},'
    }
    @ajax << '})'
    @ajax << '.dialog("open");'
=end
    @ajax << "$('<div></div>').html(#{h[:msg].to_json}).dialog({"
    @ajax << 'resizable: false, modal: true, width: "auto",'
    @ajax << 'close: function(){$(this).remove();},'
    @ajax << "title: #{h[:tit].to_json},"
    @ajax << 'buttons: {'
    h[:bot].each {|b|
      b[:close] = h[:close] if b[:close].nil?
      @ajax << "#{nt(b[:label]).to_json}: function(){"
      if b[:accion]
        @ajax << 'ponBusy();' if b[:busy]
        @ajax << "callFonServer(#{b[:accion].to_json}, {}, quitaBusy);"
      end
      @ajax << '$(this).dialog("close");' if b[:close]
      @ajax << '},'
    }
    @ajax << '}});'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'select_options(cmp, val, options)'}
  # Asigna un set de opciones al campo <i>cmp</i> que previamente ha tenido que
  # ser declarado como "select" (cláusula <i>sel</i> en la definición de campos).
  # <i>val</i> será la opción por defecto que quedará seleccionada.
  # <i>options</i> es un hash con la lista de opciones (clave: valor).
  ##

  def select_options(cmp, val, options)
    cmp = cmp.to_sym

    return unless @fact.campos[cmp][:sel]

    @ajax << "$('##{cmp}').html('"
    options.each{|k, v|
      @ajax << %Q(<option value="#{k}">#{nt(v)}</option>)
    }
    @ajax << %Q[').val("#{val}");]

    @fact[cmp] = val
  end

  def enable_disable(c, ed)
    ty = rol = nil

    if @fact
      v = @fact.campos[c.to_sym]
      if v
        ty = v[:type]
        rol = true if v[:rol]
      end
    end

    if c.to_s.ends_with?('_id') or rol
      @ajax << "$('##{c}').attr('readonly', #{ed == :d ? 'true' : 'false'}).attr('tabindex', #{ed == :d ? '-1' : '0'});"
    elsif ty == :date
      @ajax << "$('##{c}').datepicker('#{ed == :d ? 'disable' : 'enable'}');"
    elsif ty == :boolean
      @ajax << "mdlCheckStatus('#{c}','#{ed}');"
    else
      @ajax << "$('##{c}').attr('disabled', #{ed == :d ? 'true' : 'false'});"
    end
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'enable(campo)'}
  # Habilita el campo <i>campo</i>
  ##

  def enable(c)
=begin
    if c.to_s.ends_with?('_id')
      @ajax << "$('##{c}').attr('readonly', false).attr('tabindex', 0);"
    elsif @fact and @fact.campos[c.to_sym] and @fact.campos[c.to_sym][:type] == :date
      @ajax << "$('##{c}').datepicker('enable');"
    else
      @ajax << "$('##{c}').attr('disabled', false);"
    end
=end
    enable_disable(c, :e)
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'disable(campo)'}
  # Deshabilita el campo <i>campo</i>
  ##

  def disable(c)
    enable_disable(c, :d)
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'disable_all'}
  # Deshabilita todos los campos
  ##

  def disable_all
    @ajax << '$(":input").attr("disabled", true);'
    #@ajax << '$(".page-content").css("pointer-events", "none");'
    status_botones grabar: false, crear: false, borrar: false
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'enable_menu(id)'}
  # Habilita la opción de @menu_r con id <i>id</i>
  ##

  def enable_menu(m)
    @ajax << "if (parent != self) $('##{m}', parent.document).attr('disabled', false);"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'disable_menu(id)'}
  # Deshabilita la opción de @menu_r con id <i>id</i>
  ##

  def disable_menu(m)
    @ajax << "if (parent != self) $('##{m}', parent.document).attr('disabled', true);"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'enable_tab(tab)'}
  # Habilita la pestaña <i>tab</i>
  ##

  def enable_tab(t)
    @ajax << "$('#h_#{t}').attr('href', '#t_#{t}').css('cursor', 'pointer');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'disable_tab(tab)'}
  # Deshabilita la pestaña <i>tab</i>
  ##

  def disable_tab(t)
    @ajax << "$('#h_#{t}').attr('href', '#').css('cursor', 'not-allowed');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'visible(cmp)'}
  # Hace que el campo <i>cmp</i> sea visible
  ##

  def visible(c)
    @ajax << "$('##{c}').parent().css('display', 'block').parent().css('display', 'block');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'invisible(cmp, collapse)'}
  # Hace que el campo <i>cmp</i> desaparezca de pantalla.
  # Si <i>collapse</i> vale true hará que desaparezca el elemento y su hueco, acomodándose el resto de elementos al nuevo layout.
  # Por el contrario si vale false el elemento desaparece pero el hueco continúa.
  ##

  def invisible(c, collapse=false)
    @ajax << "$('##{c}').parent().#{collapse ? 'parent().' : ''}css('display', 'none');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'visible_element(elemento)'}
  # Hace que el elemento del DOM <i>elemento</i> sea visible
  ##

  def visible_element(c)
    @ajax << "$('##{c}').css('display', 'block');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'invisible_element(elemento)'}
  # Hace que el elemento del DOM <i>elemento</i> desaparezca de pantalla.
  ##

  def invisible_element(c)
    @ajax << "$('##{c}').css('display', 'none');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'foco(cmp)'}
  # Cede el foco al campo <i>cmp</i>
  ##

  def foco(c)
    @ajax << '$("#' + c.to_s + '").focus();'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'abre_dialogo(dlg)'}
  # Abre el diálogo <i>dlg</i>
  ##

  def abre_dialogo(diag)
    @ajax << "$('##{diag}').dialog('open');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'cierra_dialogo(dlg)'}
  # Cierra el diálogo <i>dlg</i>
  ##

  def cierra_dialogo(diag)
    @ajax << "$('##{diag}').dialog('close');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'edita_ficha(id)'}
  # Edita en una nueva pestaña la ficha con id <i>id</i> del mantenimiento en curso
  ##

  def edita_ficha(id)
    @ajax << "window.open('/#{params[:controller]}/#{id}/edit', '_self');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'open_url(url)'}
  # Abre la URL especificada en una nueva pestaña
  ##

  def open_url(url)
    @ajax << "window.open('#{url}', '_blank');"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'index_reload'}
  # Vuelve a cargar la página index del mantenimiento
  ##

  def index_reload
    @ajax << 'if (parent != self) parent.location.reload();'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'grid_reload'}
  # Actualiza el contenido del grid
  ##

  def grid_reload
    @ajax << 'parentGridReload();'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'grid_show'}
  # Muestra el grid del mantenimiento
  ##

  def grid_show
    @ajax << 'parentGridShow();'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'grid_hide'}
  # Oculta el grid del mantenimiento
  ##

  def grid_hide
    @ajax << 'parentGridHide();'
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'status_botones(hash)'}
  # Control del estado de los botones del mantenimiento
  # Nombres de los botones (claves del hash): editar, crear, grabar, borrar
  # Los valores de cada clave (botón) pueden ser: true (habilitar), false (deshabilitar), nil (eliminar el botón)
  # Ej.: status_botones borrar: nil, editar: true, grabar: false
  ##

  def status_botones(h={})
    @ajax << "statusBotones(#{h.to_json});"
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'envia_fichero(file:, file_cli: nil, rm: true, disposition: 'attachment')'}
  # Método para hacer download del fichero <i>file</i><br>
  # <i>file_cli</i> es el nombre que se propondrá para la descarga<br>
  # <i>rm</i> puede valer true o false en función de si queremos que el fichero se borre tras la descarga.<br>
  # <i>disposition</i> puede valer 'attachment' (por defecto) o 'inline' para que el fichero se descargue y se abra.
  # Notar que los argumentos son con nombre. Ejemplo de uso:<br>
  # <pre>envia_fichero file: '/tmp/zombi.pdf', file_cli: 'datos.pdf', rm: false</pre>
  # Si no se especifica <i>file_cli</i> se usará <i>file</i>. Y si no se especifica <i>rm</i> se asume true
  ##

  def envia_fichero(file:, file_cli: nil, rm: true, disposition: 'attachment')
    flash[:file] = file
    flash[:file_cli] = file_cli
    flash[:rm] = rm
    flash[:disposition] = disposition
    @ajax << "window.open('/nim_download');"
  end

  def nim_download
    if flash[:file]
      file_name = flash[:file]
    else
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    send_data File.read(file_name), filename: flash[:file_cli] || file_name.split('/')[-1], disposition: flash[:disposition] || 'attachment'
    FileUtils.rm_f(file_name) if flash[:rm]
  end

  def nim_send_file
    f = params[:file]
    return if f.include?('..')
    send_file (f.starts_with?('/tmp') ? f : "data/#{f}"), disposition: :inline
  end

  def nim_path_image(modelo, id, tag)
    src = Dir.glob("data/#{modelo}/#{id}/_imgs/#{tag}.*")
    src.size > 0 ? "src='/nim_send_file?file=#{src[0][5..-1]}'" : ''
  end

  def ir_a_origen
    return unless @fact.id

    org = $nim_origenes[@fact[params[:cmp]].to_sym]

    unless org
      mensaje 'Origen no registrado'
      return
    end

    url = org[:clase].constantize.method(org[:metodo]).call(@fact.id)

    if !url or url.empty?
      mensaje 'No existe la ficha asociada'
    else
      open_url url
    end
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'crea_iframe(cmp:, src:, height: 300)'}
  # Crea un iframe sobre el campo X <i>cmp</i>, que debe estar declarado con type: :div<br>
  # <i>src</i> es la url que mostrará el iframe y <i>height</i> la altura del mismo.<br>
  # Este último argumento es opcional y por defecto vale 300px.
  ##

  def crea_iframe(cmp:, src:, height: 300)
    @fact[cmp] = src
    @ajax << %Q($('##{cmp}').html('<iframe src="#{src}" style="height: #{height}px"></iframe>');)
  end

  # Métodos para ejecutar procesos en segundo plano con seguimiento

  def p2p(label: nil, pbar: nil, js: nil)
    @dat[:p2p][:label] = label if label
    @dat[:p2p][:pbar] = pbar if pbar
    @dat[:p2p][:js] = js if js
    @v.save
  end

  def p2p_req
    @ajax << "$('#p2p-d',#{@dat[:p2p][:mant]?'parent.document':'document'}).html(#{@dat[:p2p][:label].html_safe.to_json});" if @dat[:p2p][:label]
    @ajax << "$('#p2p-p',#{@dat[:p2p][:mant]?'parent.document':'document'})[0].MaterialProgress.setProgress(#{@dat[:p2p][:pbar]});" if @dat[:p2p][:tpb] == :fix and @dat[:p2p][:pbar]
    @ajax << @dat[:p2p][:js] if @dat[:p2p][:js]
    begin
      Process.waitpid(@dat[:p2p][:pid], Process::WNOHANG)
    rescue
      @ajax << 'p2pStatus=0;'
    end
  end

  def exe_p2p(tit: 'En proceso', label: nil, pbar: :inf, cancel: false, width: nil)
    @v.save # Por si hay cambios en @fact, etc. que se graben antes del fork y así padre e hijo tienen la misma información

    # Cerrar las conexiones con la base de datos para que el hijo no herede descriptores
    config = ActiveRecord::Base.remove_connection

    mant = class_mant.mant?
    mant = false

    # Crear el proceeso hijo
    h = fork {
      # Cierro todos los sockets que haya abiertos para que no interfieran
      # en las lecturas que de ellos haga el parent (básicamente los requests http)
      ObjectSpace.each_object(IO) {|io| io.close if io.class == TCPSocket and !io.closed?}
      # Restablecer la conexión con la base de datos
      ActiveRecord::Base.establish_connection(config)

      @dat[:p2p] = {pid: Process.pid, label: label, tpb: pbar, mant: mant}
      @v.save

      yield
    }

    # Código específico del padre...

    # Restablecer la conexión con la base de datos
    ActiveRecord::Base.establish_connection(config)
    # No hacer seguimiento del status del hijo (para que no quede zombi al terminar)
    Process.detach(h)

    # Código javascript para sacar el cuadro de diálogo de progreso del hijo
    @ajax << "p2p(#{tit.to_json}, #{label.to_s.to_json}, #{pbar.to_json}, #{cancel.to_json}, #{width.to_json}, #{mant.to_json});"
  end

  # Métodos para el manejo del histórico de un modelo

  def histo
    begin
      modulo = params[:modulo] ? params[:modulo].capitalize + '::' : ''
      tab = params[:tabla].singularize.camelize
      modelo = (modulo + tab).constantize # Para cargar los modelos
      modeloh = (modulo + 'H' + tab).constantize # Para ver si existe (si tiene histórico)
    rescue
      render file: '/public/404.html', status: 404, layout: false
      return
    end

    @titulo = 'Histo: ' + modelo.table_name + '/' + params[:id]
    @url_list = '/histo_list?modelo=' + modeloh.to_s + '&id=' + params[:id]
    @url_edit = '/'
    @url_edit << (params[:modulo] ? params[:modulo] + '/': '')
    @url_edit << params[:tabla]
    #render 'shared/histo'
    render html: '', layout: 'histo'
  end

  def histo_list
    mod = params[:modelo].constantize
    mod_tab = mod.table_name

    w = 'idid=' + params[:id]
    tot_records = mod.where(w).size
    lim = params[:rows].to_i
    tot_pages = tot_records / lim
    tot_pages += 1 if tot_records % lim != 0
    page = params[:page].to_i
    page = tot_pages if page > tot_pages
    page = 1 if page <=0


    ord = ''
    sort_elem = params[:sidx].split(',')  #Partimos por ',' así tenemos un vector de campos por los que ordenar
    sort_elem.each{|c|
      c2 = c.split(' ') # Separamos el campo y el tipo de ord (ASC, DESC)
      ord << c2[0]
      ord << (c2[1] ? ' ' + c2[1] : '') + ','
    }
    ord = ord[0..-2] + ' ' + params[:sord] if ord != ''

    sql = mod.where(w).order(ord).offset((page-1)*lim).limit(lim);

    res = {page: page, total: tot_pages, records: tot_records, rows: []}
    sql.each {|s|
      h = {:id => s.id, :cell => []}
      #h[:cell] <<  s.created_at.to_time.to_s[0..-7]
      h[:cell] <<  s.created_at.strftime('%d-%m-%Y %H:%M:%S')
      h[:cell] << s.created_by.try(:codigo)
      res[:rows] << h
    }
    render :json => res
  end

  def sincro_hijos
    id_hijos = params[:hijos] ? eval('{' + params[:hijos] + '}') : {}
    class_mant.hijos.each_with_index {|h, i|
      @ajax << '$(function(){$("#hijo_' + i.to_s + '").attr("src", "/' + h[:url]
      @ajax << '?mod=' + class_modelo.to_s
      @ajax << '&id=' + @fact.id.to_s
      @ajax << '&padre=' + @v.id.to_s
      @ajax << '&eid=' + @dat[:eid].to_s if @dat[:eid]
      @ajax << '&jid=' + @dat[:jid].to_s if @dat[:jid]
      @ajax << "&id_edit=#{id_hijos[h[:url].to_sym]}" if id_hijos[h[:url].to_sym]
      #@ajax << '&prm=' + @dat[:prm]
      @ajax << '");});'
    }
  end

  def sincro_parent
    @dat[:vp].save
    @ajax << 'parent.parent.callFonServer("envia_ficha");'
  end

  def get_empeje
    #emej = cookies[:emej].split(':')
    emej = cookies[Nimbus::CookieEmEj] ? cookies[Nimbus::CookieEmEj].split(':') : ['null', 'null']
    eid = params[:eid]
    eid ||= (emej[0] == 'null' ? nil : emej[0])
    jid = params[:jid]
    jid ||= (emej[1] == 'null' ? nil : emej[1])

    return [eid, jid]
  end

  # Método llamado cuando en la url solo se especifica el nombre de la tabla
  # En general la idea es que la vista asociada sea un grid
  def index
    @ajax = ''

    self.respond_to?('before_index') ? r = before_index : r = true
    unless r
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    clm = class_mant
    mod_tab = clm.table_name

    eid, jid = get_empeje

    if @usu.admin
      prm = 'p'
    else
      #prm = params[:mod] ? params[:prm] : @usu.pref[:permisos] && @usu.pref[:permisos][:ctr] && @usu.pref[:permisos][:ctr][params[:controller]] && @usu.pref[:permisos][:ctr][params[:controller]][eid ? eid.to_i : 0]
      prm = @usu.pref[:permisos] && @usu.pref[:permisos][:ctr] && @usu.pref[:permisos][:ctr][params[:controller]] && @usu.pref[:permisos][:ctr][params[:controller]][eid ? eid.to_i : 0]
      case prm
        when nil
          render file: '/public/401.html', status: 401, layout: false
          return
        when 'c'
          status_botones crear: false
      end
    end

    w = ''
    wemej = ''
    ljoin = ''
    if params[:mod]
      add_where(w, mod_tab + '.' + params[:mod].split(':')[-1].downcase + '_id=' + params[:id])
    else
      if clm.respond_to?('ejercicio_path')
        if jid
          ljoin = clm.ejercicio_path
          wemej = "#{ljoin.empty? ? mod_tab : 't_emej'}.ejercicio_id=#{jid}"
        else
          render file: '/public/no_eje.html', layout: false
          return
        end
      elsif clm.respond_to?('empresa_path')
        if eid
          ljoin = clm.empresa_path
          wemej = "#{ljoin.empty? ? mod_tab : 't_emej'}.empresa_id=#{eid}"
        else
          render file: '/public/no_emp.html', layout: false
          return
        end
      end
    end

    grid = clm.grid.deep_dup
    grid_conf(grid) if self.respond_to?(:grid_conf)

    grid[:cellEdit] = false if prm == 'c'
    grid[:visible] = false if params[:hidegrid]

    add_where(w, grid[:wh]) if grid[:wh]

    @v = Vista.create
    @v.data = {}
    @dat = @v.data
    @dat[:eid] = eid
    @dat[:jid] = jid
    @dat[:auto_comp] = {_pk_input: w} unless w.empty?
    @dat[:wgrid] = w.dup
    add_where(@dat[:wgrid], wemej)
    lj = [grid[:ljoin]]
    lj << ljoin + '(t_emej)' unless ljoin.empty?
    @dat[:cad_join] = ljoin_parse(clm, lj)[:cad]

    @view = {grid: grid}
    @view[:eid] = eid
    @view[:jid] = jid
    @view[:id_edit] = params[:id_edit] ? params[:id_edit] : 0
    @view[:model] = clm.superclass.to_s
    @view[:menu_r] = clm.menu_r
    @view[:menu_l] = clm.menu_l
    @view[:url_base] = '/' + params[:controller] + '/'
    @view[:url_list] = @view[:url_base] + 'list'
    @view[:url_new] = @view[:url_base] + 'new'
    #@view[:arg_edit] = '?head=0' + (@usu.admin ? '' : "&prm=#{prm}")
    @view[:arg_edit] = '?head=0'
    arg_list_new = @view[:arg_edit].clone

    if params[:mod] != nil
      #arg_list_new << '&mod=' + params[:mod] + '&id=' + params[:id] + '&padre=' + params[:padre]
      #@view[:arg_edit] << '&padre=' + params[:padre]
      padre = params[:padre] ? "&padre=#{params[:padre]}" : ''
      arg_list_new << '&mod=' + params[:mod] + '&id=' + params[:id] + padre
      @view[:arg_edit] << padre
    end

    @titulo = ''

    arg_ej = ''
    arg_ej << '&eid=' + eid if eid
    arg_ej << '&jid=' + jid if jid

    if clm.respond_to?('ejercicio_path')
      #cj_ce = Ejercicio.where('ejercicios.id=?', jid).ljoin(:empresa).pluck('ta.codigo', 'ejercicios.codigo')
      #@titulo << cj_ce[0][0] + '/' + cj_ce[0][1]
      @j = Ejercicio.find_by id: jid
      @e = @j.empresa
      @titulo << @e.codigo + '/' + @j.codigo
    elsif clm.to_s != 'EjerciciosMod' and clm.respond_to?('empresa_path')
      #@titulo << Empresa.where('id=?', eid).pluck(:codigo)[0]
      @e = Empresa.find_by id: eid
      @titulo << @e.codigo
    end

    #@view[:arg_auto] = params[:mod] ? '&wh=' + params[:mod].split(':')[-1].downcase + '_id=' + params[:id] : arg_ej
    @view[:arg_auto] = @v ? "&vista=#{@v.id}&cmp=_pk_input" : arg_ej
    @titulo << ' ' + clm.titulo

    @view[:url_list] << arg_list_new + arg_ej + (@v ? "&vista=#{@v.id}" : '')
    @view[:url_new] << arg_list_new + arg_ej
    @view[:arg_edit] << arg_ej

    # Pasar como herencia el argumento especial 'arg'
    if params[:arg]
      @view[:url_new] << '&arg=' + params[:arg]
      @view[:arg_edit] << '&arg=' + params[:arg]
    end

    if params[:hijos]
      @view[:arg_edit] << '&hijos=' + params[:hijos]
    end

    if clm.mant? # No es un proc, y por lo tanto preparamos los datos del grid
      @view[:url_cell] = @view[:url_base] + '/validar_cell'

      #cm = clm.columnas.map{|c| clm.campos[c.to_sym][:grid]}.deep_dup
      @dat[:columnas] = []  # Aquí construimos un array con las columnas visibles para usarlo en el método "list"
      cm = clm.columnas.select{|c| clm.propiedad(c, :visible, binding)}.map{|c| @dat[:columnas] << c; clm.campos[c.to_sym][:grid]}.deep_dup
      cm.each {|h|
        h[:label] = nt(h[:label])
        if h[:edittype] == 'select'
          h[:editoptions][:value].each{|c, v|
            h[:editoptions][:value][c] = nt(v)
          }
        end
      }
      @view[:col_model] = eval_cad(clm.col_model_html(cm))
    end

    @v.save
    @ajax << '_vista=' + @v.id.to_s + ';_controlador="' + params['controller'] + '";'

    pag_render('grid')
  end

  def forma_eager(eager, campo)
    if campo.include?('.')
      tablas = campo.split('.')
      eager << tablas[0]     # Borrar cuando esté tratado el caso de varias tablas
      for i in 0..tablas.size-2
        #eager <<      # Tratar el caso de varias tablas
      end
    end
  end

  # Método para añadir a la cadena 's' el valor 'v' concatenado con 'AND'
  def add_where(s, v)
    if v and v.strip != ''
      s << ' AND ' unless s == ''
      s << v
    end
  end

  # Método que provee de datos a las peticiones del grid
  def list
    # Si la petición no es Ajax... ¡Puerta! (Por razones de seguridad)
    unless request.xhr?
      render json: ''
      return
    end

    clm = class_mant
    #mod_tab = clm.table_name

    #w = (@dat and @dat[:auto_comp] and @dat[:auto_comp][:_pk_input]) ? @dat[:auto_comp][:_pk_input] : ''
    w = @dat[:wgrid] ? @dat[:wgrid] : ''
=begin
    if params[:mod]
      add_where(w, mod_tab + '.' + params[:mod].split(':')[-1].downcase + '_id=' + params[:id])
    else
      if clm.column_names.include?('empresa_id')
        if params[:eid]
          add_where(w, mod_tab + '.empresa_id=' + params[:eid])
        else
          render json: {error: 'no_emp'}
          return
        end
      end
      if clm.column_names.include?('ejercicio_id')
        if params[:jid]
          add_where(w, mod_tab + '.ejercicio_id=' + params[:jid])
        else
          render json: {error: 'no_eje'}
          return
        end
      end
    end
=end

    # Definimos @e y @j por si hay campos que los utilizan algún parámetro (p.ej. :decim)
    @e = Empresa.find_by(id: @dat[:eid]) if @dat[:eid]
    @j = Ejercicio.find_by(id: @dat[:jid]) if @dat[:jid]

    if params[:filters]
      fil = eval(params[:filters])
      fil[:rules].each {|f|
        #[:eq,:ne,:lt,:le,:gt,:ge,:bw,:bn,:in,:ni,:ew,:en,:cn,:nc,:nu,:nn]
        op = f[:op].to_sym

        if op == :nu or op == :nn
          add_where w, f[:field]
          w << ' IS'
          w << ' NOT' if op == :nn
          w << ' NULL'
          next
        end

        ty = f[:field].split('.')
        if ty[-2] == clm.table_name
          ty = clm.campos[ty[-1].to_sym][:type]
        else
          ty = ty[-2].model.columns_hash[ty[-1]].type
        end
        add_where w, ([:bn,:ni,:en,:nc].include?(op) ? 'NOT ' : '') + (ty == :string ? 'UNACCENT(LOWER(' + f[:field] + '))' : f[:field])
        w << ({eq: '=', ne: '<>', cn: ' LIKE ', bw: ' LIKE ', ew: ' LIKE ', nc: ' LIKE ', bn: ' LIKE ', en: ' LIKE ', in: ' IN (', ni: ' IN (', lt: '<', le: '<=', gt: '>', ge: '>='}[op] || '=')
        if op == :in or op == :ni
          f[:data].split(',').each {|d| w << '\'' + I18n.transliterate(d).downcase + '\','}
          w.chop!
          w << ')'
        else
          w << '\''
          w << '%' if [:ew,:en,:cn,:nc].include?(op)
          w << (ty == :string ? I18n.transliterate(f[:data]).downcase : f[:data])
          w << '%' if [:bw,:bn,:cn,:nc].include?(op)
          w << '\''
        end
      }
    end

    eager = []
    sel = ''

    # Mirar si algún campo es de otra tabla para incluirla en la lista de eager-load
    # Componer también la cadena select (con los campos sql)
    #clm.columnas.each{|c|
    @dat[:columnas].each{|c|
      #forma_eager(eager, class_mant.campos[c.to_sym][:grid][:index])
      if c.ends_with?('_id')
        eager << c[0..-4]
      end
      v = clm.campos[c.to_sym]
      if v[:sql]
        sel << '(' + v[:sql][:select] + ') as ' + c + ','
      end
    }
    sel.chop! if sel.ends_with?(',')

    # Formar la cadena de ordenación y seguir incluyendo tablas en eager-load
    #
    ord = ''
    sort_elem = params[:sidx].split(',')  #Partimos por ',' así tenemos un vector de campos por los que ordenar
    sort_elem.each{|c|
      c2 = c.split(' ') # Separamos el campo y el tipo de ord (ASC, DESC)
      #if c2[0].include?('.')
        #c3 = c2[0].split('.')   # Aquí habrá problemas con nietos y dos o más columnas con foreing_key a la misma tabla
        #ord << c3[0].split('_')[0].pluralize + '.' + c3[-1] # Se están ignorando c3[1]...c3[-2]  ¿Qué hacer?
        #forma_eager(eager, c2[0])
      #else
        #ord << mod_tab + '.' + c2[0]  #Anteponemos el nombre de la tabla si no está puesto (para evitar conflictos de mismo nombre de campo en distintas tablas)
      #end
      ord << c2[0]
      ord << (c2[1] ? ' ' + c2[1] : '') + ','
    }
    ord = ord[0..-2] + ' ' + params[:sord] if ord != ''

=begin
    sort = params[:sidx].split('.')
    if sort.size == 1
      sortname = sort[0]
    else
      for i in 0..sort.size-2
        eager << sort[i]  # Hay que añadir el resto cuando son más de un nivel
      end
      sortname = sort[-2].split('_')[0].pluralize + '.' + sort[-1]
    end
    ord = sortname + ' ' + params[:sord]
=end

    #tot_records =  clm.eager_load(eager).where(w).where(params[:wh]).count
    tot_records =  clm.eager_load(eager).joins(@dat[:cad_join]).where(w).count
    lim = params[:rows].to_i
    tot_pages = tot_records / lim
    tot_pages += 1 if tot_records % lim != 0
    page = params[:page].to_i
    page = tot_pages if page > tot_pages
    page = 1 if page <=0

    #sql = clm.eager_load(eager).where(w).where(params[:wh]).order(ord).offset((page-1)*lim).limit(lim)
    sql = clm.eager_load(eager).joins(@dat[:cad_join]).where(w).order(ord).offset((page-1)*lim).limit(lim)

    res = {page: page, total: tot_pages, records: tot_records, rows: []}
    sql.each {|s|
      h = {:id => s.id, :cell => []}
      #clm.columnas.each {|c|
      @dat[:columnas].each {|c|
        begin
          #h[:cell] << forma_campo(:grid, s, c).to_s
          h[:cell] << forma_campo(:grid, s, c, s[c]).to_s
        rescue
          h[:cell] << ''
        end
      }
      res[:rows] << h
    }
    render :json => res
  end

  def pag_render(pag, lay=pag)
    if self.class.nimbus_views
      r = ''
      self.class.nimbus_views[pag.to_sym].each {|v|
        r << "<%= render file: '#{v}' %>"
      }

      render inline: r, layout: lay
    else
      begin
        render action: pag, layout: lay
      rescue
        render html: '', layout: lay
      end
    end
  end

  def var_for_views(clm)
    @titulo = clm.titulo
    @tabs = []
    @on_tabs = []
    @hijos = clm.hijos
    @dialogos = clm.dialogos
    @fact.campos.each{|c, v|
      @tabs << v[:tab] if v[:tab] and !@tabs.include?(v[:tab]) and v[:tab] != 'pre' and v[:tab] != 'post'
    }
    clm.hijos.each{|h|
      @tabs << h[:tab] if h[:tab] and !@tabs.include?(h[:tab]) and h[:tab] != 'pre' and h[:tab] != 'post'
    }
    @tabs.each {|t|
      f = "ontab_#{t}"
      @on_tabs << f if self.respond_to?(f)
    }

    @head = (params[:head] ? params[:head].to_i : 1)
    @menu_l = clm.menu_l
    @menu_r = clm.menu_r

    @es_un_mant = clm.mant?
  end

  def set_empeje(eid=0, jid=0)
    if eid == 0
      @e = @fact.empresa if @fact.respond_to?('empresa')
    else
      @e = eid ? Empresa.find_by(id: eid) : nil
    end

    if jid == 0
      @j = @fact.ejercicio if @fact.respond_to?('ejercicio')
    else
      @j = jid ? Ejercicio.find_by(id: jid) : nil
    end
  end

  def set_parent
    if params[:padre]
      @dat[:vp] = Vista.find(params[:padre].to_i)
      @fact.parent = @dat[:vp].data[:fact]
    end
  end

  def new
    @ajax = ''

    self.respond_to?('before_new') ? r = before_new : r = true
    unless r
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    clm = class_mant

    @v = Vista.create
    @v.data = {}
    @dat = @v.data
    @dat[:persistencia] = {}
    @g = @dat[:persistencia]
    @dat[:fact] = clm.new
    @fact = @dat[:fact]
    @fact.user_id = session[:uid]
    @dat[:head] = params[:head] if params[:head]
    #@fact.respond_to?(:id)  # Solo para inicializar los métodos internos de ActiveRecord ???

    set_parent

    var_for_views(clm)

    eid, jid = get_empeje

    @dat[:eid] = eid
    @dat[:jid] = jid

    if @usu.admin
      @dat[:prm] = 'p'
    else
      #@dat[:prm] = params[:padre] ? params[:prm] : @usu.pref[:permisos][:ctr][params[:controller]] && @usu.pref[:permisos][:ctr][params[:controller]][@dat[:eid] ? @dat[:eid].to_i : 0]
      @dat[:prm] = @usu.pref[:permisos][:ctr][params[:controller]] && @usu.pref[:permisos][:ctr][params[:controller]][@dat[:eid] ? @dat[:eid].to_i : 0]
      if @dat[:prm].nil? or @dat[:prm] == 'c'
        render file: '/public/401.html', status: 401, layout: false
        return
      end
    end

    if params[:mod]
      # Si es un mant hijo, inicializar el id del padre
      eval('@fact.' + params[:mod].split(':')[-1].downcase + '_id=' + params[:id])
    else
      if clm.respond_to?('ejercicio_path')
        if jid.nil?
          render file: '/public/no_eje', layout: false
          return
        else
          @fact.ejercicio_id = jid.to_i if clm.column_names.include?('ejercicio_id')
        end
      elsif clm.respond_to?('empresa_path')
        if eid.nil?
          render file: '/public/no_emp', layout: false
          return
        else
          @fact.empresa_id = eid.to_i if clm.column_names.include?('empresa_id')
        end
      end
    end

    set_empeje(eid, jid)

    @fact.contexto(binding) # Para adecuar los valores dependientes de parámetros (manti, decim, etc.)

    @ajax << '_vista=' + @v.id.to_s + ',_controlador="' + params['controller'] + '",eid="' + eid.to_s + '",jid="' + jid.to_s + '";'

    #Activar botones necesarios (Grabar/Borrar)
    @ajax << 'statusBotones({grabar: true, borrar: false});'

    #before_envia_ficha if self.respond_to?('before_envia_ficha')
    call_nimbus_hook :before_envia_ficha
    envia_ficha

    @v.save

    pag_render('ficha')
  end

  def edith
    clm = class_mant
    #class_modelo  # Para inicializar la clase (forzar el load)
    cls = class_modelo.to_s.split('::')
    clmh = (cls.size == 1 ? 'H' + cls[0] : cls[0] + '::H' + cls[1]).constantize
    fh = clmh.find_by id: params[:id][1..-1]
    if fh.nil?
      render file: '/public/404.html', status: 404, layout: false
      return
    end
    #fo = clmh.where('idid = ?', fh.idid).order(:created_at).first
    fo = clmh.where('idid = ? AND created_at < ?', fh.idid, fh.created_at).order(:created_at).last
    if fo.nil?
      #render file: '/public/404.html', status: 404, layout: false
      #return
      fo = fh
    end
    @fact = clm.new
    dif = ''
    clmh.column_names.each {|c|
      next unless @fact.respond_to?(c)
      #v = fh.method(c).call
      #@fact.method(c + '=').call(v)
      v = fh[c]
      @fact[c] = v
      dif << '$("#' + c + '").addClass("nim-campo-cambiado");' if (v != fo[c])
    }

    set_empeje

    var_for_views(clm)

    @fact.contexto(binding) # Para adecuar los valores dependientes de parámetros (manti, decim, etc.)

    @ajax = ''
    envia_ficha
    @ajax << '$(":input").attr("disabled", true);'
    @ajax << dif
    render html: '', layout: 'ficha'
  end

  def edit
    clm = class_mant

    if clm.mant? and params[:id][0] == 'h'
      edith
      return
    end

    if clm.mant?
      if params[:id] == '0'   # Para mostrar fichas vacías con todo deshabilitado
        @fact = clm.new
        @fact.id = 0
      else
        @fact = clm.find_by id: params[:id]
        if @fact.nil?
          render file: '/public/404.html', status: 404, layout: false
          return
        end
        @fact.user_id = session[:uid]
      end
    else
      @fact = clm.new
    end

    @ajax = ''

    ((!clm.mant? or @fact.id != 0) and self.respond_to?('before_edit')) ? r = before_edit : r = nil
    if r
      if r.is_a? Hash
        if r[:redirect]
          redirect_to r[:redirect]
        else
          render file: r[:file], status: r[:status], layout: false
        end
      else
        render file: r, status: 401, layout: false
      end
      return
    end

    var_for_views(clm)
    #ini_campos if self.respond_to?('ini_campos')
    call_nimbus_hook :ini_campos

    @v = Vista.new
    #@v.save unless clm.mant? and @fact.id == 0
    @v.data = {}
    @dat = @v.data
    @dat[:persistencia] = {}
    @g = @dat[:persistencia]
    @dat[:fact] = @fact
    @dat[:head] = params[:head] if params[:head]

    set_parent

    if clm.mant?
      if @fact.id != 0
        if @fact.respond_to?('empresa')
          @dat[:eid] = @fact.empresa.id
        elsif clm.superclass.to_s == 'Empresa'
          @dat[:eid] = @fact.id
        end

        if @fact.respond_to?('ejercicio')
          @dat[:jid] = @fact.ejercicio.id
        elsif clm.superclass.to_s == 'Empresa'
          @dat[:jid] = @fact.id
        end

        #set_empeje(@dat[:eid], @dat[:jid])
        set_empeje

        #Activar botones necesarios (Grabar/Borrar)
        @ajax << 'statusBotones({grabar: true, borrar: true});'
      else
=begin
        @dat[:eid] = params[:eid]
        @dat[:jid] = params[:jid]

        @e = Empresa.find_by id: params[:eid]
        @j = Ejercicio.find_by id: params[:jid]
=end
        set_empeje(*get_empeje)

        #Activar botones necesarios (Grabar/Borrar)
        @ajax << 'statusBotones({grabar: false, borrar: false});'
      end
    else
      eid, jid = get_empeje

      @dat[:eid] = eid
      @dat[:jid] = jid

      set_empeje(eid, jid)
    end

    # Control de permisos
    @dat[:prm] = 'p'
    unless @usu.admin or params[:controller] == 'gi' or (clm.mant? and @fact.id == 0)
      #@dat[:prm] = params[:padre] ? params[:prm] : @usu.pref[:permisos][:ctr][params[:controller]] && @usu.pref[:permisos][:ctr][params[:controller]][@dat[:eid] ? @dat[:eid].to_i : 0]
      @dat[:prm] = @usu.pref[:permisos][:ctr][params[:controller]] && @usu.pref[:permisos][:ctr][params[:controller]][@dat[:eid] ? @dat[:eid].to_i : 0]
      case @dat[:prm]
        when nil
          render file: '/public/401.html', status: 401, layout: false
          return
        when 'b'
          status_botones borrar: false
        when 'c'
          disable_all
      end
    end

    @fact.contexto(binding) # Para adecuar los valores dependientes de parámetros (manti, decim, etc.)

    @v.save unless clm.mant? and @fact.id == 0

    @ajax << 'eid="' + @dat[:eid].to_s + '",jid="' + @dat[:jid].to_s + '";'
    unless clm.mant? and @fact.id == 0
      @ajax << '_vista=' + @v.id.to_s + ';_controlador="' + params['controller'] + '";'
    end

    #before_envia_ficha if self.respond_to?(:before_envia_ficha)
    call_nimbus_hook :before_envia_ficha

    unless clm.mant? and @fact.id == 0
      envia_ficha
      sincro_hijos if clm.mant?

      @v.save
    end

    r = false
    r = mi_render if self.respond_to?(:mi_render)

    #(clm.mant? ? pag_render('ficha') : pag_render('ficha', 'proc')) unless r
    pag_render('ficha') unless r
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'set_auto_comp_filter(cmp, wh)'}
  # Asocia el filtro where <i>wh</i> al campo <i>cmp</i>. Obviamente, el campo tiene que ser de tipo _id
  ##

  def set_auto_comp_filter(cmp, wh)
    if wh.is_a? Symbol  # En este caso wh es otro campo de @fact
      #v = @fact.method(wh).call
      v = @fact[wh]
      wh = wh.to_s + ' = \'' + (v ? v.to_s : '0') + '\''
    end
    #@ajax << 'set_auto_comp_filter($("#' + cmp.to_s + '"),"' + wh + '");'
    @dat[:auto_comp] ? @dat[:auto_comp][cmp.to_sym] = wh : @dat[:auto_comp] = {cmp.to_sym => wh}
  end

  def _auto(par)
    unless request.xhr? # Si la petición no es Ajax... ¡Puerta! (para evitar accesos desde la barra de direcciones)
      render json: ''
      return
    end

    p = par[:term]
    if p == '-' or p == '--'
      render json: ''
      return
    end

    mod = par[:mod].constantize

    if @dat
      ac = @dat[:auto_comp]
      whv = ac ? ac[par[:cmp].to_sym] : nil
    else
      whv = nil
    end

    if par[:type]
      type = par[:type].to_sym
    else
      type = :form
    end

    data = mod.auto_comp_data

    if mod.respond_to?(:auto_comp_test)
      r = mod.auto_comp_test(p)
    else
      r = nil
    end

    if r.nil?
      if p[0] == '-'
        patron = p[1..-1]
      else
        patron = '%' + p
      end

      if patron[-1] == '-'
        patron = patron[0..-2]
      else
        patron << '%'
      end

      patron.gsub!('.', '%')
      patron.gsub!('"', '\"')
    else
      patron = r
    end

    wh = '('
    data[:campos].each {|c|
=begin
      if mod.columns_hash[c].type == :integer
        begin
          n = Integer(p)
          wh << c + '=' + n.to_s + ' OR '
        rescue
        end
      else
        wh << 'UNACCENT(LOWER(' + c + ')) LIKE \'' + I18n.transliterate(patron).downcase + '\'' + ' OR '
      end
=end
      wh << 'UNACCENT(LOWER(' + c.to_s + ')) LIKE \'' + I18n.transliterate(patron).downcase + '\'' + ' OR '
    }

    wh = wh[0..-5] + ')'

    #wh << ' AND ' + mod.table_name + '.' + 'empresa_id=' + par[:eid] if mod.column_names.include?('empresa_id') and par[:eid]
    #wh << ' AND ' + mod.table_name + '.' + 'ejercicio_id=' + par[:jid] if mod.column_names.include?('ejercicio_id') and par[:jid]
    if mod.respond_to?(:ejercicio_path)
      ep = mod.ejercicio_path
      ep = ep + '.' unless ep.empty?
      ep = ep + 'ejercicio_id'
      msel = mselect_parse(mod, mod.auto_comp_mselect, ep)
      edb = msel[:alias_cmp][ep][:cmp_db]
      wh << " AND #{edb}=#{(par[:jid] || @dat[:jid])}"
    elsif mod.respond_to?(:empresa_path)
      ep = mod.empresa_path
      ep = ep + '.' unless ep.empty?
      ep = ep + 'empresa_id'
      msel = mselect_parse(mod, mod.auto_comp_mselect, ep)
      edb = msel[:alias_cmp][ep][:cmp_db]
      wh << " AND #{edb}=#{(par[:eid] || @dat[:eid])}"
    else
      msel = mselect_parse(mod, mod.auto_comp_mselect)
    end

    mod.select(msel[:cad_sel]).joins(msel[:cad_join]).where(wh).where(whv).order(data[:orden]).limit(15).map {|r|
      {value: r.auto_comp_value(type), id: r[:id], label: r.auto_comp_label(type)}
    }
  end

  def auto
    render json: _auto(params)
  end

  def fact_clone
    #@fant = @fact.respond_to?(:id) ? {id: @fact.id} : {}
    #@fact.campos.each {|c, v| @fant[c] = @fact.method(c).call}
    fant = @fact.respond_to?(:id) ? {id: @fact.id} : {}
    #@fact.campos.each {|c, v| fant[c] = @fact.method(c).call}
    @fact.campos.each {|c, v| fant[c] = @fact[c]}
    @fant = fant.deep_dup
  end

  def forma_campo_id(ref, id, tipo = :form)
    return('') if id.nil? or id == 0 or id == ''

    mod = ref.constantize
    ret = mod.mselect(mod.auto_comp_mselect).where(mod.table_name + '.id=' + id.to_s)[0]
    ret ? ret.auto_comp_value(tipo) : nil
  end

  def forma_campo_axlsx(cp, cmp, val)
    if cmp.ends_with?('_id')
      forma_campo_id(cp[:ref], val, :form)
    elsif cp[:sel]
      (val.class == String) ? cp[:sel][val.to_sym] || cp[:sel][val] : cp[:sel][val]
    else
      Nimbus.nimval(val)
    end
  end

  def _forma_campo(tipo, cp, cmp, val)
=begin
    if cmp.ends_with?('_id')
      if val and val != 0 and val != ''
        ret = forma_campo_id(cp[:ref], val, tipo)
      else
        ret = ''
      end
      return ret
    end
=end

    if val.nil?
      ''
    elsif cmp.ends_with?('_id')
      forma_campo_id(cp[:ref], val, tipo)
    else
      case cp[:type].to_sym
        when :integer
          (cp[:sel]) ? val.to_s : number_with_precision(val, separator: ',', delimiter: '.', precision: 0)
        when :float, :decimal
          (cp[:sel]) ? val.to_s : number_with_precision(val, separator: ',', delimiter: '.', precision: (cp[:decim].is_a?(String) ? eval_cad(cp[:decim]).to_i : cp[:decim] || 2))
        when :date
          tipo == :lgrid ? val : val.to_s(:sp)
        when :time
          val.strftime('%H:%M' + (cp[:seg] ? ':%S' : ''))
        when :datetime
          val.strftime('%d-%m-%Y %H:%M' + (cp[:seg] ? ':%S' : ''))
        else
          if cp[:rol] == :origen
            nt(val)
          else
            val
          end
      end
    end
  end

  def forma_campo(tipo, ficha, cmp, val)
    cp = ficha.respond_to?('campos') ? ficha.campos[cmp.to_sym] : class_mant.campos[cmp.to_sym]
    _forma_campo(tipo, cp, cmp, val)
  end

  def envia_campo(cmp, val)
    cmp_s = cmp.to_s
    cp = @fact.campos[cmp.to_sym]

    return if cp[:img]

    case cp[:type]
    when :boolean
      val = false unless val
      #@ajax << '$("#' + cmp_s + '").prop("checked",' + val.to_s + ');'
      @ajax << "mdlCheck('#{cmp_s}',#{val.to_s});"
    when :div
      if cp[:grid_sel]
        @ajax << "setSelectionGridLocal('#{cmp}', #{@fact[cmp].to_json});"
      end
    when :upload
      # No hacer nada
    else
      @ajax << '$("#' + cmp_s + '").val(' + forma_campo(:form, @fact, cmp_s, val).to_json + ')'
      @ajax << '.attr("dbid",' + val.to_s + ')' if cmp_s.ends_with?('_id') and val
      @ajax << ';'
    end
  end

  def call_on(c, val)
    cs = c.to_sym
    v = @fact.campos[cs]
    hay_on = false
    if self.respond_to?(v[:on].to_s)
      hay_on = true
      val_ant = val.dup rescue val
      method(v[:on]).arity == 0 ? method(v[:on]).call() : method(v[:on]).call(cs)
    end

    fun = ('on_' + c).to_sym
    if self.respond_to?(fun)
      unless hay_on
        val_ant = val.dup rescue val
        hay_on = true
      end
      method(fun).call
    end

    if self.class.nimbus_hooks and self.class.nimbus_hooks[fun]
      unless hay_on
        val_ant = val.dup rescue val
        hay_on = true
      end
      self.class.nimbus_hooks[fun].each {|f|
        method(f).call
      }
    end

    if hay_on
      val = @fact[cs]
      return [val_ant != val, val]
    else
      return [false, val]
    end
  end

  def sincro_ficha(h={})
    vcg = []
    vc = [nil]
    while vc != []
      vc = []
      @fact.campos.each {|cs, ch|
        c = cs.to_s
        if vcg.include?(cs)
          vc.delete_if {|cv| cv[0] == cs}
          next
        end

        v = @fact[cs]
        va = @fant[cs]
        if v != va
          vc << [cs, v]
          vcg << cs

          if v.is_a? HashForGrids
            sincro_grid(cs, v, va) if va
          else
            res, v = call_on(c, v)

            if h[:ajax] and ch[:form] and (res or c != h[:exclude])
              envia_campo(c, v)
            end
          end
        end
      }
      h.delete :exclude
      vc.each {|cv|
        @fant[cv[0]] = cv[1]
      }
    end
  end

  def sincro_grid(cmp, v, va)
    celdas = []
    cambios = true
    while cambios
      cambios = false
      v[:data].each_with_index {|r, i|
        v[:cols].each_with_index {|c, j|
          name = c[:name]
          next if celdas.index{|z| z[0] == r[0] and z[1] == name}
          val = r[j+1]
          if val != va[:data][i][j+1]
            cambios = true
            #celdas << [r[0], name, val]
            celdas << [r[0], name, _forma_campo(:form, c, c[:name], val)]
            fun = "on_#{cmp}_#{name}"
            method(fun).call(r[0], val) if self.respond_to?(fun)
            va[:data][i][j+1] = val
          end
        }
      }
    end
    @ajax << "setDataGridLocal('#{cmp}',#{celdas.to_json});" unless celdas.empty?
  end

  def envia_ficha
    @fact.campos.each {|c, v|
      #envia_campo(c, @fact.method(c.to_s).call) if v[:form]
      envia_campo(c, @fact[c]) if v[:form]
    }
  end

  #### VALIDAR

  def raw_val(c, v)
    cp = @fact.campos[c.to_sym]

    case cp[:type]
      when :integer, :float, :decimal
        return v.gsub('.', '').gsub(',', '.')
      when :string
        return v.upcase if cp[:may]
      when :boolean
        return v == 'true'
    end

    return v
  end

  def procesa_vali(err)
    if err.nil? or err == ''
      @last_error = [nil, :blando]
    elsif err.is_a? String
      @last_error = [err, :duro]
    else  # Se supone que es un hash con dos claves: :msg (con el texto del error) y :tipo (:duro o :blando)
      @last_error = [err[:msg], err[:tipo] || :blando]
    end
  end

  def valida_campo(campo, tipo)
    err = nil
    t1 = t2 = :blando
    fun = 'vali_' << campo

    if self.respond_to?(fun)
      err, t1 = procesa_vali(method(fun).call)
    end

    if @fact.respond_to?(fun)
      e, t2 = procesa_vali(@fact.method(fun).call)
      if e != nil
        if err.nil?
          err = e
        else
          err << '<br>' + e
        end
      end
    end

    (tipo == :duro and t1 == :blando and t2 == :blando) ? nil : err
  end

  def validar_local_cell
    cmp = params[:cmp].to_sym
    row = params[:row]
    col = params[:col]
    val = params[:val]
    if val
      case @fact[cmp].col(col)[:type]
        when :references
          val = val.to_i
        when :integer
          val = val.gsub('.', '').gsub(',', '.').to_i
        when :decimal
          val = val.gsub('.', '').gsub(',', '.').to_d
        when :date
          val = val.to_date
        when :time
          val = val.to_time
        when :boolean
          val = (val == 'true')
      end
    end
    @fact[cmp].data(row, col, val)
    @fant[cmp].data(row, col, val)

    fun = "vali_#{cmp}_#{col}"

    err, t1 = procesa_vali(method(fun).call(row, val)) if self.respond_to?(fun)
    mensaje(err) if err

    fun = "on_#{cmp}_#{col}"
    method(fun).call(row, val) if self.respond_to?(fun)

    @ajax << 'hayCambios=true;'
  end

  def validar_cell
    clm = class_mant
    campo = ''
    valor = ''
    params.each {|p, v|
      next if ['sel', 'id', 'oper', 'controller', 'action', 'nocallback'].include?(p)
      campo = p
      valor = v
      break
    }

    @fact = clm.find_by id: params[:id]
    if @fact.nil?
      render text: nt('errors.messages.record_inex')
      return
    end

    set_parent
    fact_clone

    #@fact.method(campo + '=').call(params[:sel] ? params[:sel] : raw_val(campo, valor))
    @fact[campo] = params[:sel] ? params[:sel] : raw_val(campo, valor)

    err = valida_campo(campo, :all)

    if err.nil?
      if params[:nocallback]
        @fact.update_column(campo, valor)
      else
        if clm.view?
          clmod = class_modelo
          f = clmod.find(@fact.id)
          clmod.column_names.each {|c|
            f.method(c+'=').call(@fact.method(c).call)
          }
          f.save
        else
          @fact.save
        end
      end
      render text: ''
    else
      render text: err
    end
  end

  ##nim-doc {sec: 'Métodos de usuario', met: 'crea_grid(opts)'}
  # <pre>
  # Método para crear un grid dinámicamente
  #
  # opts es un hash con las siguientes claves:
  #
  # cmp: es un campo X definido con {type: :div}
  #
  # modo: (:ed / :sel) indica si el grid es editable o para selección
  #       Por defecto :sel
  #
  #       En el modo edición se pueden definir métodos vali y on para cada
  #       columna. La nomenclatura será vali_campox_columna o on_campox_columna
  #       Ambos métodos recibirán como argumentos el id de la fila y el valor
  #       de la celda correspondiente.
  #
  # sel: (:row / :cel / nil) Sólo válido en modo edición (:ed). Indica si
  #      el servidor es notificado cuando se selecciona una fila nueva o una
  #      celda. Se llamará al método sel_campox que recibirá como argumentos
  #      el id de la fila y el nombre de la columna. Por defecto vale nil
  #
  # del: (true / false) Sólo válido en modo edición (:ed). Indica si
  #      se permiten borrar filas. En caso afirmativo antes del borrado se
  #      llamará al método vali_borra_campox que recibirá como argumento el
  #      id de la fila a borrar y retornará una cadena con un error si no se
  #      permite el borrado o nil si se permite. Si no existe el método se
  #      entiende que se permite borrar cualquier fila sin condiciones.
  #      Por defecto vale true.
  #
  # ins: (:pos / :end / nil|false) Sólo válido en modo edición (:ed). Indica si
  #      se permite la inserción de nuevas filas. El valor :pos indica que
  #      la inserción puede ser posicional (entre dos filas), en este caso no
  #      se permitirá la ordenación por columnas. El valor :end indica que
  #      la inserción sólo se permite al final. Por defecto vale :end.
  #      Cuando se solicite la inserción de una nueva fila se llamará al método
  #      new_campox y recibirá como argumento la posición física donde se
  #      va a insertar la fila. Como valor de retorno debe devolver un array
  #      con los valores de la fila a insertar. Si no existe el método, la
  #      fila se inertará con todas las celdas vacías y con id igual al
  #      máximo de los existentes más uno (o el siguiente en orden alfabético
  #      si los ids son cadenas).
  #
  # search: (true/false) indica si aparece o no por defecto la barra
  #         de búsqueda en el grid. Por defecto vale false.
  #
  # bsearch: (true/false) indica si aparece o no un botón para mostrar/ocultar
  #          la barra de búsqueda en el grid. Por defecto vale false.
  #
  # bcollapse: (true/false) indica si aparece o no un botón para mostrar/ocultar
  #            el grid cmpleto. Por defecto vale false.
  #
  # cols: Es un array de hashes conteniendo información de cada columna.
  #       Las posibles claves del hash de cada columna son:
  #       name: el nombre de la columna. Si una columna es de tipo id
  #             haciendo referencia a otra tabla, su nombre debe acabar por '_id'
  #             y especificar el nombre del modelo con la clave :ref
  #             Si no se especifica :ref se asumirá el nombre de la columna
  #             sin el id. Si se quieren poner filtros a este tipo de campos
  #             se usará el mismo método que para campos normales (set_auto_comp_filter)
  #             con la salvedad de que como nombre de campo le pasaremos:
  #             campox_id_columna (siendo id el 'id' de la fila y 'columna' el
  #             nombre de la columna). Por ejemplo en una fila con id=123 y con una
  #             columna llamada pais_id (haciendo referencia a la tabla de países)
  #             usaríamos set_auto_comp_filter('campox_123_pais_id', 'el_filtro_que_sea')
  #       ref:  Explicada en el apartado anterior. (Sólo válida para campos _id)
  #       label: el título de la columna. Si no existe se usará 'name'
  #       type: el tipo (:boolean, :string, :integer, :decimal, :date, :time)
  #             Si no se especifica se asume string. Los campos de tipo _id no
  #             necesitan tipo explícito (no hace falta usar esta clave)
  #       manti: Sólo para tipos numéricos, indica la mantisa (defecto 7)
  #       signo: Sólo para tipos numéricos, indica si se admiten negativos
  #              Por defecto vale false
  #       dec: Sólo para el type :decimal indica el número de decimales.
  #            Por defecto 2.
  #       align: Posibles valores: 'left', 'center', 'right'
  #              Por defecto se adapta al 'type' por lo que no sería necesario
  #              darle valor, salvo que queramos un comportamiento especial.
  #       width: Anchura de la columna. Por defecto 150.
  #
  #       Cualquier clave admitida por jqGrid en colModel
  #       ver: <a href="http://www.trirand.com/jqgridwiki/doku.php?id=wiki:colmodel_options" target="_blank">colmodel_options</a>
  #
  # grid: Es un hash con opciones específicas para el grid. Admite todas las
  #       referidas en: <a href="http://www.trirand.com/jqgridwiki/doku.php?id=wiki:options" target="_blank">grid_options</a>
  #       Las más interesantes serían:
  #       caption: Es una string con un título para el grid. Añade una barra
  #                de título con dicha string y un botón para colapsar el grid.
  #       height: Indica la altura del grid. Por defecto 150.
  #       hidegrid: (true/false) Establece si aparece o no el botón de colapsar
  #                 Sólo válido si hay caption.
  #       multiselect: (true/false) Permite seleccionar múltiples filas.
  #                    En este caso se añade al grid una primera columna con
  #                    checks para indicar la selección. Por defecto false.
  #       multiSort: (true/false) Permite ordenar por varias columnas.
  #       shrinkToFit: (true/false) Si se pone a true se ajustarán las anchuras
  #                    de las columnas para caber en la anchura del grid. Por
  #                    defecto false.
  #
  # data: Es un array de arrays con los datos (puede ser un array simple si sólo
  #       hay una fila de datos). Cada array contendrá n+1 elementos, donde n es
  #       número de columnas que se han definido en 'cols'. El elemento adicional,
  #       que tiene que ser el primero del array, contendrá el id de la fila.
  #       Este id es el que se devolverá al campo X en caso de que la fila sea
  #       seleccionada.
  #
  # En el caso de que el modo sea :sel (selección sin edición)
  # El método, además de crear el grid, sincroniza la seleción de fila (o filas si
  # está a true la opción multiselect) con el servidor. En el campo X asociado
  # tendremos siempre disponible el id de la fila seleccionada (o un array de ids
  # si hay multiselección). Para acceder lo haremos con @fact.cmp (donde cmp es el
  # campo X referido).
  #
  # En el caso de que el modo sea :ed (edición) La sincronización con el servidor
  # se realiza reflejando en tiempo real el estado de cada celda. Para acceder a
  # los datos usaremos @fact.campox.data(id, col) donde 'id' es el id de la fila y 'col'
  # el nombre de la columna. Para dar valor a una celda usaremos
  # @fact.campox.data(id, col, val) igual que antes más 'val' que es el valor que queremos
  # asignar.
  # Para insertar una nueva fila por código, o bien lo hacemos con el valor de retorno
  # del método new_campox o, si queremos insertar filas en otros métodos tendremos
  # que usar el método grid_add_row(cmp, pos, data) donde cmp es el campox, pos es la
  # posición donde queremos insertar la fila (-1 para insertar por el final) y 'data'
  # un array con los valores de fila a insertar.
  # Igualmente, para borrar una fila por código se puede usar el método grid_del_row(id)
  # donde 'id' es el id de la fila a borrar. Esto sería para borrar filas 'a traición',
  # las filas que borra el usuario y que se nos notifican en vali_borra_campox se borran
  # solas (sin necesidad de usar este método) en el caso de que vali_borra_campox
  # devuelva nil.
  # Para barrer los datos habría que hacer:
  # @fact.campox.each_row {|fila, new, edit, i|
      # 'fila' es un array con los datos de la fila que toque
      # 'ins' es un booleano que indica si la fila es nueva (insertada)
      # 'edit' es un booleano que indica si la fila ha sido editada (alguna de sus celdas)
      # 'i' es el índice de la fila (0,1,2...)
  # }
  #
  # Y para barrer los registros borrados:
  # @fact.campox.each_del {|fila, new, edit, i|
      # 'fila' es un array con los datos de la fila que toque
      # 'ins' es un booleano que indica si la fila es nueva (insertada)
      # 'edit' es un booleano que indica si la fila ha sido editada (alguna de sus celdas)
      # 'i' es el índice de la fila (0,1,2...)
  # }
  # </pre>
  ##

  def crea_grid(opts)
    cmp = opts[:cmp].to_sym
    return unless cmp

    modo = opts[:modo] ? opts[:modo].to_sym : :sel
    opts[:ins] = :end unless opts.key?(:ins)
    opts[:del] = true if opts[:del].nil?

    opts[:add_prop] ||= []

    opts[:cols].each {|c|
      if c[:name].to_s.ends_with?('_id')
        c[:type] = :references
        c[:ref] ||= c[:name][0..-4].capitalize
        opts[:add_prop] << '_' + c[:name]
      end
      c[:searchoptions] ||= {}
      c[:editoptions] ||= {}
      c[:editable] = true if c[:editable].nil?
      c[:sortable] = false if opts[:ins] == :pos
      c[:type] ||= :string
      c[:type] = c[:type].to_sym
      case c[:type]
        when :boolean
          c[:align] ||= 'center'
          #c[:formatter] ||= 'checkbox'
          c[:formatter] ||= '~format_check~'
          c[:unformat] ||= '~unformat_check~'
          c[:editoptions][:value] ||= 'true:false'
          c[:edittype] ||= 'checkbox'
          c[:searchoptions][:sopt] ||= ['eq']
        when :integer, :decimal
          c[:manti] ||= 7
          c[:decim] ||= (c[:type] == :integer ? 0 : 2)
          c[:signo] = false if c[:signo].nil?
          c[:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','in','ni','nu','nn']
          c[:editoptions][:dataInit] ||= "~function(e){numero(e,#{c[:manti]},#{c[:decim]},#{c[:signo]})}~"
          c[:sortfunc] ||= '~sortNumero~'
          c[:align] ||= 'right'
        when :date
          c[:sorttype] ||= 'date'
          c[:formatter] ||= 'date'
          c[:editoptions][:dataInit] ||= '~function(e){date_pick(e)}~'
          c[:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
          #c[:sortfunc] ||= '~sortDate~'
        when :time
          c[:editoptions][:dataInit] ||= '~function(e){$(e).entrytime(' + (c[:seg] ? 'true,' : 'false,') + (c[:nil] ? 'true' : 'false') + ')}~'
          c[:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
        when :references
          #c[:controller] = c[:ref].constantize.table_name
          mt = c[:ref].split('::')
          c[:controller] = (mt.size == 1 ? c[:ref].constantize.table_name : mt[0].downcase + '/' + mt[1].downcase.pluralize)
          c[:editoptions] = {dataInit:  "~function(e){autoCompGridLocal(e,'#{c[:ref]}','#{c[:controller]}','#{cmp}','#{c[:name]}');}~"}
          c[:searchoptions][:sopt] ||= ['cn','eq','bw','ew','nc','ne','bn','en','lt','le','gt','ge','in','ni','nu','nn']
        when :text
          c[:edittype] ||= 'textarea'
          c[:searchoptions][:sopt] ||= ['cn','eq','bw','ew','nc','ne','bn','en','lt','le','gt','ge','in','ni','nu','nn']
        else
          if c[:sel]
            c[:formatter] ||= 'select'
            c[:edittype] ||= 'select'
            c[:editoptions][:value] ||= c[:sel]
            c[:align] ||= 'center'
            c[:searchoptions][:sopt] ||= ['eq', 'ne', 'in', 'ni', 'nu', 'nn']
          else
            c[:searchoptions][:sopt] ||= ['cn','eq','bw','ew','nc','ne','bn','en','lt','le','gt','ge','in','ni','nu','nn']
          end
      end
    }

    data = opts[:data]
    data_grid = []
    if data and not data.empty?
      data = [data] unless data[0].class == Array
      opts.delete(:data)
      data.each {|r|
        h = {id: r[0]}
        opts[:cols].each_with_index {|c, i|
          h[c[:name]] = _forma_campo(:lgrid, c, c[:name], r[i+1])
          h['_' + c[:name]] = r[i+1] if c[:name].ends_with?('_id')
        }
        data_grid << h
      }
    end

    @ajax << "creaGridLocal(#{opts.to_json.gsub('"~', '').gsub('~"', '')}, #{data_grid.to_json});"

    @fact.campos[cmp][:grid_emb] = {opts: opts, data: data} if opts[:export]
    case modo
      when :ed
        @fact[cmp] = HashForGrids.new(opts[:cols], data)
        @fant[cmp] = nil if @fant
      else
        #@fact[cmp] = nil
        #@fant[cmp] = nil if @fant
        @fact.campos[cmp][:grid_sel] = true
        @ajax << "setSelectionGridLocal('#{cmp}', #{@fact[cmp].to_json});"
    end
  end

  # Método para añadir filas a un grid existente
  #
  # cmp: Es el campo X sobre el que está creado el grid
  #
  # data: Es un array de arrays con los datos (puede ser un array simple si sólo
  #       hay una fila de datos). Cada array contendrá n+1 elementos, donde n es
  #       número de columnas que se han definido en 'cols'. El elemento adicional,
  #       que tiene que ser el primero del array, contendrá el id de la fila.
  #       Este id es el que se devolverá al campo X en caso de que la fila sea
  #       seleccionada.

  def add_data_grid(cmp, data)
    data = [data] unless data[0].class == Array
    @ajax << "addDataGridLocal('#{cmp}', #{data.to_json});"
  end

  def del_data_grid(cmp, id)
    @ajax << "delDataGridLocal('#{cmp}', #{id});"
  end

  def grid_local_ed_select
    fun = "sel_#{params[:cmp]}"
    self.method(fun).call(params[:row], params[:col]) if self.respond_to?(fun)
  end

  def grid_add_row(cmp, pos, data)
    cmp = cmp.to_sym
    h = {}
    @fact[cmp][:cols].each_with_index {|c, i|
      h[c[:name]] = _forma_campo(:form, c, c[:name], data[i + 1])
      h['_' + c[:name]] = data[i + 1] if c[:name].ends_with?('_id')
    }
    @ajax << "$('#g_#{cmp}').jqGrid('addRowData','#{data[0]}',#{h.to_json}"
    @ajax << ",'before',#{@fact[cmp][:data][pos][0]}" if pos >= 0
    @ajax << ");"

    @ajax << "$('##{cmp} .ui-jqgrid-bdiv').scrollTop(1000000);" if pos == -1

    @fact[cmp].add_row(pos, data)
    @fant[cmp].add_row(pos, data) if @fant
  end

  def grid_local_ins
    cmp = params[:cmp].to_sym
    pos = params[:pos].to_i

    fun = "new_#{cmp}"
    if self.respond_to?(fun)
      data = self.method(fun).call(pos)
      return if data.nil? or data.empty?
    else
      data = [@fact[cmp].max_id.next]
    end

    grid_add_row(cmp, pos, data)
  end

  def grid_del_row(cmp, row)
    cmp = cmp.to_sym
    #@ajax << "$('#g_#{cmp}').jqGrid('delRowData','#{row}');"
    @ajax << "$('#g_#{cmp}').jqGrid('delRowData','#{row}');"
    # Las dos líneas que siguen son para apañar un bug de jqGrid al borrar la ultima línea de datos
    #@ajax << "$('#g_#{cmp}').jqGrid('resetSelection');"
    @ajax << "$('#g_#{cmp}').trigger('reloadGrid', [{current:true}]);"

    @fact[cmp].del_row(row)
    @fant[cmp].del_row(row) if @fant
  end

  def grid_local_del
    cmp = params[:cmp].to_sym
    row = params[:row]

    fun = "vali_borra_#{cmp}"
    if self.respond_to?(fun)
      res = self.method(fun).call(row)
      if res
        mensaje res
        return
      end
    end
    grid_del_row(params[:cmp], row = params[:row])
  end

  def grid_local_select
    campo = params[:cmp]
    if params[:multi]
      if params[:row] == ''
        #@fact.method(campo + '=').call(nil)
        @fact[campo] = nil
      elsif params[:row].is_a? Array
        #@fact.method(campo + '=').call(params[:row].map{|c| c.to_i})
        @fact[campo] = params[:row].map{|c| c.to_i}
      else
        row = params[:row].to_i
        sel = (params[:sel] == 'true')
        #v = @fact.method(campo).call
        v = @fact[campo]
        if v
          if v.is_a? Array
            sel ? v << row : v.delete_at(v.index(row))
          else
            @fact[campo] = sel ? [v, row] : nil
          end
        else
          #@fact.method(campo + '=').call([row]) if sel
          @fact[campo] = [row] if sel
        end
      end
    else
      #@fact.method(campo + '=').call(params[:row].to_i)
      @fact[campo] = params[:row].to_i
    end

    fun = "sel_#{campo}"
    self.method(fun).call(params[:row]) if self.respond_to?(fun)
  end

  # Método para calcular dos arrays: uno de estilos y otro de tipos
  # Para usar en exportaciones a excel
  # Es llamado en la exportación de grids embebidos (un poco más abajo)
  # y desde el controlador de 'bus'

  def array_estilos_tipos_axlsx(cols, wb)
    lsty = {
      d: wb.styles.add_style({format_code: 'dd-mm-yyyy'}),
      t: wb.styles.add_style({format_code: 'HH:MM:SS'}),
      dt: wb.styles.add_style({format_code: 'dd-mm-yyyy HH:MM:SS'}),
      i: wb.styles.add_style({format_code: '#,##0'})
    }
    sty = []
    typ = []
    cols.each {|c|
      case c[:type].to_sym
        when :string
          typ << :string
          sty << nil
        when :date
          typ << :date
          sty << lsty[:d]
        when :time
          typ << :time
          sty << lsty[:t]
        when :datetime
          typ << :time
          sty << lsty[:dt]
        when :integer
          typ << nil
          sty << lsty[:i]
        when :decimal
          typ << nil
          dec = c[:decim] || 2
          lsty[dec] = wb.styles.add_style({format_code: "#,##0.#{'0'*dec}"}) unless lsty[dec]
          sty << lsty[dec]
        else
          typ << nil
          sty << nil
      end
    }

    [sty, typ]
  end

  def grid_local_export
    return unless @v

    cmp = params[:cmp].to_sym
    cols = @fact.campos[cmp][:grid_emb][:opts][:cols]
    data = @fact.campos[cmp][:grid_emb][:data]
    nc = cols.size

    xls = Axlsx::Package.new
    wb = xls.workbook
    sh = wb.add_worksheet(:name => "Hoja1")

    sty, typ = array_estilos_tipos_axlsx(cols, wb)

    # Primera fila (Cabecera)
    sh.add_row(cols.map {|v| v[:label] || v[:name]})

    #data.each {|r| sh.add_row(r[1..nc].map.with_index {|d, i| cols[i][:ref] ? forma_campo_id(cols[i][:ref], d) : d})}
    data.each {|r| sh.add_row(r[1..nc].map.with_index {|d, i| forma_campo_axlsx(cols[i], cols[i][:name], d)}, types: typ, style: sty)}

    # Fijar la fila de cabecera para repetir en cada página
    wb.add_defined_name("Hoja1!$1:$1", :local_sheet_id => sh.index, :name => '_xlnm.Print_Titles')

    file_name = "/tmp/nim#{@v.id}.xlsx"
    xls.serialize(file_name)
    @ajax << "window.location.href='/nim_download';"
    flash[:file] = file_name
    flash[:file_cli] = @fact.campos[cmp][:grid_emb][:opts][:export] + '.xlsx'
    flash[:rm] = true
  end

  def get_fact_from_marshal
    @fact = @dat[:fact]

    # La siguiente línea es muy importante. No sé cuales son los motivos exactos
    # pero es necesaria para que la clase a la que pertenece @fact se inicialice correctamente
    # cuando el request es tratado por un nuevo worker (puma) que no ha usado aún dicha clase.
    # Aunque la clase está cargada (en production todas las clases están cargadas), parece que
    # algo interno no está activado hasta que no se hace un new por primera vez.
    # No es algo habitual (en development o en production con un solo worker no se necesitaría nunca),
    # pero en production, con varios workers en paralelo podrían darse errores aleatorios si no está
    # esta línea. Así que.... NO QUITARLA AUNQUE PAREZCA ESTÚPIDA.
    @fact.class.new
  end

  def validar
    clm = class_mant

    #@dat = $h[params[:vista].to_i]
    get_fact_from_marshal
    @g = @dat[:persistencia]
    fact_clone

    @ajax = ''

    campo = params[:campo]
    cs = @fact.campos[campo.to_sym]
    valor = params[:valor]

    if cs[:img]
      if valor == '*' # Es un borrado de imagen
        @fact[campo] = '*'
        render js: "$('##{campo}_img').attr('src','');"
      else # Es una asignación de imagen que viene del submit del form asociado. La respuesta va al iframe asociado al campo imagen
        return unless params[campo] # Por si llega un submit sin fichero para upload

        @fact[campo] = "/tmp/nimImg-#{@v.id}-#{campo}.#{params[campo].tempfile.path.split('.')[1]}"
        `cp #{params[campo].tempfile.path} #{@fact[campo]}`
        render html: %Q(
          <script>
            $(window).load(function(){$("##{campo}_img",parent.document).attr('src', '/nim_send_file?file=#{params[campo].tempfile.path}')})
          </script>
        ).html_safe, layout: 'basico'
      end

      @v.save
      return
    end

    if campo.ends_with?('_id') and params[:src] # Autocompletado sin id elegido (probable introducción rápida de texto)
      par = {term: valor}
      CGI::parse(URI::parse(params[:src]).query).each {|k, v| par[k.to_sym] = v[0]}
      res = _auto(par)
      #if res.size == 1  # Se ha encontrado un registro único
      if res.size > 0  # Se ha encontrado algún registro
        valor = res[0][:id]
        @ajax << "$('##{campo}').val(#{res[0][:value].to_json}).attr('dbid',#{valor});"
      else
        valor = ''
        @ajax << "$('##{campo}').val('').attr('dbid',null);"
      end
    end

    if cs[:type] == :upload
      self.method("on_#{campo}").call(params[campo]) if self.respond_to?("on_#{campo}")
      valor = nil
    else
      @fact[campo] = raw_val(campo, valor)
      valor = @fact[campo].dup rescue @fact[campo]
    end

    ## Validación

    err = valida_campo(campo, :all)

    if err.nil?
      @ajax << '$("#' + campo + '").removeClass("ui-state-error");'
    else
      @ajax << '$("#' + campo + '").focus();'
      @ajax << '$("#' + campo + '").addClass("ui-state-error");'
      #@ajax << 'alert(' + err.to_json + ');' if err != ''
      mensaje(err)
    end

    if @fact[campo] == valor
      sincro_ficha :ajax => true, :exclude => campo
    else
      sincro_ficha :ajax => true
    end

    @ajax << 'hayCambios=' + @fact.changed?.to_s + ';' if clm.mant?

    if cs[:type] == :upload
      # Si el tipo es upload el render se realiza en el iframe asociado y por lo tanto
      # para procesar @ajax hay que que hacerlo en el ámbito de su padre (la ficha)
      render html: %Q(
          <script>
            $(window).load(function(){window.parent.eval(#{@ajax.to_json});})
          </script>
        ).html_safe, layout: 'basico'
    else
      render :js => @ajax
    end

    @v.save
  end

  def fon_server
    unless params[:fon] && self.respond_to?(params[:fon])
      #render nothing: true
      head :no_content
      return
    end

    @ajax = ''
    if params[:vista]
      @g = @dat[:persistencia]
      if @dat[:fact]
        get_fact_from_marshal
        fact_clone
      end
    end
    method(params[:fon]).call
    sincro_ficha :ajax => true if @fact
    begin
      render js: @ajax
    rescue
    end
=begin
    begin
      render nothing: true  # Por si no existe el método o por si éste no hace un render explícito
    rescue
    end
=end
    @v.save if @v
  end

  def pinta_exception(e, msg=nil)
    logger.fatal '######## ERROR #############'
    logger.fatal e.message
    logger.fatal e.backtrace[0..10]
    logger.fatal '############################'
    mensaje(msg) if msg
  end

  def borrar
    if @dat[:prm] != 'p'
      #render nothing: true
      head :no_content
      return
    end

    @ajax = ''

    get_fact_from_marshal
    @g = @dat[:persistencia]
    err = vali_borra if self.respond_to?('vali_borra')
    if err
      mensaje err
    else
      class_mant.view? ? class_modelo.destroy(@fact.id) : @fact.destroy

      # Borrar los datos asociados
      `rm -rf data/#{class_modelo}/#{@fact.id}`

      grid_reload
      @ajax << "window.location.replace('/' + _controlador + '/0/edit?head=#{@dat[:head]}');"
    end

    render js: @ajax
    @v.save
  end

  #### GRABAR

  def grabar(ajx=true)
    if @dat[:prm] == 'c'
      #render nothing: true
      head :no_content
      return
    end

    clm = class_mant
    get_fact_from_marshal
    @g = @dat[:persistencia]
    fact_clone
    err = ''
    @ajax = ''
    last_c = nil
    begin
      cmps_img = [] # Crear un vector con los campos de imagen modificados
      @fact.campos.each {|cs, v|
        c = cs.to_s

        cmps_img << cs if v[:img] && @fact[c]

        if v[:type] == :div
          e = nil
          valor = @fact[c]
          if valor.is_a? HashForGrids
            valor[:data].each {|r|
              valor[:cols].each_with_index {|col, i|
                fun = "vali_#{c}_#{col[:name]}"
                er, t = procesa_vali(method(fun).call(r[0], r[i+1])) if self.respond_to?(fun)
                err << '<br>' + er if t == :duro
              }
            }
          end
        else
          if v[:req]
            valor = @fact[c]
            (valor.nil? or ([:string, :text].include?(v[:type]) and not c.ends_with?('_id') and valor.strip == '')) ? e = "Campo #{nt(v[:label])} requerido" : e = nil
          else
            e = nil
          end
          e = valida_campo(c, :duro) unless e
        end

        if e != nil
          err << '<br>' + e
          @ajax << '$("#' + c + '").addClass("ui-state-error");' if v[:form]
          last_c = c
        end
      }

      if err == ''
        err = vali_save if self.respond_to?('vali_save')
        err ||= ''
      end

      if err == ''
        call_nimbus_hook :before_save

        if clm.view?
          clmod = class_modelo
          if (@fact.id)
            f = clmod.find(@fact.id)
          else
            f = clmod.new
          end
          clmod.column_names.each {|c|
            #f.method(c+'=').call(@fact.method(c).call)
            f[c] = @fact[c]
          }
          f.user_id = @fact.user_id
          f.save
          @fact.id = f.id
        else
            @fact.save if @fact.respond_to?('save') # El if es por los 'procs' (que no tienen modelo subyacente)
        end

        # Tratar campos imagen
        cmps_img.each {|c|
          v = @fact.campos[c][:img]
          path = "data/#{v[:modelo]}/#{@fact.id}/_imgs"

          # Borrar imágenes previas
          `rm -f #{path}/#{v[:tag]}.*`

          unless @fact[c] == '*' # el valor asterisco es borrar la imagen, cosa que se ha hecho en la línea anterior
            ia = @fact[c].split('.')
            FileUtils.mkdir_p(path)
            `mv #{@fact[c]} #{path}/#{v[:tag]}.#{ia[1]}`
          end

          @fact[c] = nil
        }

        if clm.mant?
          #Refrescar el grid si procede
          grid_reload

          if @dat[:grabar_y_alta] or params[:_new] # Entrar en una ficha nueva después de grabar
            @ajax << "parent.newFicha(#{@fact.id});"
          else
            sincro_hijos if @fant[:id].nil?

            #Activar botones necesarios (Grabar/Borrar)
            @ajax << 'statusBotones({borrar: true});'
          end
        end

        begin
          call_nimbus_hook :after_save
        rescue Exception => e
          pinta_exception(e, 'Error: after_save')
        end

        @ajax << 'hayCambios=false;'
      else
        @ajax << '$("#' + last_c + '").focus();' if last_c
        mensaje tit: 'Errores en el registro', msg: err
      end
    rescue ActiveRecord::RecordNotUnique
      mensaje 'Grabación cancelada. Ya existe la clave'
    rescue Exception => e
      pinta_exception(e, 'Error interno')
    end

    sincro_ficha :ajax => true

    @v.save

    render :js => @ajax if ajx
  end

  # Método para hacer una grabación de @fact manual y con las acciones oportunas
  def grabar_manual
    id = @fact.id
    @fact.save
    sincro_hijos unless id
    grid_reload
    @ajax << 'statusBotones({borrar: true});'
    @ajax << 'hayCambios=false;'
  end

  # Método para destruir una vista cuando se abandona la página

  def destroy_vista
    sql_exe("DELETE FROM vistas where id = #{params[:vista]}")
    # Borrar todas las imágenes temporales que queden
    `rm -f /tmp/nimImg-#{params[:vista]}-*`
    #render nothing: true
    head :no_content
  end

  def bus_call
    get_fact_from_marshal

    cmp = (params[:cmpid] ? params[:cmpid] : params[:id]).to_sym
    if params[:cmp] # Casos de campos (columnas) de grids editables
      v = @fact[params[:cmp]].col(params[:col])
    else  # Casos de campos normales de mantenimientos
      v = @fact.campos[cmp]
    end

    flash[:mod] = v[:ref].to_s
    flash[:ctr] = params[:controller]
    flash[:ctr] += "_#{params[:col]}" if params[:col]
    flash[:eid] = @dat[:eid]
    flash[:jid] = @dat[:jid]
    flash[:wh] = @dat[:auto_comp][cmp] if @dat[:auto_comp] and @dat[:auto_comp][cmp]
    flash[:pref] = v[:bus] if v[:bus]

    @ajax << 'var w = window.open("/bus", "_blank", "width=700, height=500"); w._autoCompField = bus_input_selected;'
  end

  def bus_call_pk
    flash[:mod] = class_modelo.to_s
    flash[:ctr] = params[:controller]
    flash[:eid] = @dat[:eid]
    flash[:jid] = @dat[:jid]
    flash[:wh] = @dat[:auto_comp][:_pk_input] if @dat[:auto_comp] and @dat[:auto_comp][:_pk_input]

    @ajax << 'var w = window.open("/bus", "_blank", "width=700, height=500"); w._autoCompField = "mant";'
  end

  def gen_form(h={})
    clm = class_mant

    sal = ''
    prim = true
    tab_dlg = h[:tab] ? :tab : :dlg

    @fact.campos.each{|c, v|
      cs = c.to_s
      #next if v[:tab].nil? or v[:tab] != h[:tab]
      next if v[tab_dlg].nil? or v[tab_dlg] != h[tab_dlg] or !v[:visible]

      #ro = eval_cad(v[:ro])
      #manti = eval_cad(v[:manti]).to_i
      #decim = eval_cad(v[:decim]).to_i
      ro = v[:ro]
      manti = v[:manti]
      decim = v[:decim]
      if v[:size]
        size = v[:size].to_s
      elsif v[:type] == :integer or v[:type] == :decimal
        size = (manti + decim + manti/3 + 1).to_s
      else
        size = manti.to_s
      end
      manti = manti.to_s

=begin
      rows = eval_cad(v[:rows])
      sel = eval_cad(v[:sel])

      if v[:code]
        code = eval_cad(v[:code])
        code_pref = eval_cad(code[:prefijo])
        code_rell = eval_cad(code[:relleno])
      end
=end

      plus = ''
      if ro == :all or ro == params[:action].to_sym or v[:rol] == :origen
        if cs.ends_with?('_id') or v[:rol]
          plus << ' readonly tabindex=-1'
        else
          plus << ' disabled'
        end
      end

      plus << " title='#{nt(v[:title])}'" if v[:title] and ![:boolean, :upload].include?(v[:type])
      plus << " #{v[:attr]}" if v[:attr]

      sal << '</div>' unless prim or v[:span] # Cerrar el div mdl-cell si procede

      sal << '</div>' if !prim && !v[:span] && (v[:hr] || v[:br]) # Cerrar el div mdl-grid si procede

      if v[:hr]
        case v[:hr].class.to_s
          when 'String'
            sal << "<div id='hr-#{c}' class='nim-hr-div'><label class='nim-hr-label'>#{nt(v[:hr])}</label><hr></div>"
          when 'Hash'
            sal << "<div id='hr-#{c}' class='#{v[:hr][:class_div] ? v[:hr][:class_div] : 'nim-hr-div'}'><label class='#{v[:hr][:class_label] ? v[:hr][:class_label] : 'nim-hr-label'}'>#{nt(v[:hr][:label])}</label><hr></div>"
          else
            sal << "<hr id='hr-#{c}'>"
        end
      end

      sal << '<div class="mdl-grid">' if prim || !v[:span] && (v[:hr] || v[:br])
      sal << '<br>' if v[:span] and v[:inline] and v[:br]
=begin
      if prim or v[:hr] or v[:br]
        sal << '</div>' unless prim # Cerrar el div mdl-grid si procede
        sal << '<hr>' if v[:hr]
        sal << '<div class="mdl-grid">'
        prim = false
      end
=end

      div_class = v[:span] ? 'nim-group-span' : 'nim-group'
      div_class << '-inline' if v[:inline]

      #sal << '<div class="mdl-cell mdl-cell--' + v[:gcols].to_s + '-col">' if prim or !v[:span]
      if prim or !v[:span]
        sal << (v[:gcols] == 0 ? '<div style="display: none">' : "<div class='mdl-cell mdl-cell--#{v[:gcols]}-col #{v[:class]}'>")
      end

      prim = false

      if v[:type] == :boolean
        sal << "<div class='#{div_class}' title='#{nt(v[:title])}'>"
        sal << '<label class="mdl-checkbox mdl-js-checkbox mdl-js-ripple-effect" for="' + cs + '">'
        sal << '<input id="' + cs + '" type="checkbox" class="mdl-checkbox__input" onchange="vali_check($(this))"' + plus + '/>'
        sal << '<span class="mdl-checkbox__label">' + nt(v[:label]) + '</span>'
        sal << '</label>'
        sal << '</div>'
      elsif v[:type] == :text
        sal << '<div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">'
        sal << '<textarea class="nim-textarea mdl-textfield__input" type="text" id="' + cs + '" cols=' + size + ' rows=' + v[:rows].to_s + ' onchange="validar($(this))"' + plus + '>'
        sal << '</textarea>'
        sal << '<label class="mdl-textfield__label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
=begin
        sal << '<div class="nim-group">'
        sal << '<textarea id="' + cs + '" cols=' + size + ' rows=' + rows.to_s + ' required onchange="validar($(this))"' + plus + '>'
        sal << '</textarea>'
        sal << '<label class="nim-label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
=end
      elsif v[:code]
        #sal << '<div class="nim-group">'
        sal << "<div class='#{div_class}'>"
        #sal << '<input class="nim-input" id="' + cs + '" maxlength=' + size + ' onchange="vali_code($(this),' + manti + ',\'' + code_pref + '\',\'' + code_rell + '\')" required style="max-width: ' + size + 'em"' + plus + '/>'
        sal << '<input class="nim-input" id="' + cs + '" maxlength=' + size + ' onchange="vali_code($(this),' + manti + ',\'' + v[:code][:prefijo] + '\',\'' + v[:code][:relleno] + '\')" required style="max-width: ' + size + 'em"' + plus + '/>'
        sal << '<label class="nim-label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
      elsif v[:sel]
        #sal << '<div class="nim-group">'
        sal << "<div class='#{div_class}'>"
        sal << '<select class="nim-select" id="' + cs + '" required onchange="validar($(this))"' + plus + '>'
        v[:sel].each{|k, tex|
          sal << '<option value="' + k.to_s + '">' + nt(tex) + '</option>'
        }
        sal << '</select>'
        sal << '<label class="nim-label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
      elsif cs.ends_with?('_id')
        #sal << '<div class="nim-group">'
        sal << "<div class='#{div_class}'>"
        sal << '<input class="nim-input" id="' + cs + '" required style="max-width: ' + size + 'em"'
        sal << ' menu="N"' if v.include?(:menu) and !v[:menu]
        sal << ' dialogo="' + h[:dlg] + '"' if h[:dlg]
        sal << " go='go_#{cs}'" if self.respond_to?('go_' + cs)
        sal << " new='new_#{cs}'" if self.respond_to?('new_' + cs)
        sal << plus + '/>'
        sal << '<label class="nim-label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
      elsif v[:type] == :div
        sal << "<div id='#{cs}' style='overflow: auto'></div>"
      elsif v[:img]
        if v[:img][:fon_id]
          plus << ' disabled' unless plus.include?(' disabled')
          img_id = method(v[:img][:fon_id]).call
        else
          img_id = @fact.id == 0 ? nil : @fact.id
        end
        sal << '<div style="text-align: left;overflow: auto">'
        sal << view_context.form_tag("/#{params[:controller]}/validar?vista=#{@v.id}&campo=#{cs}", multipart: true, target: "#{cs}_iframe")
        sal << "<input id='#{cs}' name='#{cs}' type='file' accept='image/*' class='nim-input-img' onchange='$(this).parent().submit()' #{plus}/>"
        sal << "<label class='nim-label-img' for='#{cs}'>#{nt(v[:label])}</label><br>"
        sal << "<img id='#{cs}_img'"
        #if img_id
        #  src = Dir.glob("data/#{v[:img][:modelo]}/#{img_id}/_imgs/#{v[:img][:tag]}.*")
        #  sal << "src='/nim_send_file?file=#{src[0][5..-1]}'" if src.size > 0
        #end
        sal << nim_path_image(v[:img][:modelo], img_id, v[:img][:tag])
        sal << " width=#{v[:img][:width]}" if v[:img][:width]
        sal << " height=#{v[:img][:height]}" if v[:img][:height]
        #sal << '></label>'
        sal << '></form>'
        sal << "<iframe name='#{cs}_iframe' style='display: none'></iframe>"
        sal << '</div>'
      elsif v[:type] == :upload
        if !clm.mant? or @fact.id != 0
          sal << "<div title='#{nt(v[:title])}'>"
          sal << view_context.form_tag("/#{params[:controller]}/validar?vista=#{@v.id}&campo=#{cs}", multipart: true, target: "#{cs}_iframe")
          sal << "<input id='#{cs}_input' name='#{cs + (v[:multi] ? '[]' : '')}' #{v[:multi] ? 'multiple' : ''} type='file' class='nim-input-img'} onchange='$(this).parent().submit()' #{plus}/>"
          sal << "<label id='#{cs}' class='nim-label-upload' for='#{cs}_input'>#{nt(v[:label])}</label><br>"
          sal << '</form>'
          sal << "<iframe name='#{cs}_iframe' style='display: none'></iframe>"
          sal << '</div>'
        end
      else
        clase = 'nim-input'
        case v[:rol]
          when :origen
            clase << ' nim-input-origen'
          when :email
            clase << ' nim-input-email'
          when :url
            clase << ' nim-input-url'
          when :map
            clase << ' nim-input-map'
            v[:map] ||= cs
            plus << " map='nim-map-#{v[:map]}'"
        end
        clase << " nim-map-#{v[:map]}" if v[:map]
        clase << ' nim-may' if v[:may]

        #sal << '<div class="nim-group">'
        sal << "<div class='#{div_class}'>"
        #sal << '<input class="nim-input nim_input_email' + (v[:may] ? ' nim-may' : '') + '" id="' + cs + '" required onchange="validar($(this))" style="max-width: ' + size + 'em"'
        sal << '<input class="' + clase + '" id="' + cs + '" required onchange="validar($(this))" style="max-width: ' + size + 'em"'
        sal << ' maxlength=' + size if v[:type] == :string
        sal << plus + '/>'
        sal << '<label class="nim-label" for="' + cs + '">' + nt(v[:label]) + '</label>'
        sal << '</div>'
      end

      #sal << '</div>' # Fin de <div class="mdl-cell">
    }
    sal << '</div>' if sal != ''   # Fin de <div class="mdl-cell">
    sal << '</div>' if sal != ''   # Fin de <div class="mdl-grid">

    sal.html_safe
  end

  def gen_js
    return unless @v  # Si no hay vista no generar nada (históricos)

    clm = class_mant
    sal = ''

    if clm.mant? and @fact.id == 0
      sal << '$(":input").attr("disabled", true);'
      sal << '$("#_d-input-pk_").css("display", "block");'
      sal << '$("#_input-pk_").attr("disabled", false);'
      return sal.html_safe
    end

    @fact.campos.each{|c, v|
      next unless v[:form] and v[:visible] and !v[:img]

      if block_given?
        plus = yield(c)
      else
        plus = ''
      end

      next if plus == 'stop'

=begin
      manti = eval_cad(v[:manti]).to_i
      decim = eval_cad(v[:decim]).to_i
      signo = eval_cad(v[:signo])
      mask = eval_cad(v[:mask])
      date_opts = eval_cad(v[:date_opts])
      ro = eval_cad(v[:ro])
=end

      cs = c.to_s
      if cs.ends_with?('_id')
        sal << 'auto_comp("#' + cs + '","/application/auto?mod=' + v[:ref]
        sal << '&type=' + v[:auto_tipo].to_s if v[:auto_tipo]
        sal << '&eid=' + @e.id.to_s if @e
        sal << '&jid=' + @j.id.to_s if @j
        sal << '&vista=' + @v.id.to_s
        sal << '&cmp=' + cs
        sal << '","' + v[:ref]
        #sal << '","' + v[:ref].constantize.table_name + '");'
        mt = v[:ref].split('::')
        sal << '","' + (mt.size == 1 ? v[:ref].constantize.table_name : mt[0].downcase + '/' + mt[1].downcase.pluralize) + '");'
      elsif v[:mask]
        sal << '$("#' + cs + '").mask("' + v[:mask] + '",{placeholder: " "});'
        #sal << 'mask({elem: "#' + cs + '", mask:"' + mask + '"'
        #sal << ', may:' + may.to_s if may
        #sal << '});'
      elsif v[:type] == :date
        #sal << 'date_pick("#' + cs + '",' + (date_opts == {} ? '{showOn: "button"}' : date_opts.to_json) + ');'
        sal << 'date_pick("#' + cs + '",' + v[:date_opts].to_json + ');'
        sal << "$('##{cs}').datepicker('disable');" if v[:ro] == :all or v[:ro] == params[:action].to_sym
      elsif v[:type] == :time
        sal << '$("#' + cs + '").entrytime(' + (v[:seg] ? 'true,' : 'false,') + (v[:nil] ? 'true);' : 'false);')
      elsif (v[:type] == :integer or v[:type] == :decimal) and !v[:sel]
        #sal << "numero('##{cs}',#{manti},#{decim},#{signo});"
        sal << "numero('##{cs}',#{v[:manti]},#{v[:decim]},#{v[:signo]});"
      end
    }

    sal.html_safe
  end

  helper_method :gen_form
  helper_method :gen_js
  helper_method :nim_path_image
end
