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
    render 'shared/histo'
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
    class_mant.hijos.each {|h|
      @ajax << '$(function(){$("#' + h.split('/')[-1] + '").attr("src", "/' + h
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

    @titulo = nt(clm.titulo)
    @url_base = '/' + params[:controller] + '/'
    @url_list = @url_base + 'list'
    @url_new = @url_base + 'new'
    @arg_edit = '?'
    arg_list_new = '?'

    if params[:mod] != nil
      arg_list_new << '&mod=' + params[:mod] + '&id=' + params[:id] + '&padre=' + params[:padre]
      @arg_edit << '&padre=' + params[:padre]
    end

    if eid
      arg_list_new << '&eid=' + eid
      @e = Empresa.find_by id: eid.to_i
    end

    if jid
      arg_list_new << '&jid=' + jid
      @j = Ejercicio.find_by id: jid.to_i
    end

    @url_list << arg_list_new
    @url_new << arg_list_new

    if clm.mant? # No es un proc, y por lo tanto preparamos los datos del grid
      @orden_grid = clm.orden_grid
      @url_cell = @url_base + '/validar_cell'

      cm = clm.col_model.deep_dup
      cm.each {|h|
        h[:label] = nt(h[:label])
        if h[:edittype] == 'select'
          h[:editoptions][:value].each{|c, v|
            h[:editoptions][:value][c] = nt(v)
          }
        end
      }
      @col_model = eval_cad(clm.col_model_html(cm))
      #@col_model = clm.col_model_html(cm)
    end
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

  def new
    #return unless sesion_valida

    self.respond_to?('before_new') ? r = before_new : r = true
    unless r
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    clm = class_mant

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
    #sincro_ficha
    envia_ficha

    render 'shared/new'
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
      dif << '$("#' + c + '").css("background-color", "Bisque");' if ( v != fo.method(c).call)
    }

    @ajax = ''
    envia_ficha
    @ajax << '$(".nimbus_entry").attr("disabled", "disabled");'
    @ajax << '$(".nimbus_entry").css("color", "black");'
    @ajax << dif
    render 'shared/edith'
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
        @ajax = ''
        envia_ficha
        render 'shared/edit'
        return
      else
        @fact = clm.find_by id: params[:id]
        if @fact.nil?
          render file: '/public/404.html', status: 404, layout: false
          return
        end
      end
    end

    self.respond_to?('before_edit') ? r = before_edit : r = nil
    if r
      render file: r, status: 401, layout: false
      return
    end

    if not clm.mant?
      @fact = clm.new
      ini_campos if self.respond_to?('ini_campos')
    end

    @titulo = nt(clm.titulo)

    if params[:vista]
      v = Vista.new
      v.id = params[:vista]
    else
      v = Vista.create
      $h[v.id] = {}
    end

    @vid = v.id
    $h[v.id][:fact] = @fact

    @fact.parent = $h[params[:padre].to_i][:fact] unless params[:padre].nil?

    @fant = clm.new
    @ajax = 'var _vista=' + v.id.to_s + ';var _controlador="' + params['controller'] + '";'

    sincro_hijos(v.id)
    #sincro_ficha
    before_envia_ficha if self.respond_to?('before_envia_ficha')
    envia_ficha

    render 'shared/edit' if clm.mant?
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
      wh << 'LOWER(' + c + ') LIKE \'' + patron.downcase + '\'' + ' OR '
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

    @fact.method(campo + '=').call(raw_val(campo, valor))

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
      @ajax << 'alert(' + err.to_json + ');' if err != ''
    end

    sincro_ficha :ajax => true, :exclude => campo

    render :js => @ajax
  end

  #Función para ser llamada desde el botón aceptar de los 'procs'
  def fon_server
    @fact = $h[params[:vista].to_i][:fact] if params[:vista]
    if self.respond_to?(params[:fon])
      method(params[:fon]).call
    else
      render nothing: true
    end
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
    err = "Hay errores en el registro\n"
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
          err << "\n#{e}"
          vali = false
        end
      else
        if self.respond_to?(fun)
          e = method(fun).call
          if e != nil
            vali = false
            err << "\n"+ e if e != ''
          end
        end

        if @fact.respond_to?(fun)
          e = @fact.method(fun).call
          if e != nil
            vali = false
            err << "\n"+ e if e != ''
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
        @fact.save if @fact.respond_to?('save') # El if es por los 'procs' (que no tienen modelo subyacente)
      end
      save if self.respond_to?('save') # Damos la opción de tener un método save (adicional) en el mantenimiento

      sincro_ficha :ajax => true

      sincro_hijos(vid) if (id_old.nil?)

      #@ajax << 'parent.$("#grid").flexReload();'
      #@ajax << 'alert("Grabación correcta");'
    else
      @ajax << '$("#' + last_c + '").focus();'
      @ajax << 'alert(' + err.to_json + ');'
    end

    render :js => @ajax
  end

  def eval_cad(cad)
    cad.is_a?(String) ? eval('%~' + cad.gsub('~', '\~') + '~') : cad
  end

  def gen_form(h={})
    clm = class_mant

    if h[:table] != nil
      tab = h[:table]
    else
      tab = true
    end

    if tab
      sal = '<table>'
      pref = '<td>'
      suf = '</td>'
    else
      sal = ''
      pref = ''
      suf = ''
    end

    #@e = clm.column_names.include?('empresa_id') ? @fact.empresa : nil
    #@j = clm.column_names.include?('ejercicio_id') ? @fact.ejercicio : nil
    @e = @fact.empresa if @fact.respond_to?('empresa')
    @j = @fact.ejercicio if @fact.respond_to?('ejercicio')

    clm.campos.each{|c, v|
      cs = c.to_s
      next if v[:div].nil? or v[:div] != h[:div]

      if block_given?
        plus = yield(cs)
      else
        plus = ''
      end

      next if plus == 'stop'

      ro = eval_cad(v[:ro])
      manti = eval_cad(v[:manti])
      decim = eval_cad(v[:decim])
      size = manti + decim + manti/3 + 1
      manti = manti.to_s
      rows = eval_cad(v[:rows])
      sel = eval_cad(v[:sel])
      if v[:code]
        code = eval_cad(v[:code])
        code_pref = eval_cad(code[:prefijo])
        code_rell = eval_cad(code[:relleno])
      end

      plus = '' if plus.class != String

      plus << ' disabled' if ro == :all or ro == params[:action].to_sym
      plus << ' class="nimbus_entry"'

      sal << '<tr>' if tab
      sal << pref + '<label for="' + cs + '">' + nt(v[:label]) + ':</label>' + suf

      sal << pref

      if v[:type] == :boolean
        sal << '<input id="' + cs + '" type="checkbox" onchange="vali_check($(this))" ' + plus + '/>'
      elsif v[:type] == :text
        sal << '<textarea id="' + cs + '" cols=' + manti + ' rows=' + rows.to_s + ' onchange="validar($(this))" ' + plus + '>'
        sal << '</textarea>'
      elsif v[:code]
          sal << '<input id="' + cs + '" size=' + manti + ' onchange="vali_code($(this),' + manti + ',\'' + code_pref + '\',\'' + code_rell + '\')" ' + plus + '/>'
      elsif sel
        sal << '<select id="' + cs + '" onchange="validar($(this))" ' + plus + '>'
        sel.each{|k, tex|
          sal << '<option value="' + k.to_s + '">' + nt(tex) + '</option>'
        }
        sal << '</select>'
      elsif cs.ends_with?('_id')
        sal << '<input id="' + cs + '" size=' + manti + ' ' + plus + '/>'
      else
        sal << '<input id="' + cs + '" size=' + size.to_s + ' onchange="validar($(this))"'
        sal << ' maxlength=' + manti if v[:type] == :string
        sal << ' ' + plus + '/>'
      end

      sal << suf

      sal << '</tr>' if tab
    }

    sal << '</table>' if tab

    sal.html_safe
  end

  def gen_js
    if @fact.id == 0
      return '$(":input").attr("disabled", "disabled");'.html_safe
    end

    clm = class_mant
    sal = ''

    #@e = clm.column_names.include?('empresa_id') ? @fact.empresa : nil
    #@j = clm.column_names.include?('ejercicio_id') ? @fact.ejercicio : nil
    @e = @fact.empresa if @fact.respond_to?('empresa')
    @j = @fact.ejercicio if @fact.respond_to?('ejercicio')

    class_mant.campos.each{|c, v|
      next unless v[:div]

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

    if clm.mant?
      if @fact.id.nil?
        sal << %Q{$("#encurso").text("#{nt('nuevo')}");}
      elsif @fact.id !=0
        sal << %Q{$("#encurso").text("#{nt('editando')}");}
      end
    end

    sal.html_safe
  end

  helper_method :gen_form
  helper_method :gen_js

  def savepanel
    render nothing: true;
  end
end
