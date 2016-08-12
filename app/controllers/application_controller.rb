SESSION_EXPIRATION_TIME = 30.minutes

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  include ActionView::Helpers::NumberHelper

  before_action :ini_controller
  skip_before_action :ini_controller, only: [:destroy_vista]

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
          #render json: [{error: 1}]
          render json: [{error: 'no_session'}]
        when 'list'
          render json: {error: 'no_session'}
        when 'validar'
          #@fact = $h[params[:vista].to_i][:fact]
          #c = params[:campo]
          #v = @fact.method(c).call
          @ajax =  'alert(js_t("no_session"));'
          #envia_campo(c, v)
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
    if @fact and @fact.campos[c.to_sym] and @fact.campos[c.to_sym][:type] == :date
      @ajax << '$("#' + c.to_s + '").datepicker("enable");'
    else
      @ajax << '$("#' + c.to_s + '").attr("disabled", false);'
    end
  end

  def disable(c)
    if @fact and @fact.campos[c.to_sym] and @fact.campos[c.to_sym][:type] == :date
      @ajax << '$("#' + c.to_s + '").datepicker("disable");'
    else
      @ajax << '$("#' + c.to_s + '").attr("disabled", true);'
    end
  end

  def enable_menu(m)
    @ajax << "if (parent != self) $('##{m}', parent.document).attr('disabled', false);"
  end

  def disable_menu(m)
    @ajax << "if (parent != self) $('##{m}', parent.document).attr('disabled', true);"
  end

  def enable_tab(t)
    @ajax << "$('#h_#{t}').attr('href', '#t_#{t}').css('cursor', 'pointer');"
  end

  def disable_tab(t)
    @ajax << "$('#h_#{t}').attr('href', '#').css('cursor', 'not-allowed');"
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

  # Control del estado de los botones del mantenimiento
  def status_botones(h={})
    @ajax << "statusBotones(#{h.to_json});"
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
      h[:cell] << s.created_by.try(:codigo)
      res[:rows] << h
    }
    render :json => res
  end

  def sincro_hijos
    class_mant.hijos.each_with_index {|h, i|
      @ajax << '$(function(){$("#hijo_' + i.to_s + '").attr("src", "/' + h[:url]
      @ajax << '?mod=' + class_modelo.to_s
      @ajax << '&id=' + @fact.id.to_s
      @ajax << '&padre=' + @v.id.to_s
      #@ajax << '&eid=' + params[:eid] if params[:eid]
      #@ajax << '&jid=' + params[:jid] if params[:jid]
      @ajax << '&eid=' + @dat[:eid].to_s if @dat[:eid]
      @ajax << '&jid=' + @dat[:jid].to_s if @dat[:jid]
      @ajax << '");});'
    }
  end

  def sincro_parent
    @dat[:vp].save
    @ajax << 'parent.parent.callFonServer("envia_ficha");'
  end

  def get_empeje
    #emej = cookies[:emej].split(':')
    emej = cookies[Nimbus::CookieEmEj].split(':')
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

    if self.respond_to?(:grid_conf)
      grid = clm.grid.deep_dup
      grid_conf(grid)
    else
      grid = clm.grid
    end

    add_where(w, grid[:wh]) if grid[:wh]

    @v = Vista.new
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
    @v.save
    @ajax << 'var _vista=' + @v.id.to_s + ';var _controlador="' + params['controller'] + '";'

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
    arg_ej << '&eid=' + eid if eid
    arg_ej << '&jid=' + jid if jid

    if clm.respond_to?('ejercicio_path')
      cj_ce = Ejercicio.where('ejercicios.id=?', jid).ljoin(:empresa).pluck('ta.codigo', 'ejercicios.codigo')
      @titulo << cj_ce[0][0] + '/' + cj_ce[0][1]
    elsif clm.respond_to?('empresa_path')
      @titulo << Empresa.where('id=?', eid).pluck(:codigo)[0]
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
      clm.columnas.each {|c|
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
    @menu_l = clm.menu_l
    @menu_r = clm.menu_r
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

    @ajax << 'var _vista=' + @v.id.to_s + ',_controlador="' + params['controller'] + '",eid="' + eid.to_s + '",jid="' + jid.to_s + '";'

    #Activar botones necesarios (Grabar/Borrar)
    @ajax << 'statusBotones({grabar: true, borrar: false});'

    before_envia_ficha if self.respond_to?('before_envia_ficha')
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
    fo = clmh.where('idid = ?', fh.idid).order(:created_at).first
    if fo.nil?
      render file: '/public/404.html', status: 404, layout: false
      return
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
        render file: r[:file], status: r[:status], layout: false
      else
        render file: r, status: 401, layout: false
      end
      return
    end

    var_for_views(clm)
    ini_campos if self.respond_to?('ini_campos')

    @v = Vista.new
    @v.save unless clm.mant? and @fact.id == 0
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

        #Activar botones necesarios (Grabar/Borrar)
        @ajax << 'statusBotones({grabar: false, borrar: false});'
      end
    else
      eid, jid = get_empeje

      @dat[:eid] = eid
      @dat[:jid] = jid

      set_empeje(eid, jid)
    end

    @ajax << 'var eid="' + @dat[:eid].to_s + '",jid="' + @dat[:jid].to_s + '";'
    unless clm.mant? and @fact.id == 0
      @ajax << 'var _vista=' + @v.id.to_s + ';var _controlador="' + params['controller'] + '";'
    end

    before_envia_ficha if self.respond_to?(:before_envia_ficha)

    unless clm.mant? and @fact.id == 0
      envia_ficha
      sincro_hijos if clm.mant?

      @v.save
    end

    r = false
    r = mi_render if self.respond_to?(:mi_render)
    (clm.mant? ? pag_render('ficha') : pag_render('proc')) unless r
  end

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
    mod = ref.constantize
    ret = mod.mselect(mod.auto_comp_mselect).where(mod.table_name + '.id=' + id.to_s)[0]
    ret ? ret.auto_comp_value(tipo) : nil
  end

  def _forma_campo(tipo, cp, cmp, val)
    if cmp.ends_with?('_id')
      #id = ficha[cmp]
      if val and val != 0 and val != ''
        #mod = cp[:ref].constantize
        #ret = mod.mselect(mod.auto_comp_mselect).where(mod.table_name + '.id=' + val.to_s)[0]
        #ret = ret ? ret.auto_comp_value(tipo) : nil
        ret = forma_campo_id(cp[:ref], val, tipo)
      else
        ret = ''
      end
      return ret
    end

=begin
    if val == {}
      begin
        #val = eval('ficha.' + cmp)
        val = ficha[cmp]
      rescue
        val = nil
      end
    end
=end

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

  def forma_campo(tipo, ficha, cmp, val)
    cp = ficha.respond_to?('campos') ? ficha.campos[cmp.to_sym] : class_mant.campos[cmp.to_sym]
    _forma_campo(tipo, cp, cmp, val)
  end

  def envia_campo(cmp, val)
    cmp_s = cmp.to_s
    cp = @fact.campos[cmp.to_sym]

    case cp[:type]
    when :boolean
      val = false unless val
      @ajax << '$("#' + cmp_s + '").prop("checked",' + val.to_s + ');'
    when :div
      ;
    else
      @ajax << '$("#' + cmp_s + '").val(' + forma_campo(:form, @fact, cmp_s, val).to_json + ')'
      @ajax << '.attr("dbid",' + val.to_s + ')' if cmp_s.ends_with?('_id') and val
      @ajax << ';'
    end
  end

  def call_on(c)
    cs = c.to_sym
    v = @fact.campos[cs]
    if self.respond_to?(v[:on].to_s)
      method(v[:on]).arity == 0 ? method(v[:on]).call() : method(v[:on]).call(cs)
    end

    fun = 'on_' << c
    method(fun).call if self.respond_to?(fun)
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
            if h[:ajax] and c != h[:exclude] and ch[:form]
              envia_campo(c, v)
            end

            call_on(c)
          end
        end
      }
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
  # search: (true/false) indica si aparece o no la barra de búsqueda
  #         en el grid. Por defecto vale false.
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
  #       ver: http://www.trirand.com/jqgridwiki/doku.php?id=wiki:colmodel_options
  #
  # grid: Es un hash con opciones específicas para el grid. Admite todas las
  #       referidas en: http://www.trirand.com/jqgridwiki/doku.php?id=wiki:options
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

  def crea_grid(opts)
    cmp = opts[:cmp].to_sym
    return unless cmp

    modo = opts[:modo] ? opts[:modo].to_sym : :sel
    opts[:ins] = :end unless opts.key?(:ins)
    opts[:del] = true if opts[:del].nil?

    opts[:cols].each {|c|
      if c[:name].to_s.ends_with?('_id')
        c[:type] = :references
        c[:ref] ||= c[:name][0..-4].capitalize
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
          #c[:sorttype] ||= 'date'
          #c[:formatter] ||= 'date'
          c[:editoptions][:dataInit] ||= '~function(e){date_pick(e)}~'
          c[:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
          c[:sortfunc] ||= '~sortDate~'
        when :time
          c[:editoptions][:dataInit] ||= '~function(e){$(e).entrytime(' + (c[:seg] ? 'true,' : 'false,') + (c[:nil] ? 'true' : 'false') + ')}~'
          c[:searchoptions][:sopt] ||= ['eq','ne','lt','le','gt','ge','nu','nn']
        when :references
          c[:editoptions] = {dataInit:  "~function(e){autoCompGridLocal(e,'#{c[:ref]}','#{c[:ref].constantize.table_name}','#{cmp}','#{c[:name]}');}~"}
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
        opts[:cols].each_with_index {|c, i| h[c[:name]] = _forma_campo(:form, c, c[:name], r[i+1])}
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
        @fact[cmp] = nil
        @fant[cmp] = nil if @fant
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
    @fact[cmp][:cols].each_with_index {|c, i| h[c[:name]] = _forma_campo(:form, c, c[:name], data[i + 1])}
    @ajax << "$('#g_#{cmp}').jqGrid('addRowData','#{data[0]}',#{h.to_json}"
    @ajax << ",'before',#{@fact[cmp][:data][pos][0]}" if pos >= 0
    @ajax << ");"

    @ajax << "$('##{cmp} .ui-jqgrid-bdiv').scrollTop(1000000);" if pos == -1

    @fact[cmp].add_row(pos, data)
    @fant[cmp].add_row(pos, data)
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
    @fant[cmp].del_row(row)
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
    #@dat = $h[params[:vista].to_i]
    #@fact = @dat[:fact]
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
          sel ? v << row : v.delete_at(v.index(row))
        else
          #@fact.method(campo + '=').call([row]) if sel
          @fact[campo] = [row] if sel
        end
      end
    else
      #@fact.method(campo + '=').call(params[:row].to_i)
      @fact[campo] = params[:row].to_i
    end
  end

  def nim_download
    if flash[:file]
      file_name = flash[:file]
    else
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    send_data File.read(file_name), filename: flash[:file_cli] || file_name
    if flash[:rm]
      FileUtils.rm file_name, force: true
    end
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

    sh.add_row(cols.map {|v| v[:label] || v[:name]})

    data.each {|r| sh.add_row(r[1..nc].map.with_index {|d, i| cols[i][:ref] ? forma_campo_id(cols[i][:ref], d) : d})}

    # Fijar la fila de cabecera para repetir en cada página
    wb.add_defined_name("Hoja1!$1:$1", :local_sheet_id => sh.index, :name => '_xlnm.Print_Titles')

    file_name = "/tmp/nim#{@v.id}.xlsx"
    xls.serialize(file_name)
    @ajax << "window.location.href='/nim_download';"
    flash[:file] = file_name
    flash[:file_cli] = @fact.campos[cmp][:grid_emb][:opts][:export] + '.xlsx'
    flash[:rm] = true
  end

  def validar
    clm = class_mant

    #@dat = $h[params[:vista].to_i]
    @fact = @dat[:fact]
    @g = @dat[:persistencia]
    fact_clone

    campo = params[:campo]
    valor = params[:valor]

    @ajax = ''

    if campo.ends_with?('_id') and params[:src] # Autocompletado sin id elegido (probable introducción rápida de texto)
      par = {term: valor}
      CGI::parse(URI::parse(params[:src]).query).each {|k, v| par[k.to_sym] = v[0]}
      res = _auto(par)
      if res.size == 1  # Se ha encontrado un registro único
        valor = res[0][:id]
        @ajax << "$('##{campo}').val(#{res[0][:value].to_json}).attr('dbid',#{valor});"
      else
        valor = ''
        @ajax << "$('##{campo}').val('').attr('dbid',null);"
      end
    end

    @fact[campo] = raw_val(campo, valor)

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

    sincro_ficha :ajax => true, :exclude => campo

    @ajax << 'hayCambios=' + @fact.changed?.to_s + ';' if clm.mant?

    render :js => @ajax

    @v.save
  end

  #Función para ser llamada desde el botón aceptar de los 'procs'
  def fon_server
    unless self.respond_to?(params[:fon])
      render nothing: true
      return
    end

    @ajax = ''
    if params[:vista]
      @fact = @dat[:fact]
      @g = @dat[:persistencia]
      fact_clone if @fact
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
    @ajax = ''

    @fact = @dat[:fact]
    @g = @dat[:persistencia]
    err = vali_borra if self.respond_to?('vali_borra')
    if err
      mensaje err
    else
      @fact.destroy

      grid_reload
      @ajax << "window.location.replace('/' + _controlador + '/0/edit?head=#{@dat[:head]}');"
    end

    render js: @ajax
    @v.save
  end

  #### GRABAR

  def grabar(ajx=true)
    clm = class_mant
    @fact = @dat[:fact]
    @g = @dat[:persistencia]
    fact_clone
    err = ''
    @ajax = ''
    last_c = nil
    begin
      @fact.campos.each {|cs, v|
        c = cs.to_s

        if v[:req]
          valor = @fact[c]
          (valor.nil? or ([:string, :text].include?(v[:type]) and not c.ends_with?('_id') and valor.strip == '')) ? e = "Campo #{c} requerido" : e = nil
        elsif v[:type] == :div
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
            #f.method(c+'=').call(@fact.method(c).call)
            f[c] = @fact[c]
          }
          f.save
        else
          #begin
            @fact.save if @fact.respond_to?('save') # El if es por los 'procs' (que no tienen modelo subyacente)
=begin
          rescue ActiveRecord::RecordNotUnique
            @ajax = ''
            sincro_ficha :ajax => true
            mensaje 'Grabación cancelada. Ya existe la clave'
            @v.save
            render :js => @ajax if ajx
            return
          end
=end
        end

        begin
          after_save if self.respond_to?('after_save')
        rescue Exception => e
          pinta_exception(e, 'Error: after_save')
        end

        if clm.mant?
          sincro_hijos if @fant[:id].nil?

          #Refrescar el grid si procede
          grid_reload

          #Activar botones necesarios (Grabar/Borrar)
          @ajax << 'statusBotones({borrar: true});'
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
    render nothing: true
  end

  def bus_call
    @fact = @dat[:fact]

    cmp = params[:id].to_sym
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
        #sal << '<input class="nim-input" id="' + cs + '" required style="max-width: ' + size + 'em" ' + plus + '/>'
        sal << '<input class="nim-input" id="' + cs + '" required style="max-width: ' + size + 'em" '
        sal << 'dialogo="' + h[:dlg] + '" ' if h[:dlg]
        sal << plus + '/>'
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
      elsif v[:type] == :div
        sal << "<div id='#{cs}' style='overflow: auto'></div>"
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
        sal << '&vista=' + @v.id.to_s
        sal << '&cmp=' + cs
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
