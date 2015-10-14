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
      @ajax << '"' + nt(b[:label]) + '": function(){callFonServer("' + b[:accion] + '");'
      @ajax << '$("#dialog-nim-alert").dialog("close");' if h[:close]
      @ajax << '},'
    }
    @ajax << '})'
    @ajax << '.dialog("open");'
  end

  def enable(c)
    @ajax << '$("#' + c + '").attr("disabled", false);'
  end

  def disable(c)
    @ajax << '$("#' + c + '").attr("disabled", true);'
  end

  def foco(c)
    @ajax << '$("#' + c + '").focus();'
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
      @ajax << '&eid=' + params[:eid] if params[:eid]
      @ajax << '&jid=' + params[:jid] if params[:jid]
      @ajax << '");});'
    }
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

    emej = cookies[:emej].split(':')
    eid = params[:eid]
    eid ||= emej[0] == 'null' ? nil : emej[0]
    jid = params[:jid]
    jid ||= emej[1] == 'null' ? nil : emej[1]

    unless params[:mod]
      if clm.column_names.include?('empresa_id') and eid.nil?
        render file: '/public/no_emp.html', layout: false
        return
      elsif clm.column_names.include?('ejercicio_id') and jid.nil?
        render file: '/public/no_eje.html', layout: false
        return
      end
    end

    @view = {grid: clm.grid}
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
      @e = Empresa.find_by id: eid.to_i
      @titulo << @e.codigo if clm.column_names.include?('empresa_id')
    end

    if jid
      arg_ej << '&jid=' + jid
      @j = Ejercicio.find_by id: jid.to_i
      @titulo << '/' + @j.codigo if clm.column_names.include?('ejercicio_id')
    end

    @view[:arg_auto] = params[:mod] ? '&wh=' + params[:mod].split(':')[-1].downcase + '_id=' + params[:id] : arg_ej
    @titulo << ' ' + clm.titulo

    @view[:url_list] << arg_list_new + arg_ej
    @view[:url_new] << arg_list_new + arg_ej

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
    # jqGrid
    #
    render json: '' unless request.xhr? # Si la petición no es Ajax... ¡Puerta! (Por razones de seguridad)

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

    tot_records = clm.select(:id).where(w).size
    lim = params[:rows].to_i
    tot_pages = tot_records / lim
    tot_pages += 1 if tot_records % lim != 0
    page = params[:page].to_i
    page = tot_pages if page > tot_pages
    page = 1 if page <=0

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

    sql = clm.eager_load(eager).where(w).order(ord).offset((page-1)*lim).limit(lim)

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
    clm.campos.each{|c, v|
      @tabs << v[:tab] if v[:tab] and !@tabs.include?(v[:tab]) and v[:tab] != 'pre' and v[:tab] != 'post'
    }
    clm.hijos.each{|h|
      @tabs << h[:tab] if h[:tab] and !@tabs.include?(h[:tab]) and h[:tab] != 'pre' and h[:tab] != 'post'
    }
    @head = (params[:head] ? params[:head].to_i : 1)
  end

  def new
    self.respond_to?('before_new') ? r = before_new : r = true
    unless r
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    clm = class_mant

    var_for_views(clm)

    if params[:vista]
      v = Vista.new
      v.id = params[:vista]
    else
      v = Vista.create
      $h[v.id] = {}
    end

    @fact = $h[v.id][:fact] = clm.new
    @fact.respond_to?(:id)  # Solo para inicializar los métodos internos de ActiveRecord
    @fant = @fact.dup

    @fact.parent = $h[params[:padre].to_i][:fact] unless params[:padre].nil?

    # Si es un mant. hijo inicializar el id del padre
    eval('@fact.' + params[:mod].split(':')[-1].downcase + '_id=' + params[:id]) if params[:mod]

    unless params[:mod]
      emej = cookies[:emej].split(':')
      eid = params[:eid]
      eid ||= emej[0] == 'null' ? nil : emej[0]
      jid = params[:jid]
      jid ||= emej[1] == 'null' ? nil : emej[1]

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

    @ajax = 'var _vista=' + v.id.to_s + ';var _controlador="' + params['controller'] + '";'
    #Activar botones necesarios (Grabar/Borrar)
    @ajax << 'statusBotones({grabar: true, borrar: false});'

    envia_ficha

    #render 'shared/new'
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

    @ajax = ''
    envia_ficha
    @ajax << '$(":input").attr("disabled", true);'
    @ajax << dif
    render html: '', layout: 'ficha'
  end

  def edit
    clm = class_mant

    var_for_views(clm)

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
      end
    end

    ((!clm.mant? or @fact.id != 0) and self.respond_to?('before_edit')) ? r = before_edit : r = nil
    if r
      render file: r, status: 401, layout: false
      return
    end

    if not clm.mant?
      campos_x if self.respond_to?('campos_x')
      @fact = clm.new
      ini_campos if self.respond_to?('ini_campos')
    end

    if params[:vista]
      v = Vista.new
      v.id = params[:vista]
    else
      v = Vista.create
      $h[v.id] = {}
    end

    @vid = v.id
    $h[v.id][:fact] = @fact
    $h[v.id][:head] = params[:head] if params[:head]

    @fact.parent = $h[params[:padre].to_i][:fact] unless params[:padre].nil?

    @fant = clm.new
    @ajax = 'var _vista=' + v.id.to_s + ';var _controlador="' + params['controller'] + '";'

    if clm.mant?
      if @fact.id != 0
        sincro_hijos(v.id)

        #Activar botones necesarios (Grabar/Borrar)
        @ajax << 'statusBotones({grabar: true, borrar: true});'
      else
        #Activar botones necesarios (Grabar/Borrar)
        @ajax << 'statusBotones({grabar: false, borrar: false});'
      end
    end

    before_envia_ficha if self.respond_to?('before_envia_ficha')
    envia_ficha

    #pag_render('ficha') if clm.mant?
    clm.mant? ? pag_render('ficha') : pag_render('proc')
  end

  def auto
    unless request.xhr? # Si la petición no es Ajax... ¡Puerta! (para evitar accesos desde la barra de direcciones)
      render json: ''
      return
    end

    p = params[:term]
    if p == '-' or p == '--' or p == '.'
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
      wh << 'UNACCENT(LOWER(' + c + ')) LIKE \'' + I18n.transliterate(patron).downcase + '\'' + ' OR '
    }
    wh = wh[0..-5] + ')'
    wh << ' AND empresa_id=' + params[:eid] if mod.column_names.include?('empresa_id') and params[:eid]
    wh << ' AND ejercicio_id=' + params[:jid] if mod.column_names.include?('ejercicio_id') and params[:jid]
    mod.where(params[:wh]).where(wh).order(data[:orden]).limit(15).each {|r|
      res << {value: r.auto_comp_value(type), id: r[:id], label: r.auto_comp_label(type)}
    }

    render :json => res
  end

  def forma_campo(tipo, ficha, cmp, val={})
    cp = class_mant.campos[cmp.to_sym]
    if cmp.ends_with?('_id')
      id = ficha.method(cmp).call
      if id
        if class_modelo.attribute_names.include?(cmp)
          val = {}
          cmpr = cmp[0..-4] + ".auto_comp_value(:#{tipo})"
        else
          val =  cp[:ref].constantize.find(id).method('auto_comp_value').call(tipo)
        end
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
      else
        return val
      end
    end
  end

  def envia_campo(cmp, val)
    cp = class_mant.campos[cmp.to_sym]

    case cp[:type]
    when :boolean
      val = false unless val
      @ajax << '$("#' + cmp + '").prop("checked",' + val.to_s + ');'
    else
      @ajax << '$("#' + cmp + '").val(' + forma_campo(:form, @fact, cmp, val).to_json + ');'
    end
  end

  def call_on(c)
    fun = 'on_' << c
    if self.respond_to?(fun)
      method(fun).call
    end
  end

  def sincro_ficha(h={})
    clm = class_mant
    vcg = []
    vc = [nil]
    while vc != []
      vc = []
      clm.campos.each {|cs, ch|
        c = cs.to_s
        if vcg.include?(c)
          vc.delete_if {|cv| cv[0] == c}
          next
        end

        v = @fact.method(c).call
        va = @fant.method(c).call
        if v != va
          vc << [c, v]
          vcg << c

          if h[:ajax] and c != h[:exclude] and clm.campos_f.include?(c)
            envia_campo(c, v)
          end

          call_on(c)
        end
      }
      vc.each {|cv|
        c = cv[0] + '='
        @fant.method(c).call(cv[1]) if @fant.respond_to?(c)
      }
    end
  end

  def envia_ficha
    class_mant.campos_f.each {|c|
      envia_campo(c, @fact.method(c).call)
    }
  end

  #### VALIDAR

  def raw_val(c, v)
    cp = class_mant.campos[c.to_sym]

    case cp[:type]
    when :integer, :float, :decimal
      return v.gsub('.', '').gsub(',', '.')
    else
      return v
    end
  end

  def valida_campo(campo)
    err = nil
    fun = 'vali_' << campo

    if self.respond_to?(fun)
      err = method(fun).call
    end

    if @fact.respond_to?(fun)
      e = @fact.method(fun).call
      if e != nil
        if err.nil?
          err = e
        else
          err << e
        end
      end
    end

    err
  end

  def validar_cell
    clm = class_modelo  # OJO! aquí clm es del modelo subyacente (para cuando el controlador es una vista)
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
    @fant = @fact.dup

    @fact.method(campo + '=').call(params[:sel] ? params[:sel] : raw_val(campo, valor))

    err = valida_campo(campo)

    if err.nil?
      if params[:nocallback]
        @fact.update_column(campo, valor)
      else
        @fact.save
      end
      render text: ''
    else
      render text: err
    end
  end

  def validar
    clm = class_mant

    @fact = $h[params[:vista].to_i][:fact]
    @fant = @fact.dup

    campo = params[:campo]
    valor = params[:valor]

    @fact.method(campo + '=').call(raw_val(campo, valor))

=begin
class_mant.campos.each {|cs, h|
  c = cs.to_sym
  v = @fact.method(c).call
  va = @fant.method(c).call
  puts c + ': <' + v.to_s + '> <' + va.to_s + '>'
}
=end

    ## Validación

    err = valida_campo(campo)

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
    @fact = $h[params[:vista].to_i][:fact] if params[:vista]
    @fant = @fact.dup if @fact
    method(params[:fon]).call if self.respond_to?(params[:fon])
    sincro_ficha :ajax => true if @fact
    render js: @ajax
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
    clm = class_mant
    vid = params[:vista].to_i
    @fact = $h[vid][:fact]
    @fact.destroy
    render js: ''
  end

  #### GRABAR

  def grabar
    clm = class_mant
    vid = params[:vista].to_i
    @fact = $h[vid][:fact]
    @fant = @fact.dup
    vali = true
    err = ''
    @ajax = ''
    last_c = nil
    clm.campos.each {|cs, v|
      c = cs.to_s

      fun = 'vali_' << c
      e = nil

      if v[:req]
        valor = @fact.method(c).call
        if valor.nil? or ([:string, :text].include?(v[:type]) and valor.strip == '')
          e = "Campo #{c} requerido"
          err << '<br>' + e
          vali = false
        end
      else
        if self.respond_to?(fun)
          e = method(fun).call
          if e != nil
            vali = false
            err << '<br>' + e
          end
        end

        if @fact.respond_to?(fun)
          e = @fact.method(fun).call
          if e != nil
            vali = false
            err << '<br>' + e
          end
        end
      end

      if e != nil
        @ajax << '$("#' + c + '").addClass("ui-state-error");' if clm.campos_f.include?(c)
        last_c = c
      end
    }

    if vali
      id_old = @fact.id
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
          @ajax = ''
          mensaje 'Grabación cancelada. Ya existe la clave'
          render :js => @ajax
          return
        end
      end
      save if self.respond_to?('save') # Damos la opción de tener un método save (adicional) en el mantenimiento

      sincro_ficha :ajax => true

      sincro_hijos(vid) if (id_old.nil?)

      #Refrescar el grid si procede
      @ajax << 'parentGridReload();'

      #Activar botones necesarios (Grabar/Borrar)
      @ajax << 'statusBotones({borrar: true});'

      @ajax << 'hayCambios=false;'
    else
      @ajax << '$("#' + last_c + '").focus();'
      #@ajax << 'alert(' + err.to_json + ');'
      mensaje tit: 'Errores en el registro', msg: err
    end

    render :js => @ajax
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

    #@e = clm.column_names.include?('empresa_id') ? @fact.empresa : nil
    #@j = clm.column_names.include?('ejercicio_id') ? @fact.ejercicio : nil
    @e = @fact.empresa if @fact.respond_to?('empresa')
    @j = @fact.ejercicio if @fact.respond_to?('ejercicio')

    clm.campos.each{|c, v|
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

      #if prim or v[:hr] or ncols >= 12
      if prim or v[:hr]
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
        sal << '<button id="_acb_' + cs + '" class="nim-autocomp-button mdl-button mdl-js-button mdl-button--icon">'
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
        sal << '<input class="nim-input" id="' + cs + '" required onchange="validar($(this))" style="max-width: ' + size + 'em"'
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

    #@e = clm.column_names.include?('empresa_id') ? @fact.empresa : nil
    #@j = clm.column_names.include?('ejercicio_id') ? @fact.ejercicio : nil
    @e = @fact.empresa if @fact.respond_to?('empresa')
    @j = @fact.ejercicio if @fact.respond_to?('ejercicio')

    if clm.mant? and @fact.id == 0
      sal << '$(":input").attr("disabled", true);'
      sal << '$("#_d-input-pk_").css("display", "block");'
      sal << '$("#_input-pk_").attr("disabled", false);'
      sal << 'auto_comp("#_input-pk_","/application/auto?mod=' + clm.superclass.to_s
      sal << '&eid=' + @e.id.to_s if @e
      sal << '&jid=' + @j.id.to_s if @j
      sal << '");'
      return sal.html_safe
    end

    class_mant.campos.each{|c, v|
      next unless v[:tab]

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
      may = eval_cad(v[:may])
      date_opts = eval_cad(v[:date_opts])

      cs = c.to_s
      if cs.ends_with?('_id')
        sal << 'auto_comp("#' + cs + '","/application/auto?mod=' + v[:ref]
        sal << '&eid=' + @e.id.to_s if @e
        sal << '&jid=' + @j.id.to_s if @j
        sal << '");'
      elsif mask
        sal << 'mask({elem: "#' + cs + '", mask:"' + mask + '"'
        sal << ', may:' + may.to_s if may
        sal << '});'
      elsif v[:type] == :date
        sal << 'date_pick("#' + cs + '",' + (date_opts == {} ? '{showOn: "button"}' : date_opts.to_json) + ');'
      elsif v[:type] == :integer or v[:type] == :decimal
        sal << 'numero("#' + cs + '",' + manti + ',' + decim.to_s + ',' + signo.to_s + ');'
      end
    }

    sal.html_safe
  end

  helper_method :gen_form
  helper_method :gen_js

  def savepanel
    render nothing: true;
  end
end
