SESSION_EXPIRATION_TIME = 30.minutes

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  include ActionView::Helpers::NumberHelper

  before_action :ini_controller

  def sesion_invalida
    @usu = Usuario.find_by id: session[:uid]
    return true if @usu.nil? or session[:fec] < @usu.password_fec_mod
    fex = @usu.timeout.nil? ? SESSION_EXPIRATION_TIME : @usu.timeout.minutes
    fex != 0 and session[:fem].to_time + fex < Time.now
  end

  def ini_controller
    if sesion_invalida
      session[:uid] = nil
      if request.xhr? # Si la petición es Ajax...
        case params[:action]
        when 'noticias'
          render js: 'session_out();'
        when 'auto'
          render json: [{error: 1}]
        when 'list'
          render json: {error: 'no_session'}
        when 'validar'
          @fact = $h[params[:vista].to_i][:fact]
          c = params[:campo]
          v = @fact.method(c).call
          @ajax =  'alert(js_t("no_session"));'
          envia_campo(c, v)
          render js: @ajax
        else
          render js: 'alert(js_t("no_session"))'
        end
      else
        render file: '/public/401.html', status: 401, layout: false
      end
    end

    session[:fem] = Time.now unless params[:action] == 'noticias'    #Actualizar fecha de último uso
    I18n.locale = session[:locale]
  end

=begin
  # Elegir layout

  layout :choose_layout

  def choose_layout
    params[:lay].nil? ? 'application' : params[:lay]
  end
=end

  $h = {}

  # Clase del modelo ampliado para este mantenimiento (con campos X etc.)
  def class_mant
    (self.class.to_s[0..-11] + 'Mod').constantize
  end

  # Clase del modelo original
  def class_modelo
    class_mant.superclass
  end

  def noticias
    render js: ''
  end

  # Funciones para interactuar con el cliente

  def mensaje(h)
    h = {msg: h} if h.is_a? String
    h[:tit] ||= nt('aviso')
    h[:bot] ||= []
    h[:close] = true if h[:close].nil?

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
  end

  def enable(c)
    if class_mant.campos[c.to_sym][:type] == :date
      @ajax << '$("#' + c.to_s + '").datepicker("enable");'
    else
      @ajax << '$("#' + c.to_s + '").attr("disabled", false);'
    end
  end

  def disable(c)
    if class_mant.campos[c.to_sym][:type] == :date
      @ajax << '$("#' + c.to_s + '").datepicker("disable");'
    else
      @ajax << '$("#' + c.to_s + '").attr("disabled", true);'
    end
  end

  # Métodos para hacer visibles/invisibles campos. El argumento collapse a true hará
  # que desaparezca el elemento y su hueco, acomodándose el resto de elementos al
  # nuevo layout. Por el contrario si vale false el elemento desaparece
  # pero el hueco continúa

  def visible(c)
    @ajax << "$('##{c}').parent().css('display', 'block').parent().css('display', 'block');"
  end

  def invisible(c, collapse=false)
    @ajax << "$('##{c}').parent().#{collapse ? 'parent().' : ''}css('display', 'none');"
  end

  def foco(c)
    @ajax << '$("#' + c.to_s + '").focus();'
  end

  def abre_dialogo(diag)
    @ajax << "$('##{diag}').dialog('open');"
  end

  def cierra_dialogo(diag)
    @ajax << "$('##{diag}').dialog('close');"
  end

  def edita_ficha(id)
    @ajax << "window.open('/#{params[:controller]}/#{id}/edit', '_self');"
  end

  def open_url(url)
    @ajax << "window.open('#{url}', '_blank');"
  end

  # Actualiza el contenido del grid
  def grid_reload
    @ajax << 'parentGridReload();'
  end

  # Muestra el grid
  def grid_show
    @ajax << 'parentGridShow();'
  end

  # Oculta el grid
  def grid_hide
    @ajax << 'parentGridHide();'
  end

  # Funciones para el manejo del histórico de un modelo
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
      h[:cell] <<  s.created_at.to_time.to_s[0..-7]
      h[:cell] << s.created_by.codigo
      res[:rows] << h
    }
    render :json => res
  end

  def sincro_hijos(vid)
    class_mant.hijos.each_with_index {|h, i|
      @ajax << '$(function(){$("#hijo_' + i.to_s + '").attr("src", "/' + h[:url]
      @ajax << '?mod=' + class_modelo.to_s
      @ajax << '&id=' + @fact.id.to_s
      @ajax << '&padre=' + vid.to_s
      #@ajax << '&eid=' + params[:eid] if params[:eid]
      #@ajax << '&jid=' + params[:jid] if params[:jid]
      @ajax << '&eid=' + $h[vid][:eid].to_s if $h[vid][:eid]
      @ajax << '&jid=' + $h[vid][:jid].to_s if $h[vid][:jid]
      @ajax << '");});'
    }
  end

  def get_empeje
    emej = cookies[:emej].split(':')
    eid = params[:eid]
    eid ||= (emej[0] == 'null' ? nil : emej[0])
    jid = params[:jid]
    jid ||= (emej[1] == 'null' ? nil : emej[1])

    return [eid, jid]
  end

  # Método llamado cuando en la url solo se especifica el nombre de la tabla
  # En general la idea es que la vista asociada sea un grid
  def index
    self.respond_to?('before_index') ? r = before_index : r = true
    unless r
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    clm = class_mant

    eid, jid = get_empeje

    unless params[:mod]
      if clm.column_names.include?('empresa_id') and eid.nil?
        render file: '/public/no_emp.html', layout: false
        return
      elsif clm.column_names.include?('ejercicio_id') and jid.nil?
        render file: '/public/no_eje.html', layout: false
        return
      end
    end

    if self.respond_to?(:grid_conf)
      grid = clm.grid.deep_dup
      grid_conf(grid)
    else
      grid = clm.grid
    end
    @view = {grid: grid}
    @view[:eid] = eid
    @view[:jid] = jid
    @view[:model] = clm.superclass.to_s
    @view[:menu_r] = clm.menu_r
    @view[:menu_l] = clm.menu_l
    @view[:url_base] = '/' + params[:controller] + '/'
    @view[:url_list] = @view[:url_base] + 'list'
    @view[:url_new] = @view[:url_base] + 'new'
    @view[:arg_edit] = '?head=0'
    arg_list_new = '?head=0'

    if params[:mod] != nil
      arg_list_new << '&mod=' + params[:mod] + '&id=' + params[:id] + '&padre=' + params[:padre]
      @view[:arg_edit] << '&padre=' + params[:padre]
    end

    @titulo = ''

    arg_ej = ''
    if eid
      arg_ej << '&eid=' + eid
      e = Empresa.find_by id: eid.to_i
      @titulo << e.codigo if clm.column_names.include?('empresa_id')
    end

    if jid
      arg_ej << '&jid=' + jid
      j = Ejercicio.find_by id: jid.to_i
      @titulo << '/' + j.codigo if clm.column_names.include?('ejercicio_id')
    end

    @view[:arg_auto] = params[:mod] ? '&wh=' + params[:mod].split(':')[-1].downcase + '_id=' + params[:id] : arg_ej
    @titulo << ' ' + clm.titulo

    @view[:url_list] << arg_list_new + arg_ej
    @view[:url_new] << arg_list_new + arg_ej
    @view[:arg_edit] << arg_ej

    # Pasar como herencia el argumento especial 'arg'
    if params[:arg]
      @view[:url_new] << '&arg=' + params[:arg]
      @view[:arg_edit] << '&arg=' + params[:arg]
    end

    if clm.mant? # No es un proc, y por lo tanto preparamos los datos del grid
      @view[:url_cell] = @view[:url_base] + '/validar_cell'

      cm = clm.col_model.deep_dup
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
    s << ' AND ' unless s == ''
    s << v
  end

  # Método que provee de datos a las peticiones del grid
  def list
    # Si la petición no es Ajax... ¡Puerta! (Por razones de seguridad)
    unless request.xhr?
      render json: ''
      return
    end

    clm = class_mant
    mod_tab = clm.table_name

    # El 'to_i.to_s' es para evitar SQL injection
    w = ''
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
        ty = ty[-2].model.columns_hash[ty[-1]].type
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
    clm.columnas.each{|c|
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

    #tot_records = clm.select(:id).ljoin(eager.map{|j| j.to_sym}).where(w).size
    tot_records =  clm.eager_load(eager).where(w).where(params[:wh]).count
    lim = params[:rows].to_i
    tot_pages = tot_records / lim
    tot_pages += 1 if tot_records % lim != 0
    page = params[:page].to_i
    page = tot_pages if page > tot_pages
    page = 1 if page <=0

    sql = clm.eager_load(eager).where(w).where(params[:wh]).order(ord).offset((page-1)*lim).limit(lim)

    res = {page: page, total: tot_pages, records: tot_records, rows: []}
    sql.each {|s|
      h = {:id => s.id, :cell => []}
      clm.columnas.each {|c|
        begin
          h[:cell] << forma_campo(:grid, s, c).to_s
        rescue
          h[:cell] << ''
        end
      }
      res[:rows] << h
    }
    render :json => res
  end

  def pag_render(pag)
    begin
      render action: pag, layout: pag
    rescue
      render html: '', layout: pag
    end
  end

  def var_for_views(clm)
    @titulo = clm.titulo
    @tabs = []
    @hijos = clm.hijos
    @dialogos = clm.dialogos
    @fact.campos.each{|c, v|
      @tabs << v[:tab] if v[:tab] and !@tabs.include?(v[:tab]) and v[:tab] != 'pre' and v[:tab] != 'post'
    }
    clm.hijos.each{|h|
      @tabs << h[:tab] if h[:tab] and !@tabs.include?(h[:tab]) and h[:tab] != 'pre' and h[:tab] != 'post'
    }
    @head = (params[:head] ? params[:head].to_i : 1)
  end

  def set_empeje(eid=0, jid=0)
    if eid == 0
      @e = @fact.empresa if @fact.respond_to?('empresa')
    else
      @e = Empresa.find_by id: eid
    end

    if eid == 0
      @j = @fact.ejercicio if @fact.respond_to?('ejercicio')
    else
      @j = Ejercicio.find_by id: jid
    end
  end

  def new
    self.respond_to?('before_new') ? r = before_new : r = true
    unless r
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    clm = class_mant

    if params[:vista]
      v = Vista.new
      v.id = params[:vista].to_i
    else
      v = Vista.create
      $h[v.id] = {}
    end

    @dat = $h[v.id]
    @fact = @dat[:fact] = clm.new
    @fact.user_id = session[:uid]
    @fact.respond_to?(:id)  # Solo para inicializar los métodos internos de ActiveRecord

    @fact.parent = $h[params[:padre].to_i][:fact] unless params[:padre].nil?

    var_for_views(clm)

    eid, jid = get_empeje

    @dat[:eid] = eid
    @dat[:jid] = jid

    if params[:mod]
      # Si es un mant hijo, inicializar el id del padre
      eval('@fact.' + params[:mod].split(':')[-1].downcase + '_id=' + params[:id])
    else
      if clm.column_names.include?('empresa_id')
        if eid.nil?
          render file: '/public/no_emp', layout: false
          return
        else
          @fact.empresa_id = eid.to_i
        end
      elsif clm.column_names.include?('ejercicio_id')
        if jid.nil?
          render file: '/public/no_eje', layout: false
          return
        else
          @fact.ejercicio_id = jid.to_i
        end
      end
    end

    set_empeje(eid, jid)

    @ajax = 'var _vista=' + v.id.to_s + ',_controlador="' + params['controller'] + '",eid="' + eid.to_s + '",jid="' + jid.to_s + '";'
    #Activar botones necesarios (Grabar/Borrar)
    @ajax << 'statusBotones({grabar: true, borrar: false});'

    before_envia_ficha if self.respond_to?('before_envia_ficha')
    envia_ficha

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
    fo = clmh.where('idid = ?', fh.idid).order(:created_at).first
    if fo.nil?
      render file: '/public/404.html', status: 404, layout: false
      return
    end
    @fact = clm.new
    dif = ''
    clmh.column_names.each {|c|
      next unless @fact.respond_to?(c)
      v = fh.method(c).call
      @fact.method(c + '=').call(v)
      #dif << '$("#' + c + '").css("background-color", "Bisque");' if ( v != fo.method(c).call)
      dif << '$("#' + c + '").addClass("nim-campo-cambiado");' if ( v != fo.method(c).call)
    }

    set_empeje

    var_for_views(clm)
    
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
    end

    ((!clm.mant? or @fact.id != 0) and self.respond_to?('before_edit')) ? r = before_edit : r = nil
    if r
      render file: r, status: 401, layout: false
      return
    end

    if not clm.mant?
      @fact = clm.new
    end

    var_for_views(clm)
    ini_campos if self.respond_to?('ini_campos')

    if params[:vista]
      v = Vista.new
      v.id = params[:vista].to_i
    else
      v = Vista.create
      $h[v.id] = {}
    end

    @vid = v.id
    @dat = $h[v.id]
    @dat[:fact] = @fact
    @dat[:head] = params[:head] if params[:head]

    @fact.parent = $h[params[:padre].to_i][:fact] unless params[:padre].nil?

    @ajax = 'var _vista=' + v.id.to_s + ';var _controlador="' + params['controller'] + '";'

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

        sincro_hijos(v.id)

        set_empeje(@dat[:eid], @dat[:jid])

        #Activar botones necesarios (Grabar/Borrar)
        @ajax << 'statusBotones({grabar: true, borrar: true});'
      else
        @dat[:eid] = params[:eid]
        @dat[:jid] = params[:jid]

        @e = Empresa.find_by id: params[:eid]
        @j = Ejercicio.find_by id: params[:jid]

        #Activar botones necesarios (Grabar/Borrar)
        @ajax << 'statusBotones({grabar: false, borrar: false});'
      end
    else
      eid, jid = get_empeje

      @dat[:eid] = eid
      @dat[:jid] = jid

      set_empeje(eid, jid)
    end

    @ajax += 'var eid="' + @dat[:eid].to_s + '",jid="' + @dat[:jid].to_s + '";'

    before_envia_ficha if self.respond_to?('before_envia_ficha')
    envia_ficha

    #pag_render('ficha') if clm.mant?
    clm.mant? ? pag_render('ficha') : pag_render('proc')
  end

  def set_auto_comp_filter(cmp, wh)
    if wh.is_a? Symbol  # En este caso wh es otro campo de @fact
      v = @fact.method(wh).call
      wh = wh.to_s + ' = \'' + (v ? v.to_s : '0') + '\''
    end
    @ajax << 'set_auto_comp_filter($("#' + cmp.to_s + '"),"' + wh + '");'
  end

  def auto
    unless request.xhr? # Si la petición no es Ajax... ¡Puerta! (para evitar accesos desde la barra de direcciones)
      render json: ''
      return
    end

    p = params[:term]
    if p == '-' or p == '--'
      render json: ''
      return
    end

    mod = params[:mod].constantize

    if params[:type]
      type = params[:type].to_sym
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

    res = []
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
      wh << 'UNACCENT(LOWER(' + c + ')) LIKE \'' + I18n.transliterate(patron).downcase + '\'' + ' OR '
    }

    wh = wh[0..-5] + ')'
    wh << ' AND ' + mod.table_name + '.' + 'empresa_id=' + params[:eid] if mod.column_names.include?('empresa_id') and params[:eid]
    wh << ' AND ' + mod.table_name + '.' + 'ejercicio_id=' + params[:jid] if mod.column_names.include?('ejercicio_id') and params[:jid]

    mod.mselect(mod.auto_comp_mselect).where(params[:wh]).where(wh).order(data[:orden]).limit(15).each {|r|
      res << {value: r.auto_comp_value(type), id: r[:id], label: r.auto_comp_label(type)}
    }

    render :json => res
  end

  def fact_clone
    @fant = @fact.respond_to?(:id) ? {id: @fact.id} : {}
    @fact.campos.each {|c, v| @fant[c] = @fact.method(c).call}
  end

  def forma_campo(tipo, ficha, cmp, val={})
    cp = ficha.respond_to?('campos') ? ficha.campos[cmp.to_sym] : class_mant.campos[cmp.to_sym]
    if cmp.ends_with?('_id')
      id = ficha.method(cmp).call
      if id and id != 0 and id != ''
        #if class_modelo.attribute_names.include?(cmp)
          #val = {}
          #cmpr = cmp[0..-4] + ".auto_comp_value(:#{tipo})"
          mod = cp[:ref].constantize
          val = mod.mselect(mod.auto_comp_mselect).where(mod.table_name + '.id=' + id.to_s)[0].auto_comp_value(tipo)
        #else
        #  val =  cp[:ref].constantize.find(id.to_i).method('auto_comp_value').call(tipo)
        #end
      else
        val = nil
      end
    else
      cmpr = cmp
    end

    if val == {}
      begin
        val = eval('ficha.' + cmpr)
      rescue
        val = nil
      end
    end

    if val.nil?
      return ''
    else
      case cp[:type]
      when :integer, :float, :decimal
        return number_with_precision(val, separator: ',', delimiter: '.', precision: cp[:decim])
      when :date
        return val.to_s(:sp)
      when :time
        return val.strftime('%H:%M' + (cp[:seg] ? ':%S' : ''))
      else
        return val
      end
    end
  end

  def envia_campo(cmp, val)
    cmp_s = cmp.to_s
    cp = @fact.campos[cmp.to_sym]

    case cp[:type]
    when :boolean
      val = false unless val
      @ajax << '$("#' + cmp_s + '").prop("checked",' + val.to_s + ');'
    else
      @ajax << '$("#' + cmp_s + '").val(' + forma_campo(:form, @fact, cmp_s, val).to_json + ')'
      @ajax << '.attr("dbid",' + val.to_s + ')' if cmp_s.ends_with?('_id') and val
      @ajax << ';'
    end
  end

  def call_on(c)
    fun = 'on_' << c
    if self.respond_to?(fun)
      method(fun).call
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

        v = @fact.method(cs).call
        va = @fant[cs]
        if v != va
          vc << [cs, v]
          vcg << cs

          if h[:ajax] and c != h[:exclude] and ch[:form]
            envia_campo(c, v)
          end

          call_on(c)
        end
      }
      vc.each {|cv|
        #c = cv[0] + '='
        #@fant.method(c).call(cv[1]) if @fant.respond_to?(c)
        @fant[cv[0]] = cv[1]
      }
    end
  end

  def envia_ficha
    @fact.campos.each {|c, v|
      envia_campo(c, @fact.method(c.to_s).call) if v[:form]
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
    end

    return v
  end

  def procesa_vali(err)
    if err.nil? or err == ''
      return [nil, :blando]
    elsif err.is_a? String
      return [err, :duro]
    else  # Se supone que es un hash con dos claves: :msg (con el texto del error) y :tipo (:duro o :blando)
      return [err[:msg], err[:tipo] || :blando]
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

    @fact.parent = $h[params[:padre].to_i][:fact] unless params[:padre].nil?
    fact_clone

    @fact.method(campo + '=').call(params[:sel] ? params[:sel] : raw_val(campo, valor))

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

  def validar
    clm = class_mant

    @dat = $h[params[:vista].to_i]
    @fact = @dat[:fact]
    fact_clone

    campo = params[:campo]
    valor = params[:valor]

    @fact.method(campo + '=').call(raw_val(campo, valor))

    ## Validación

    err = valida_campo(campo, :all)

    @ajax = ''

    if err.nil?
      @ajax << '$("#' + campo + '").removeClass("ui-state-error");'
    else
      @ajax << '$("#' + campo + '").focus();'
      @ajax << '$("#' + campo + '").addClass("ui-state-error");'
      #@ajax << 'alert(' + err.to_json + ');' if err != ''
      mensaje(err)
    end

    sincro_ficha :ajax => true, :exclude => campo

    @ajax << 'hayCambios=' + @fact.changed?.to_s + ';' if clm.mant?

    render :js => @ajax
  end

  #Función para ser llamada desde el botón aceptar de los 'procs'
  def fon_server
    @ajax = ''
    if params[:vista]
      @dat = $h[params[:vista].to_i]
      @fact = @dat[:fact]
      fact_clone if @fact
    end
    method(params[:fon]).call if self.respond_to?(params[:fon])
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
  end

  #### CANCELAR

  def cancelar
=begin
    envia_ficha
    render :js => @ajax
=end
    render js: ''
  end

  def borrar
    @dat = $h[params[:vista].to_i]
    @fact = @dat[:fact]
    @fact.destroy
    render js: ''
  end

  #### GRABAR

  def grabar
    clm = class_mant
    vid = params[:vista].to_i
    @dat = $h[vid]
    @fact = @dat[:fact]
    fact_clone
    err = ''
    @ajax = ''
    last_c = nil
    @fact.campos.each {|cs, v|
      c = cs.to_s

      if v[:req]
        valor = @fact.method(c).call
        (valor.nil? or ([:string, :text].include?(v[:type]) and not c.ends_with?('_id') and valor.strip == '')) ? e = "Campo #{c} requerido" : e = nil
      else
        e = valida_campo(c, :duro)
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
      before_save if self.respond_to?('before_save')
      if clm.view?
        clmod = class_modelo
        if (@fact.id)
          f = clmod.find(@fact.id)
        else
          f = clmod.new
        end
        clmod.column_names.each {|c|
          f.method(c+'=').call(@fact.method(c).call)
        }
        f.save
      else
        begin
          @fact.save if @fact.respond_to?('save') # El if es por los 'procs' (que no tienen modelo subyacente)
        rescue Exception => e
          puts e
          @ajax = ''
          sincro_ficha :ajax => true
          mensaje 'Grabación cancelada. Ya existe la clave'
          render :js => @ajax
          return
        end
      end
      after_save if self.respond_to?('after_save')

      if clm.mant?
        sincro_hijos(vid) if @fant[:id].nil?

        #Refrescar el grid si procede
        grid_reload

        #Activar botones necesarios (Grabar/Borrar)
        @ajax << 'statusBotones({borrar: true});'
      end

      @ajax << 'hayCambios=false;'
    else
      @ajax << '$("#' + last_c + '").focus();' if last_c
      #@ajax << 'alert(' + err.to_json + ');'
      mensaje tit: 'Errores en el registro', msg: err
    end

    sincro_ficha :ajax => true

    render :js => @ajax
  end

  def bus_call()
    @dat = $h[params[:vista].to_i]
    @fact = @dat[:fact]
    cmp = @fact.campos[params[:id].to_sym]

    flash[:mod] = cmp[:ref].to_s
    flash[:ctr] = params[:controller]
    flash[:eid] = @dat[:eid]
    flash[:jid] = @dat[:jid]
    flash[:pref] = cmp[:bus] if cmp[:bus]

    @ajax << 'var w = window.open("/bus", "_blank", "width=700, height=500"); w._autoCompField = bus_input_selected;'
  end

  def eval_cad(cad)
    cad.is_a?(String) ? eval('%~' + cad.gsub('~', '\~') + '~') : cad
  end

  def gen_form(h={})
    clm = class_mant

    sal = ''
    ncols = 0
    prim = true
    tab_dlg = h[:tab] ? :tab : :dlg

    @fact.campos.each{|c, v|
      cs = c.to_s
      #next if v[:tab].nil? or v[:tab] != h[:tab]
      next if v[tab_dlg].nil? or v[tab_dlg] != h[tab_dlg]

      ro = eval_cad(v[:ro])
      manti = eval_cad(v[:manti])
      decim = eval_cad(v[:decim])
      if v[:size]
        size = v[:size].to_s
      elsif v[:type] == :integer or v[:type] == :decimal
        size = (manti + decim + manti/3 + 1).to_s
      else
        size = manti.to_s
      end
      manti = manti.to_s
      rows = eval_cad(v[:rows])
      sel = eval_cad(v[:sel])
      if v[:code]
        code = eval_cad(v[:code])
        code_pref = eval_cad(code[:prefijo])
        code_rell = eval_cad(code[:relleno])
      end

      plus = ''
      plus << ' disabled' if ro == :all or ro == params[:action].to_sym

      if prim or v[:hr] or v[:br]
        sal << '</div>' unless prim
        sal << '<hr>' if v[:hr]
        sal << '<div class="mdl-grid">'
        ncols = 0
        prim = false
      end

      ncols += v[:gcols]

      sal << '<div class="mdl-cell mdl-cell--' + v[:gcols].to_s + '-col">'

      if v[:type] == :boolean
        sal << '<label class="mdl-checkbox mdl-js-checkbox mdl-js-ripple-effect" for="' + cs + '">'
        sal << '<input id="' + cs + '" type="checkbox" class="mdl-checkbox__input" onchange="vali_check($(this))" ' + plus + '/>'
        sal << '<span class="mdl-checkbox__label">' + nt(v[:label]) + '</span>'
        sal << '</label>'
      elsif v[:type] == :text
        sal << '<div class="mdl-textfield mdl-js-textfield mdl-textfield--floating-label">'
        sal << '<textarea class="nim-textarea mdl-textfield__input" type="text" id="' + cs + '" cols=' + size + ' rows=' + rows.to_s + ' onchange="validar($(this))" ' + plus + '>'
        sal << '</textarea>'
        sal << '<label class="mdl-textfield__label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
=begin
        sal << '<div class="nim-group">'
        sal << '<textarea id="' + cs + '" cols=' + size + ' rows=' + rows.to_s + ' required onchange="validar($(this))" ' + plus + '>'
        sal << '</textarea>'
        sal << '<label class="nim-label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
=end
      elsif v[:code]
        sal << '<div class="nim-group">'
        sal << '<input class="nim-input" id="' + cs + '" maxlength=' + size + ' onchange="vali_code($(this),' + manti + ',\'' + code_pref + '\',\'' + code_rell + '\')" required style="max-width: ' + size + 'em" ' + plus + '/>'
        sal << '<label class="nim-label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
      elsif sel
        sal << '<div class="nim-group">'
        sal << '<select class="nim-select" id="' + cs + '" required onchange="validar($(this))" ' + plus + '>'
        sel.each{|k, tex|
          sal << '<option value="' + k.to_s + '">' + nt(tex) + '</option>'
        }
        sal << '</select>'
        sal << '<label class="nim-label">' + nt(v[:label]) + '</label>'
        sal << '</div>'
      elsif cs.ends_with?('_id')
        sal << '<div class="nim-group">'
        #sal << '<input id="' + cs + '" size=' + v[:size].to_s + ' required ' + plus + '/>'
        sal << '<input class="nim-input" id="' + cs + '" required style="max-width: ' + size + 'em" ' + plus + '/>'
        sal << '<label class="nim-label">' + nt(v[:label]) + '</label>'
=begin
        sal << '<button id="_acb_' + cs + '" class="nim-autocomp-button mdl-button mdl-js-button mdl-button--icon" style="position: absolute;top: -8px; right: 0">'
        sal << '<i class="material-icons">more_vert</i>'
        sal << '</button>'
        sal << '<ul class="mdl-menu mdl-menu--bottom-right mdl-js-menu mdl-js-ripple-effect" for="_acb_' + cs + '">'
        sal << '<li class="mdl-menu__item">Buscar</li>'
        sal << '<li class="mdl-menu__item">Ir a</li>'
        sal << '</ul>'
=end
        sal << '</div>'
      else
        sal << '<div class="nim-group">'
        #sal << '<input id="' + cs + '" size=' + size + ' required onchange="validar($(this))"'
        sal << '<input class="nim-input' + (v[:may] ? ' nim-may' : '') + '" id="' + cs + '" required onchange="validar($(this))" style="max-width: ' + size + 'em"'
        sal << ' maxlength=' + size if v[:type] == :string
        sal << ' ' + plus + '/>'
        sal << '<label class="nim-label" for="' + cs + '">' + nt(v[:label]) + '</label>'
        sal << '</div>'
      end

      sal << '</div>'
    }
    sal << '</div>' if sal != ''   # Fin de <div class="mdl-grid">

    sal.html_safe
  end

  def gen_js
    clm = class_mant
    sal = ''

    if clm.mant? and @fact.id == 0
      sal << '$(":input").attr("disabled", true);'
      sal << '$("#_d-input-pk_").css("display", "block");'
      sal << '$("#_input-pk_").attr("disabled", false);'
      return sal.html_safe
    end

    @fact.campos.each{|c, v|
      next unless v[:form]

      if block_given?
        plus = yield(c)
      else
        plus = ''
      end

      next if plus == 'stop'

      manti = eval_cad(v[:manti]).to_s
      decim = eval_cad(v[:decim])
      signo = eval_cad(v[:signo])
      mask = eval_cad(v[:mask])
      date_opts = eval_cad(v[:date_opts])
      ro = eval_cad(v[:ro])

      cs = c.to_s
      if cs.ends_with?('_id')
        sal << 'auto_comp("#' + cs + '","/application/auto?mod=' + v[:ref]
        sal << '&eid=' + @e.id.to_s if @e
        sal << '&jid=' + @j.id.to_s if @j
        sal << '","' + v[:ref]
        sal << '","' + v[:ref].constantize.table_name + '");'
      elsif mask
        sal << '$("#' + cs + '").mask("' + mask + '",{placeholder: " "});'
        #sal << 'mask({elem: "#' + cs + '", mask:"' + mask + '"'
        #sal << ', may:' + may.to_s if may
        #sal << '});'
      elsif v[:type] == :date
        sal << 'date_pick("#' + cs + '",' + (date_opts == {} ? '{showOn: "button"}' : date_opts.to_json) + ');'
        sal << "$('##{cs}').datepicker('disable');" if ro == :all or ro == params[:action].to_sym
      elsif v[:type] == :time
        sal << '$("#' + cs + '").entrytime(' + (v[:seg] ? 'true,' : 'false,') + (v[:nil] ? 'true);' : 'false);')
      elsif v[:type] == :integer or v[:type] == :decimal
        sal << 'numero("#' + cs + '",' + manti + ',' + decim.to_s + ',' + signo.to_s + ');'
      end
    }

    sal.html_safe
  end

  helper_method :gen_form
  helper_method :gen_js
end
