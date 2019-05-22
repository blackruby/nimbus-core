class GiMod
  @campos = {
    form_type: {sel: {pdf: 'pdf', xlsx: 'excel', xls: 'excel_old'}, tab: 'post', hr: true},
    form_modulo: {},
    form_file: {},
  }
end

class GiMod
  include MantMod
end

class GiController < ApplicationController
  # Método para contantizar un modelo y, si es un histórico, constantizar antes el modelo original para que se carguen las clases correctamente
  def h_constantize(mod)
    begin
      mod.constantize
    rescue
      im = mod.index('::')
      if im
        (mod[0..im+1] + mod[im+3..-1]).constantize
      else
        mod[1..-1].constantize
      end
      mod.constantize
    end
  end

  def nuevo_mod(mod, path)
    if File.directory?(path + '/' + mod)
      # Esto es el caso de módulos con module rails asociado
      path = path + '/' + mod
      modulo = "#{mod.capitalize}::"
    else
      modulo = ''
    end

    Dir.glob(path + '/*').sort.each {|fic|
      ficb = Pathname(fic).basename.to_s

      next if File.directory?(fic)
      next if ficb == 'vista.rb'
      next unless ficb.ends_with?('.rb')

      ficb = ficb[0..-4].capitalize

      @tablas[mod] ||= []
      @tablas[mod] << [ficb, modulo + ficb]
    }
  end

  def nuevo_form(mod, path, ext=true)
    @forms[mod] = [] unless ext
    Dir.glob(path + '/*.yml').sort.each {|fic|
      ficb = Pathname(fic).basename.to_s

      @forms[mod] ||= []
      if ext
        modelo = desc = com = ''
        open(fic, 'r').each_with_index {|l, i|
          break if i > 3
          modelo = YAML.load(l)[:modelo] if l.starts_with?(':modelo:')
          desc = YAML.load(l)[:descripcion] if l.starts_with?(':descripcion:')
          com = YAML.load(l)[:comentario] if l.starts_with?(':comentario:')
        }
        @forms[mod] << [ficb[0..-5], modelo, desc, com]
      else
        @forms[mod] << ficb[0..-5]
      end
    }
  end

  def all_files(ext)
    @forms = {}

    nuevo_form('privado', "formatos/_usuarios/#{@usu.codigo}", ext)
    nuevo_form('publico', 'formatos/_publico', ext)

    if (@usu.codigo == 'admin')
      nuevo_form(Rails.app_class.to_s.split(':')[0].downcase, 'formatos', ext)

      Dir.glob('modulos/*').sort.each {|mod|
        nuevo_form(mod.split('/')[1], mod + '/formatos', ext) unless mod.ends_with?('/idiomas') or mod.ends_with?('/nimbus-core')
      }
    end
  end

  def gi
    @assets_stylesheets = %w(gi)
    @assets_javascripts = %w(gi)

    unless @usu.admin or @usu.pref[:permisos][:ctr]['gi']
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    @titulo = nt('gi')
    all_files(true)
    @modo = 'edit'
  end

  def giv
    @assets_stylesheets = %w(gi)
    @assets_javascripts = %w(gi)

    unless @usu.admin or @usu.pref[:permisos][:ctr]['giv']
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    @titulo = nt('giv')
    all_files(true)
    @modo = 'run'
    render 'gi'
  end

  def new
    unless @usu.admin or @usu.pref[:permisos][:ctr]['gi']
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    if params[:modelo]
      @assets_stylesheets = %w(gi_edita)
      @assets_javascripts = %w(gi_edita)

      @modelo = params[:modelo]
=begin
      begin
        @modelo.constantize # Solo para provocar una excepción si no existe el modelo
      rescue
        begin
          @modelo[1..-1].constantize  # Por si es un histórico
          @modelo.constantize # Solo para provocar una excepción si no existe el modelo
        rescue
          render file: '/public/404.html', status: 404, layout: false
          return
        end
      end
=end

      # Comprobar si existe el modelo constantizándolo
      begin
        h_constantize(@modelo)
      rescue
        render file: '/public/404.html', status: 404, layout: false
        return
      end

      @modulo = 'privado'
      @formato = ''
      @form = {}
      all_files(false)
      render 'edita'
    else
      @assets_stylesheets = %w(gi_new)

      @titulo = nt('gi')
      @tablas = {}

      nuevo_mod(Rails.app_class.to_s.split(':')[0].downcase, 'app/models')

      Dir.glob('modulos/*').each {|mod|
        nuevo_mod(mod.split('/')[1], mod + '/app/models')
      }
    end
  end

  def edita
    @assets_stylesheets = %w(gi_edita)
    @assets_javascripts = %w(gi_edita)

    unless @usu.admin or @usu.pref[:permisos][:ctr]['gi']
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    @modulo = params[:modulo]
    @formato = params[:formato]
    @form = GI.formato_read(@modulo, @formato, @usu.codigo)
    if @form
      @modelo = @form[:modelo]
      all_files(false)
    else
      render file: '/public/404.html', status: 404, layout: false
    end
  end

  def campos
    cl = h_constantize(params[:node])

    emp = params[:emp].to_i

    data = []

    cols = Nimbus::Config.dig(:gi, :ord_cmp) ? cl.column_names : (['id'] + cl.pk + cl.column_names.sort).uniq
    cols.each {|c|
      cs = c.to_sym
      next if cl.propiedades.dig(cs, :bus_hide)
      d = {table: cl.table_name, type: cl.columns_hash[c].type}
      if c.ends_with?('_id')
        assoc = cl.reflect_on_association(c[0..-4].to_sym)
        if assoc
          #d[:id] = cl.reflect_on_association(c[0..-4].to_sym).options[:class_name]
          d[:id] = assoc.class_name
          # Controlar permisos. Si no se tiene permiso para el controlador asociado al modelo
          # correspondiente al campo "id" ==> Excluir dicho id para no poder acceder a esa tabla.
          unless @usu.admin
            ctrl = assoc.class_name.constantize.ctrl_for_perms
            next unless @usu.pref[:permisos][:ctr][ctrl] && @usu.pref[:permisos][:ctr][ctrl][emp]
          end
          d[:label] = c[0..-4]
          d[:load_on_demand] = true
        else
          logger.fatal "######## ERROR. Modelo: #{cl}, campo: #{c} No tiene belongs_to asociado."
          next
        end
      else
        d[:label] = c
        d[:pk] = cl.respond_to?(:pk) ? (c == cl.pk[-1]) : false
        d[:manti] = cl.propiedades[cs][:manti] if cl.propiedades[cs] and cl.propiedades[cs][:manti]
        decim = (cl.propiedades[cs] and cl.propiedades[cs][:decim]) ? cl.propiedades[cs][:decim] : 2

        case d[:type]
          when :boolean
            d[:ali] = 'c'
            d[:estilo] = 'def_c'
          when :date
            d[:ali] = 'c'
            d[:estilo] = 'date'
          when :time
            d[:ali] = 'c'
            d[:estilo] = 'time'
          when :datetime
            d[:ali] = 'c'
            d[:estilo] = 'datetime'
          when :integer
            d[:ali] = 'd'
            d[:estilo] = 'int'
          when :decimal
            d[:ali] = 'd'
            if decim.is_a?(String)
              d[:decim] = decim[decim.index('#{').to_i+2...decim.rindex('}').to_i]
              d[:estilo] = 'dyn'
            else
              d[:decim] = decim
              d[:estilo] = 'dec' + decim.to_s
            end
          else
            d[:ali] = 'i'
        end
      end
      tit = cl.propiedades.dig(cs, :title)
      d[:title] = tit if tit
      data << d
    }

    render json: data
  end

  def graba_fic
    begin
      case params[:modulo]
        when ''
          #render text: 'n'
          render plain: 'n'
          return
        when 'privado'
          path = "formatos/_usuarios/#{@usu.codigo}/"
        when 'publico'
          path = "formatos/_publico/"
        when Rails.app_class.to_s.split(':')[0].downcase
          path = "formatos/"
        else
          path = "modulos/#{params[:modulo]}/formatos/"
      end

      FileUtils.mkdir_p(path)
      File.write(path + params[:formato] + '.yml', eval(params[:data]).to_yaml)
      #render text: 's'
      render plain: 's'
    rescue Exception => e
      pinta_exception(e)
      #render text: 'n'
      render plain: 'n'
    end
  end

  def borra_formato
    form = params[:form]
    return unless form
    form = form.split('/')
    return if form.size != 2
    return if !(@usu.codigo == 'admin' || @usu.pref[:permisos] && @usu.pref[:permisos][:ctr] && @usu.pref[:permisos][:ctr]['gi'] && (form[0] == 'publico' || form[0] == 'privado'))

    if form[0] == 'publico'
      pref = 'formatos/_publico'
    elsif form[0] == 'privado'
      pref = "formatos/_usuarios/#{@usu.codigo}"
    elsif form[0] == Rails.app_class.to_s.split(':')[0].downcase
      pref = 'formatos'
    else
      pref = "modulos/#{form[0]}/formatos"
    end

    FileUtils.rm_rf "#{pref}/#{form[1]}.yml"
  end

  def before_edit
    if params[:controller] == 'gi'
      @gi_modulo = params['modulo']
      @gi_formato = params['formato']

      if @gi_modulo != 'publico' and @gi_modulo != 'privado'
        pref_html = '/'
        if @gi_modulo == Rails.app_class.to_s.split(':')[0].downcase
          pref = 'app/controllers'
        else
          pref = "modulos/#{@gi_modulo}/app"
          if File.exist?("#{pref}/models/#{@gi_modulo}.rb")
            pref << "/controllers/#{@gi_modulo}"
            pref_html = "/#{@gi_modulo}/"
          else
            pref << "/controllers"
          end
        end
        #return({redirect: "#{pref_html}#{@gi_formato}"}) if File.exist?("#{pref}/#{@gi_formato}_controller.rb")
        if File.exist?("#{pref}/#{@gi_formato}_controller.rb")
          redirect_to "#{pref_html}#{@gi_formato}"
          return
        end
      end

      #return('/public/401.html') unless @usu.admin or params[:modulo] == 'publico' or params[:modulo] == 'privado' or @usu.pref[:permisos][:ctr]['gi/run/' + params[:modulo] + '/' + params[:formato]]
      prm = @usu.pref[:permisos][:ctr]['gi/run/' + params[:modulo] + '/' + params[:formato]]
      return(false) unless @usu.admin or params[:modulo] == 'publico' || params[:modulo] == 'privado' || prm && prm[get_empeje[0].to_i]
    else
      ctr = params[:controller].split('/')
      if ctr.size == 1
        @gi_modulo = Rails.app_class.to_s.split(':')[0].downcase
        @gi_formato = ctr[0]
      else
        @gi_modulo = ctr[0]
        @gi_formato = ctr[1]
      end
    end

    @formato = GI.new(@gi_modulo, @gi_formato, @usu.codigo, nil)
    @form = @formato.formato

    if @form
      @titulo = @form[:descripcion] if @form[:descripcion] && !@form[:descripcion].strip.empty?
      if @form[:modelo]
        cl = h_constantize(@form[:modelo])
        if cl.respond_to?('ejercicio_path')
          @nivel = :j
        elsif cl.respond_to?('empresa_path')
          @nivel = :e
        end
        @titulo ||= 'Listado de ' + nt(cl.table_name)
      else
        @titulo ||= 'Listado'
      end
      @nivel ||= :g
      return true
    else
      render file: '/public/404.html', status: 404, layout: false
      return
    end
    #@form ? nil : {file: '/public/404.html', status: 404}
  end

  def before_envia_ficha
    @g[:go] = params[:go]
    @g[:info] = @titulo

    @fact.form_type = 'pdf'
    @fact.form_modulo = @gi_modulo
    @fact.form_file = @gi_formato

    @form[:lim].each {|c, v|
      @fact.add_campo(c, eval('{' + v + '}'))
    }
    @fact.campos.each {|c, v|
      @fact[c] = params[c] if params[c]
    }
    if @formato.respond_to?(:ini_campos)
      if @formato.method(:ini_campos).arity == 1
        @formato.ini_campos(@fact)
      elsif @formato.method(:ini_campos).arity == 2
        @formato.ini_campos(@fact, params)
      else
        @formato.ini_campos(@fact, params, @form)
      end
    end

=begin
    if @form[:modelo]
      begin
        cl = @form[:modelo].constantize
      rescue
        @form[:modelo][1..-1].constantize
        cl = @form[:modelo].constantize
      end
      tit = 'Listado de ' + nt(cl.table_name)
    else
      tit = 'Listado'
    end

    tit = @form[:descripcion] if @form[:descripcion] && !@form[:descripcion].strip.empty?
    set_titulo(tit, @e&.codigo, @j&.codigo)
=end

    if @formato.respond_to?(:before_envia_ficha)
      eval(@formato.before_envia_ficha)
    end
  end

  def mi_render
    if params[:go]
      @ajax_load << 'callFonServer("grabar");'
      render html: '', layout: 'basico_ajax'
    end
  end

  def gi_envia_datos
    envia_fichero(file: "#{@g[:fns]}.#{@fact.form_type}", file_cli: "#{@fact.form_file}.#{@fact.form_type}", rm: true, disposition: @fact.form_type == 'pdf' ? 'inline' : 'attachment', popup: @g[:go] ? :self : false)
  end

  def after_save
    label = 'Obteniendo información'
    exe_p2p(label: label, width: 400, cancel: true, info: @g[:info], tag: (@fact.form_type == 'xlsx' ? :xls : :loff), fin: :gi_envia_datos) {
      begin
        lim = {}
        @fact.campos.each {|c, v|
          cs = c.to_s
          if v[:cmph]
            lim[c] = @fact[cs[0..-4]].try(v[:cmph])
          elsif v[:rango]
            lim[c] = @fact[c].expande_rango
            lim[("#{cs}_rango").to_sym] = @fact[c]
          else
            lim[c] = @fact[c]
          end

          if cs.ends_with?('_id')
            lim[("#{cs}_value").to_sym] = @fact[c] ? forma_campo_id(v[:ref], @fact[c], :gi) : ''
          end
        }

        lim[:eid], lim[:jid] = get_empeje

        g = GI.new(@fact.form_modulo, @fact.form_file, @usu.codigo, lim)

        fns = "/tmp/nim#{@v.id}" #file_name_server
        fnc = @fact.form_file
        @g[:fns] = fns

        p2p label: label << '<br>Formateando datos'
        g.gen_xls("#{fns}.xlsx", @fact.form_type == 'pdf')

        case @fact.form_type
          when 'pdf'
            p2p label: label << '<br>Generando PDF'
            # LibreOffice, de momento, no es capaz de rodar instancias en paralelo. Parece que esto se va a
            # solucionar en la versión 5.3.0
            # Mientras tanto y como "workaround" se puede solventar forzando en cada instancia un directorio
            # distinto de configuración con la opción: -env:UserInstallation=file:///directorio_de_conf
            # Cuando el tema esté resuelto habría que quitar esta opción de la llamada a libreoffice.

            #`libreoffice --headless --convert-to pdf --outdir /tmp #{fns}.xlsx`
            #`libreoffice -env:UserInstallation=file://#{fns}_lo_dir --headless --convert-to pdf --outdir /tmp #{fns}.xlsx`
            h = spawn "libreoffice -env:UserInstallation=file://#{fns}_lo_dir --headless --convert-to pdf --outdir /tmp #{fns}.xlsx"
            Process.wait h
            FileUtils.rm_rf %W(#{fns}.xlsx #{fns}_lo_dir)
          when 'xls'
            p2p label: label << '<br>Generando XLS'
            # La misma historia que en el caso anterior

            #`libreoffice --headless --convert-to xls --outdir /tmp #{fns}.xlsx`
            #`libreoffice -env:UserInstallation=file://#{fns}_lo_dir --headless --convert-to xls --outdir /tmp #{fns}.xlsx`
            h = spawn "libreoffice -env:UserInstallation=file://#{fns}_lo_dir --headless --convert-to xls --outdir /tmp #{fns}.xlsx"
            Process.wait h
            FileUtils.rm_rf %W(#{fns}.xlsx #{fns}_lo_dir)
        end
      rescue => e
        FileUtils.rm_rf %W(#{fns}.xlsx #{fns}.xls #{fns}.pdf #{fns}_lo_dir)
        raise e
      end
    }
  end
end

=begin
##nim-doc {sec: 'Acceso externo', met: 'URLs'}
<pre>
URLS asociadas
--------------

/gi ==> Accede a la pantalla principal del GI (a la que te lleva el menú principal).
/gi/new ==> Accede a la pantalla desde la que se muestran todos los módulos con los
            modelos correspondientes (la pantalla antigua de inicio).
/gi/new/Modelo ==> Accede a la creación de un nuevo formato para el "Modelo" indicado.
/gi/edit/modulo/formato ==> Edita el formato "formato" del módulo "modulo".
/gi/run/modulo/formato ==> Abre la pantalla de límites para ejecutar el formato
                           "formato" del módulo "modulo".

En esta última URL se pueden pasar argumentos para indicar valores a límites. P.ej.:
/gi/run/conta/mayor?L1=00001&L2=99999
Además de los alias de límites que se hayan especificado en el formato, existe un
alias que es ':form_type' para indicar el formato de salida (:pdf, :xlsx, :xls)
Existe un argumento especial llamado 'go' que si tiene valor hará que el listado
salga directamente sin pasar por la pantalla de límites. Ej.:
/gi/run/conta/mayor?L1=00001&L2=99999&go=1
</pre>
##

##nim-doc {sec: 'Acceso externo', met: 'Nomenclatura de módulos'}
<pre>
Nomenclaturas de 'modulo'
-------------------------

privado: se refiere a "formatos/_usuarios/usuario"
publico: "formatos/_publico"
gestion: "formatos" (sustituir gestión por el nombre apropiado: cope, consejo, etc.)
modulo: "modulos/modulo/formatos"
</pre>
##

##nim-doc {sec: 'Programación', met: 'Hooks'}
<pre>
Métodos disponibles para definirlos en el fuente asociado al formato
--------------------------------------------------------------------

ini_campos(f, args)
  Este método se dispara sólo cuando entramos en la ventana de límites
  Recibe dos argumentos:
    f:    es la ficha con la que accedemos a las propiedades de los campos.
          Podemos acceder a un límite a través de su alias de dos formas:
          f.L1 o f[:L1]
          también está a nuestra disposición el método 'campos' a través del
          cual podemos acceder a todas las propiedades de éste. P.ej:
          f.campos[:L1][:manti] = 8
          f.campos[:L1][:tab] = nil (para que no se muestre el campo en pantalla)
    args: Es un hash conteniendo todas las parejas clave/valor recibidas
          en la URL como argumentos.

before_envia_ficha
  Este método se dispara sólo cuando entramos en la ventana de límites.
  Tiene por objeto devolver una cadena (¡ojo! tiene que ser UNA cadena)
  con código a ejecutar en el before_envia_ficha del contralador que
  recoge los límites. El código a usar es cualquiera que sea válido en
  ese contexto. Es decir, no hay que poner el código directamente como
  en cualquier método, sino encerrarlo en una cadena y devolverla.

before_sql
  Se dispara justo antes de hacer la consulta SQL correspondiente. Si el
  método le da valor a la variable @data, la SQL no se ejecutará y se usarán
  los datos contenidos en @data. @data es un array de arrays conteniendo los
  datos de cada fila que será procesada en el listado. Si le damos el valor:
  @data = [] conseguiremos que no se ejecute la SQL y además que no haya
  datos. De esta forma podríamos hacer un listado totalmente personalizado
  añadiendo bandas manualmente en los métodos 'inicio' o 'final'.

after_create_workbook
  Se dispara justo después de la creación del workbook y antes de la creación
  de la hoja (sheet) que se usará para alojar el listado (@sh). Esto nos
  permite poder crear una hoja de usuario anterior a la principal (p.ej para
  pintar una página de título independiente).

inicio
  Se dispara cuando va a comenzar el listado y aún no se ha echado ninguna
  banda (ni cabecera). Nos permite por ejemplo echar bandas previas a la
  cabecera, para por ejemplo, dejar hueco para alojar un gráfico estadístico.
  También nos permitiría alterar los datos en @data antes de empezar a
  procesarlo. Por ejemplo se podrían añadir "a traición" nuevas filas, o
  lo contrario, eliminar filas en función de determinadas condiciones.
  Podría ser un sustituto de fcon_listo (en ewin), pero haciendo el filtro
  completo de una sola vez y dejando ya los datos definitivos a pintar,
  evitando así falsas rupturas.

cabecera
  Si existe, sustituirá al pintado de la banda de cabecera (:cab) siendo
  responsabilidad del programador el añadir dicha banda (add_banda :cab).
  Se considerará cabecera (en el sentido de las filas que se repetirán
  como título en cada página) a todo lo que pinte este método. Tener en cuenta
  que si se pintan en este método otras bandas que no sean :cab (bandas de usuario)
  hay que forzar las rupturas a cero por si la cabecera es dinámica (para que
  no salten rupturas dentro de la propia cabecera). O sea, poner siempre:
  add_banda ban: :la_que_sea, rupa: 0, rup: 0

detalle
  Si existe este método, sustituirá al pintado estándar de la banda de detalle.
  Significando que asumimos el control y que es responsabilidad del programador
  el pintar dicha banda. Si tuviéramos:
  def detalle
    add_banda
  end
  Sería equivalente a no tener el método (lo que se haría por defecto).
  Se dispara cada vez que se procesa una nueva fila de @data

pie
  Si existe, sustituirá al pintado de la banda de pie (:pie) siendo
  responsabilidad del programador el añadir dicha banda (add_banda :pie).

final
  Se dispara al final del listado, después de pintar la banda 'pie'
</pre>
##

##nim-doc {sec: 'Programación', met: 'Métodos'}
<pre>
Métodos disponibles para usar dentro de los métodos anteriores
--------------------------------------------------------------

nueva_hoja(opciones)
  Sirve para crear una nueva hoja (sheet) en el workbook.
  'opciones' es un hash con las siguientes posibilidades:
  name: nombre de la hoja
  state: :visible|:hidden|:very_hidden (por defecto :visible)
         Indica la visibilidad de la hoja. Si es :hidden no se pintará
  page_setup: hash
              Las opciones de este hash son las descritas en la ayuda del GI
              para el apartado 'Configuración de página'
  page_margins: hash
              Las opciones de este hash son las descritas en la ayuda del GI
              para el apartado 'Márgenes'
  print_options: hash
              Las opciones de este hash son las descritas en la ayuda del GI
              para el apartado 'Opciones de impresión'
  Un ejemplo podría ser:
    nueva_hoja name: 'mi_hoja', page_setup: {orientation: :landscape}

  Al obtener el PDF se imprimirán en orden secuencial de creación todas las
  hojas cuyo 'state' sea :visible (por defecto)

add_banda(opciones)
  Añade una nueva banda al listado. 'opciones' es un hash con las siguientes
  claves (todas opcionales):
  rupa: nivel de 'ruptura anterior'. Por defecto se usará la que corresponda.
  rup:  nivel de 'ruptura siguiente'. Por defecto se usará la que corresponda.
  sheet: Hoja en la queremos echar la banda (por defecto @sh)
  ban: Banda que queremos echar (por defecto :det). La nomenclatura de las bandas
       es la siguiente:
       :cab    Banda de cabecera
       :det    Banda de detalle
       :pie    Banda de pie
       'rcn'   Banda de cabecera de ruptura 'n', siendo 0 la más exterior
       'rpn'   Banda de pie de ruptura 'n', siendo 0 la más exterior
       :bu_xx  Banda de usuario cuyo nombre es 'xx'
       :_blank Banda en blanco (para separador, por ejemplo)
       nil     Ninguna banda
  valores: Es un hash cuyas claves son alias de celdas y sus valores el valor que
           queremos asignarles.

  Si al añadir una banda especificamos 'ban: nil' querrá decir que no queremos
  pintar ninguna banda, pero sí gestionar las rupturas y por lo tanto dichas
  bandas (de ruptura) sí se pintarán.

val_select(cmp, fila=@d)
  Devuelve el valor del campo 'cmp' en la fila de datos 'fila',
  si no se especifica 'fila' se usará la actual.
  El valor de 'cmp' puede ser o bien 'Sn'
  refiriéndose al enésimo campo de la lista de Selects en el formato, o
  'modelo1.modelo2...campo' para referirse a un campo cualquiera de los usados
  en el formato. Ejemplos:
  Si partimos de la tabla 'clientes' (como modelo del formato), podríamos
  referenciar:
    'nombre_comercial'
    'agente.nombre'
    'agente.pais.codigo'

val_alias(alias, banda)
  Devuelve el valor del campo cuya celda tiene como alias 'alias' en la
  banda 'banda'. 'banda' es opcional, y si se omite vale por defecto ':det'

set_cmp_ban(ban, ali, val)
  Asigna el valor 'val' al campo de la casilla 'ali' de la banda 'ban'
  'ban' puede ser o bien un símbolo indicando el nombre de la banda
  o directamente el array que representa la banda.
</pre>
##

##nim-doc {sec: 'Programación', met: 'Variables'}
<pre>
Variables disponibles para usar en los métodos de usuario
---------------------------------------------------------

@form       Es un hash conteniendo el formato (tal cual está en el .yml)
@e          Es la ficha de la empresa por defecto
@dat        Es un hash vacío para poder almacenar variables de usuario
@data       Es un array de arrays conteniendo todas las filas de datos
            que se pintarán
@ds         @data.size - 1
@wb         Referencia al workbook
@sh         Hoja (sheet) principal
@di         Índice de datos (indica el índice en @data que se está procesando)
@ri         Índice de fila (row) por el que vamos en la Excel en la hoja @sh
@ris[hoja]  Índice de fila (row) por el que vamos en la Excel en la hoja 'hoja'
            @ris[@sh] sería equivalente a @ri. Si hemos creado una hoja p.ej.:
            @dat[:mi_hoja] = nueva_hoja name: 'mi_hoja'
            sabríamos el índice de fila por el que vamos con @ris[@dat[:mi_hoja]]
@lis[hoja]  Índice de fila (row) por el que vamos en la Excel en la hoja 'hoja'
            por página física (se resetea en cada nueva página)
@rupa       Ruptura con fila anterior actual
@rup        Ruptura con fila siguiente actual
@rup_ini[i] Índice de la primera fila de detalle correspondiente a la ruptura i.
            Siendo 0 el índice de la ruptura más exterior.
@fx         Es un hash con el valor calculado de las fórmulas de usuario.
            @fx[:F1] nos daría el valor de la fórmula 'F1'
@lim        Es un hash con el valor de los campos usados para límites.
            @lim[:L1] nos daría el valor del campo asociado al límite 'L1'
</pre>
##

##nim-doc {sec: 'Programación', met: 'Gráficos estadísticos'}
<pre>
Ejemplos de gráficos estadísticos que se podrían añadir
-------------------------------------------------------

@sh.add_chart(Axlsx::Pie3DChart, start_at: "D1", end_at: "J15", title: 'Tarta') do |chart|
  chart.add_series data: @sh["B2:B6"], labels: @sh["A2:A6"], title: 'Hola', colors: ["00FF00", "0000FF", "FF0000", "d3d3d3", "FFA015"]
end

@sh.add_chart(Axlsx::Bar3DChart, start_at: "D16", end_at: "J30", title: 'Barras') do |chart|
  chart.add_series data: @sh["B2:B6"], labels: @sh["A2:A6"], colors: ["00FF00", "0000FF", "FF0000", "d3d3d3", "FFA015"]
  chart.valAxis.gridlines = true
  chart.catAxis.gridlines = true
  chart.catAxis.label_rotation = 45
  chart.catAxis.color = "888888"
  chart.show_legend = false
  chart.bar_dir = :col
end

@sh.add_chart(Axlsx::LineChart, title: 'Línea', start_at: "D30", end_at: "M50") do |chart|
  chart.add_series data: @sh["B2:B6"], title: @sh["A1"], color: "00FF00"
  chart.add_series data: @sh["C2:C6"], title: @sh["C1"], color: "0000FF", show_marker: true, smooth: true
  chart.catAxis.title = 'X Axis'
  chart.valAxis.title = 'Y Axis'
end

@sh.add_chart(Axlsx::ScatterChart, start_at: "D51", end_at: "M70", title: 'Scatter') do |chart|
  chart.add_series xData: @sh["B2:B6"], yData: @sh["C2:C6"], title: @sh["A1"], color: "FF0000"
end

Para los gráficos que necesitan un array de colores hay definidos varios arrays con colores razonables:
GI::Colors Es un array con 9 colores
GI::Colors20 Es un array con 20 colores
GI::Colors20d Es un array con 20 colores más suaves
</pre>
##
=end

class GI
  Colors = %w(4D4D4D 5DA5DA FAA43A 60BD68 F17CB0 B2912F B276B2 DECF3F F15854)
  Colors20 = %w(278ECF 4BD762 FFCA1F FF9416 D42AE8 535AD7 FF402C 83BFFF 6EDB8F FFE366 FFC266 D284BD 8784DB FF7B65 CAEEFC 9ADBAD FFF1B2 FFE0B2 FFBEB2 B1AFDB)
  Colors20d = %w(278ECF 4BD762 FFCA1F FF9416 D42AE8 535AD7 FF402C 83BFFF 6EDB8F 4D4D4D FFC266 D284BD 8784DB FF7B65 CAEEFC 9ADBAD FFF1B2 FFE0B2 FFBEB2 B1AFDB)

  def self.formato_read(modulo, file, user, cl=nil)
    case modulo
      when '', '_', Rails.app_class.to_s.split(':')[0].downcase
        path = 'formatos/'
      when 'publico'
        path = 'formatos/_publico/'
      when 'privado'
        path = "formatos/_usuarios/#{user}/"
      else
        path = "modulos/#{modulo}/formatos/"
    end

    # Cargar formato
    form = nil
    archivo = path + file + '.yml'
    if File.exist? archivo
      form = YAML.load(File.read(archivo))
    elsif path == 'formatos/'
      # Podría ser el caso de formatos con un controlador que está en un módulo no declarado como tal
      # Sin module asociado pero con carpeta propia. En este caso vamos a buscar el yml por todos los
      # módulos para ver si existe.
      Nimbus::Modulos[0..-2].each {|m|
        ar = m + '/' + archivo
        if File.exist? ar
          path = m + '/formatos/'
          form = YAML.load(File.read(ar))
          break
        end
      }
    end

    # Cargar fuentes si existen
    if cl && form
      cl.instance_eval(File.read(path + form[:fuente] + '.rb')) if File.exist?(path + form[:fuente].to_s + '.rb')
      cl.instance_eval(File.read(path + file + '.rb')) if File.exist?(path + file + '.rb')
    end

    form
  end

  def alias_cmp_db(cad, h_alias)
    return(nil) unless cad

    new_cad = ''
    cad.split('~').each_with_index {|c, i|
      c = h_alias[c][:cmp_db] if i.odd?
      new_cad << c
    }
    new_cad
  end

  def val_select(ali, d=@d)
    #i = (ali[0] == 'S' ? @ali_sel.index(ali.to_sym) : @vpluck.index(ali))
    i = (ali[0] == 'S' ? @ali_sel.index(ali.to_sym) : @ali_cmp[ali])
    (i and d) ? d[i] : nil
  end

  def val_alias(ali, ban=@form[:det])
    ban = @form[ban] if ban.is_a? Symbol
    ban.each {|fila|
      fila.each {|cmp|
        return(val_campo(cmp[:campo])) if cmp[:alias] == ali.to_s
      }
    }
    nil
  end

  def set_cmp_ban(ban, ali, val)
    ban = @form[ban] if ban.is_a? Symbol
    ban.each {|fila|
      fila.each {|cmp|
        cmp[:campo] = val if cmp[:alias] == ali.to_s
      }
    }
  end

  def procesa_macros(cad, vpl=true)
    return(nil) unless cad

    new_cad = ''
    cad.split('~').each_with_index {|c, i|
      if i.odd?
        if c[0] == 'S'  # Es un campo de select
          #c = "@d[#{@ali_sel.index(c.to_sym)}]"
          c = "f[#{@ali_sel.index(c.to_sym)}]"
        else
          @msel << c unless @msel.include?(c)
          if vpl
            ip = @vpluck.index(c)
            unless ip
              ip = @vpluck.size
              @vpluck << c
            end
            c = "f[#{ip}]"
          end
        end
      end
      new_cad << c
    }
    new_cad
  end

  def gen_alias(sym_ban, ban)
    ali = @alias[sym_ban] = {}
    ban.each_with_index {|r, nf |
      r.each_with_index {|h, nc|
        if h[:alias] and h[:alias] != ''
          ali[h[:alias].to_sym] = {col: ('A'.ord + nc).chr, row: nf}
        end

        # Procesar campos para sustituirlos por su posición en el vector vpluck y generar éste.
        h[:campo] = procesa_macros(h[:campo])
      }
    }
  end

  def eval_tit_macros(cad)
    if cad.is_a?(String)
      begin
        cad.gsub!('#e', @e.codigo)
        cad.gsub!('#E', @e.nombre)
        cad.gsub!('#j', @j.codigo)
        cad.gsub!('#J', @j.descripcion)
      rescue
      end
    end

    return cad
  end

  def initialize(modulo, form, user, lim={})
    @form = self.class.formato_read(modulo, form, user, self)

    return unless lim

    @dat = {} # Hash vacío para poder incluir variables de usuario
    @e = Empresa.find_by(id: lim[:eid]) if lim[:eid]
    @j = Ejercicio.find_by(id: lim[:jid]) if lim[:jid]

    @form[:modelo] = @form[:modelo].constantize if @form[:modelo]
    @form[:style].each {|k, v| @form[:style][k] = eval("[#{v}]")}
    @form[:page_margins] = eval("{#{@form[:page_margins]}}")
    @form[:page_setup] = eval("{#{@form[:page_setup]}}")
    @form[:print_options] = eval("{#{@form[:print_options]}}")
    @form[:print_options][:grid_lines] = true if @form[:pingrid]
    if @form[:row_height] and !@form[:row_height].strip.empty?
      @form[:row_height] = @form[:row_height].to_i
    else
      @form[:row_height] = nil
    end
    @form[:linxpag] = @form[:linxpag].to_i == 0 ? nil : @form[:linxpag].to_i
    @form[:cab_din] = false unless @form[:linxpag]
    @form[:cab_din_pdf] = true unless @form[:cab_din]

    @form[:tit_i] = @form[:tit_i].empty? ? '&B' + @e.try(:nombre).to_s + '&B' : eval_tit_macros(@form[:tit_i])
    @form[:tit_d] = @form[:tit_d].empty? ? '&P de &N' : eval_tit_macros(@form[:tit_d])
    if @form[:tit_c].empty?
      if @form[:descripcion].to_s.strip.empty?
        @form[:tit_c] = '&BListado de ' + nt(@form[:modelo].table_name) + '&B' if @form[:modelo]
      else
        @form[:tit_c] = @form[:descripcion].dup
      end
    else
      eval_tit_macros(@form[:tit_c])
    end

    @nr = @form[:rup] ? @form[:rup].size : 0

    @vpluck = []
    @msel = []
    @ali_sel = []
    @alias = {}
    @lim = lim
    @fx = {}

    # Procesar los wheres asociados a límites para borrarlos o adecuar su contenido
    # en función del parámetro 'sinil' asociado al límite
    @form[:lim].each {|l, v|
      va = v.gsub(',', '').split
      sinil = va.index('sinil:')
      if sinil && @lim[l].nil? && @form[:where][l]
        vs = va[sinil + 1]
        case vs
          when ':b'
            @form[:where].delete(l)
          when ':n', ':nn'
            unless @form[:where][l].include?('<') || @form[:where][l].include?('>')
              @form[:where][l] = @form[:where][l].split('=')[0] + " IS #{vs == ':nn' ? 'NOT ' : ''}NULL"
            end
        end
      end
    }
    before_sql if self.respond_to?(:before_sql)

    @nr = @form[:rup] ? @form[:rup].size : 0 # Por si before_sql altera el número de rupturas

    # Procesar select (1ª vuelta)
    @form[:select].each {|k, v|
      @ali_sel << k
      @vpluck << v
      procesa_macros(v, false)
    }
    # Generar el hash de 'alias' y pluck
    gen_alias(:cab, @form[:cab]) if @form[:cab]
    gen_alias(:det, @form[:det]) if @form[:det]
    gen_alias(:pie, @form[:pie]) if @form[:pie]

    @form[:rup].each_with_index {|r, i|
      r[:campo] = procesa_macros(r[:campo])
      gen_alias("rc#{i}", r[:cab]) if r[:cab]
      gen_alias("rp#{i}", r[:pie]) if r[:pie]
    }

    @form.each {|k, v| gen_alias(k, v) if k.to_s.starts_with?('bu_')}

    unless @data
      # Añadir where de empresa y ejercicio si procede
      if @form[:filt_emej]
        if @form[:modelo].respond_to?('ejercicio_path')
          jp = @form[:modelo].ejercicio_path
          jpi = jp + (jp.empty? ? '' : '.') + 'ejercicio_id'
          @form[:where]['_weje'] = '~' + jpi + '~' + ' = :jid'
        elsif @form[:modelo].respond_to?('empresa_path')
          ep = @form[:modelo].empresa_path
          epi = ep + (ep.empty? ? '' : '.') + 'empresa_id'
          @form[:where]['_wemp'] = '~' + epi + '~' + ' = :eid'
        end
      end

      # procesar where (1ª vuelta)
      @form[:where].each {|_, v|
        procesa_macros(v, false)
      }

      # procesar order (1ª vuelta)
      procesa_macros(@form[:order], false)

      # procesar group (1ª vuelta)
      procesa_macros(@form[:group], false)

      # procesar having (1ª vuelta)
      @form[:having].each {|_, v|
        procesa_macros(v, false)
      }

      # procesar join (1ª vuelta)
      procesa_macros(@form[:join], false)

      # Procesar fómulas
      @form[:formulas].each {|k, v| @form[:formulas][k] = procesa_macros(v)}

      # Procesar condición para pintado de la banda de detalle
      @form[:detalle_cond] = procesa_macros(@form[:detalle_cond])

      #@data = @form[:modelo].select(@form[:select]).ljoin(@form[:join]).where(@form[:where], lim).order(@form[:order])
      ms = mselect_parse @form[:modelo], @msel

      @join = ms[:cad_join]

      # procesar vpluck (2ª vuelta)
      @ali_cmp = {}
      nsel = @form[:select].size
      @vpluck.size.times {|i|
        if i < nsel # Los primeros son los selects
          @vpluck[i] = alias_cmp_db(@vpluck[i], ms[:alias_cmp])
        else
          @ali_cmp[@vpluck[i]] = i
          @vpluck[i] = ms[:alias_cmp][@vpluck[i]][:cmp_db]
        end
      }

      # procesar where (2ª vuelta)
      @where = ''
      @form[:where].each {|_, v|
        @where << ' AND ' unless @where.empty?
        @where << alias_cmp_db(v, ms[:alias_cmp])
      }

      # procesar order (2ª vuelta)
      @form[:order] = alias_cmp_db(@form[:order], ms[:alias_cmp])

      # procesar group (2ª vuelta)
      @form[:group] = alias_cmp_db(@form[:group], ms[:alias_cmp])

      # procesar having (2ª vuelta)
      @having = ''
      @form[:having].each {|_, v|
        @having << ' AND ' unless @having.empty?
        @having << alias_cmp_db(v, ms[:alias_cmp])
      }

      # procesar join (2ª vuelta)
      @form[:join] = alias_cmp_db(@form[:join], ms[:alias_cmp])

      # Obtener la query
      #@data = @form[:modelo].joins(@join).joins(@form[:join]).where(@where, lim).group(@form[:group]).having(@having, lim).order(@form[:order]).limit(200).pluck(*@vpluck)
      @data = @form[:modelo].joins(@join).joins(@form[:join]).where(@where, lim).group(@form[:group]).having(@having, lim).order(@form[:order]).pluck(*@vpluck)
    end
  end

  def formato
    @form
  end

  def cel(ali)
    ali = ali.to_sym
    # Si la fila del alias está por encima de @bi_din restar el número de filas que haya podido
    # pintar una cabecera dinámica que se haya colado por medio
    ajuste = @alias[@ban][ali][:row] < @bi_din ? @lincabdin : 0
    @alias[@ban][ali][:col] + (@ri_act - @bi - ajuste + @alias[@ban][ali][:row]).to_s
  end

  def rango(ali, niv = @rupi, offset = -1)
    ali = ali.to_sym
    col = @alias[:det][ali][:col]
    "#{col}#{@rup_ini[niv]}:#{col}#{@ri_act + offset}"
  end

  def tot(ali, niv = @rupi, offset = -1)
    "SUBTOTAL(9,#{rango(ali, niv, offset)})"
  end

  def val_campo(c, f=@d)
=begin
    if c.is_a? Symbol
      return f.method(c).call
    elsif c.is_a? Fixnum
      # Para el caso de que los datos sea un array y 'c' represente el índice
    elsif c.is_a? String
      return eval(c)
    else
      return c
    end
=end
    if c
      begin
        eval(c)
      rescue Exception => e
        Rails.logger.debug "######## ERROR al evaluar '#{c}'"
        Rails.logger.debug e.message
        Rails.logger.debug e.backtrace[0..10]
        Rails.logger.debug '############################'
        '¡ERROR!'
      end
    else
      nil
    end
  end

  def col_code(i)
    r='A'
    i.times{r.next!}
    r
  end

  def _add_banda(ban, valores={}, sheet)
    @ri_act = @ris[sheet]
    merg = []
    @lincabdin = 0
    @bi_din = 0
    ban.each_with_index {|r, i|
      if @form[:linxpag]
        if @lis[sheet] == -1 || @lis[sheet] == @form[:linxpag] && (@pdf || !@form[:cab_din_pdf])  # El caso -1 es cuando ha habido ruptura con salto
          sheet.add_page_break("A#{@ri_act}")
          @lis[sheet] = 0
          if ban != @form[:cab] and @form[:cab_din]
            lincabdin = @ri_act
            old_ban = @ban
            @ban = :cab
            self.respond_to?(:cabecera) ? method(:cabecera).call : _add_banda(@form[:cab], {}, sheet)
            @lincabdin = @ri_act - lincabdin
            @bi_din = i
            @ban = old_ban  # Reponemos @ban después de recursivarnos
          end
        end
        @lis[sheet] += 1
      end
      @bi = i
      res = []
      num_rows = 0
      r.each_with_index {|c, i|
        res << Nimbus.nimval(valores[c[:alias].to_s.to_sym] || val_campo(c[:campo]))
        cxl = c[:charxlin].to_i
        if cxl > 0 && res[-1]
          l = res[-1].size / cxl
          num_rows = l if l > num_rows
        end

        if c[:colspan].to_i > 0 or c[:rowspan].to_i > 0
          #merg << "#{('A'.ord + i).chr}#{@ri_act}:#{('A'.ord + i + c[:colspan].to_i).chr}#{@ri_act + c[:rowspan].to_i}"
          merg << "#{col_code(i)}#{@ri_act}:#{col_code(i + c[:colspan].to_i)}#{@ri_act + c[:rowspan].to_i}"
        end
      }
      sty = r.map {|c| c[:estilo].to_s.empty? ? @sty[:def] : @sty[c[:estilo].to_sym]}
      typ = r.map {|c| c[:tipo] ? (c[:tipo].empty? ? nil : c[:tipo].to_sym) : nil}
      #sheet.add_row res, style: sty, types: typ, height: @form[:row_height]
      sheet.add_row res, style: sty, types: typ, height: (num_rows == 0 ? @form[:row_height] : 13 * (num_rows+1))
      @ris[sheet] += 1
      @ri_act += 1
      @ri += 1 if sheet == @sh
    }
    merg.each {|m| sheet.merge_cells(m)}
  end

  def add_banda(rupa: @rupa, rup: @rup, ban: :det, valores: {}, sheet: @sh)
    # Si la banda es la cabecera pongo las rupturas a cero por si se dispara con cabeceras dinámicas
    rupa = rup = 0 if ban == :cab

    if ban == :_blank
      #_add_banda([[]], {}, sheet)
      #return
      banda = [[]]
    else
      banda = @form[ban]
    end

    (@nr - rupa...@nr).each {|i|
      @ban = "rc#{i}"
      @rupi = i + 1
      _add_banda(@form[:rup][i][:cab], valores, sheet)
      @rup_ini[i+1] = @ris[sheet]
    }

    if ban
      @rupi = 0
      @ban = ban
      #_add_banda(@form[ban], valores, sheet)
      _add_banda(banda, valores, sheet)
    end

    (@nr - 1).downto(@nr - rup).each {|i|
      @ban = "rp#{i}"
      @rupi = i + 1
      _add_banda(@form[:rup][i][:pie], valores, sheet)
      if @form[:rup][i][:salto] && (!@form[:no_salto_last_rup] || @di < @ds)
        sheet.add_page_break("A#{@ris[sheet]}") unless @form[:cab_din]
        @lis[sheet] = -1
      end
    }
  end

  def new_style(s, st)
    if s.is_a? Array
      s.each {|a|
        (a.is_a? Symbol) ? new_style(@form[:style][a], st) : st.deep_merge!(a)
      }
    else
      st.deep_merge!(s)
    end
  end

  def nueva_hoja(args)
    sh = @wb.add_worksheet(args)
    @ris[sh] = 1
    @lis[sh] = 0

    unless args[:header_footer]
      sh.header_footer.odd_header = "&L#{@form[:tit_i]}&C#{@form[:tit_c]}&R#{@form[:tit_d]}"
      sh.header_footer.odd_footer = "&L#{@form[:pie_i]}&C#{@form[:pie_c]}&R#{@form[:pie_d]}"
    end
    sh.page_setup.set(@form[:page_setup]) unless args[:page_setup]
    sh.page_margins.set(@form[:page_margins]) unless args[:page_margins]
    sh.print_options.set(@form[:print_options]) unless args[:print_options]
    #sh.print_options.grid_lines = true if @form[:pingrid]

    sh
  end

  def set_col_widths(sheet=@sh, w=@form[:col_widths])
    if w.is_a? Array
      sheet.column_widths(*w)
    else
      sheet.column_widths(*(w.split(',').map{|a| a == '0' ? nil : a.to_i}))
    end
  end

  def gen_xls(name=nil, pdf=false)
    name ||= Dir::Tmpname.make_tmpname('/tmp/', '.xlsx')
    @pdf = pdf

    # Procesar la banda de detalle para extraer campos a totalizar
=begin
    @ctot = {}
    @form[:det][:row][0].each_with_index {|c, i|
      if c.is_a? Array
        @ctot[c[0]] = {col: ('A'.ord + i).chr}
      end
    }
=end
    @ris = {} # Hash para llevar la fila (row index) de las hojas adicionales que se puedan crear
    @lis = {} # Hash para llevar el número de línea de impresión por página física de las hojas adicionales que se puedan crear

    xls = Axlsx::Package.new
    @wb = xls.workbook

    after_create_worbook if self.respond_to?(:after_create_worbook)

    @sh = nueva_hoja name: 'Uno'

    # Añadir estilos
    if @form[:style]
      @sty = {}
      @form[:style].each {|c, v|
        st = {}
        new_style(v, st)
        @sty[c] = @wb.styles.add_style(st)
      }
    end

    @ri = 1
    @rupa = @rup = 0
    @d = @data[0]
    @di = 0

    inicio if self.respond_to?(:inicio)
    @d = @data[0] # Por si 'inicio' ha alterado el array @data
    @di = 0
    @ds = @data.size - 1

    # Añadir banda de cabecera (si no hay método específico)
    row_ini_cab = @ri
    if self.respond_to?(:cabecera)
      method(:cabecera).call
    else
      add_banda rupa: 0, rup: 0, ban: :cab
    end

    unless @form[:cab_din]
      # Fijar las filas de cabecera para repetir en cada página
      @wb.add_defined_name("Uno!$#{row_ini_cab}:$#{@ri - 1}", :local_sheet_id => @sh.index, :name => '_xlnm.Print_Titles')
    end

    # Inicializar vector de rupturas (para llevar la fila de inicio de cada una)
    #@rup_ini = [@form[:cab].size + @ri - 1]
    @rup_ini = [@ri]

    @data.each_with_index {|dat, di|
      dat = [dat] unless dat.is_a?(Array)
      @d = dat
      @di = di

      # Procesar fórmulas
      f = dat
      @form[:formulas].each {|k, v|
        @fx[k] = eval(v)
      }

      # Calcular rupa
      if di == 0
        @rupa = @nr
      else
        @rupa = 0
        @form[:rup].each_with_index {|r, i|
          if val_campo(r[:campo], dat) != val_campo(r[:campo], @data[di-1])
            @rupa = @nr - i
            break
          end
        }
      end

      # Calcular rup
        if di == @ds
          @rup = @nr
        else
          @rup = 0
          @form[:rup].each_with_index {|r, i|
            if val_campo(r[:campo], dat) != val_campo(r[:campo], @data[di+1])
              @rup = @nr - i
              break
            end
          }
        end

      # Añadir banda de detalle (si no hay método específico)
      if self.respond_to?(:detalle)
        method(:detalle).call
      else
        add_banda ban: (eval(@form[:detalle_cond].to_s) ? nil : :det)
      end
    }

    @rupa = @rup = 0

    # Añadir banda de pie
    if self.respond_to?(:pie)
      method(:pie).call
    else
      add_banda rupa: 0, rup: 0, ban: :pie
    end

    # Método de final si existe
    final if self.respond_to?(:final)

    #@sh.column_widths(*(@form[:col_widths].split(',').map{|w| w == '0' ? nil : w.to_i})) if @form[:col_widths]
    set_col_widths

    xls.serialize(name)
    return name
  end
end
