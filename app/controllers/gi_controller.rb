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
  def nuevo_mod(mod, path)
    Dir.glob(path).sort.each {|fic|
      ficb = Pathname(fic).basename.to_s

      next if File.directory?(fic)
      next if ficb == 'vista.rb'

      @tablas[mod] ||= []
      @tablas[mod] << ficb[0..-4].capitalize
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
    nuevo_form(Rails.app_class.to_s.split(':')[0].downcase, 'formatos', ext)

    Dir.glob('modulos/*').sort.each {|mod|
      nuevo_form(mod.split('/')[1], mod + '/formatos', ext) unless mod.ends_with?('/idiomas') or mod.ends_with?('/nimbus-core')
    }
  end

  def gi
    @titulo = nt('gi')
    all_files(true)
    @modo = 'edit'
  end

  def giv
    @titulo = nt('giv')
    all_files(true)
    @modo = 'run'
    render 'gi'
  end

  def new
    if params[:modelo]
      @modelo = params[:modelo]
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
      @modulo = 'privado'
      @formato = ''
      @form = {}
      all_files(false)
      render 'edita'
    else
      @titulo = nt('gi')
      @tablas = {}

      nuevo_mod(Rails.app_class.to_s.split(':')[0].downcase, 'app/models/*')

      Dir.glob('modulos/*').each {|mod|
        nuevo_mod(mod.split('/')[1].capitalize, mod + '/app/models/*')
      }
    end
  end

  def edita
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
    begin
      cl = params[:node].constantize
    rescue
      # Se supone que sería un histórico y está sin cargar su clase
      params[:node][1..-1].constantize
      cl = params[:node].constantize
    end

    data = []
    cl.column_names.each {|c|
      d = {}
      if c.ends_with?('_id')
        d[:label] = c[0..-4]
        d[:load_on_demand] = true
        d[:id] = cl.reflect_on_association(c[0..-4].to_sym).options[:class_name]
      else
        cs = c.to_sym
        d[:label] = c
        d[:table] = cl.table_name
        d[:pk] = cl.respond_to?(:pk) ? (c == cl.pk[-1]) : false
        d[:type] = cl.columns_hash[c].type
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
            d[:decim] = decim
            d[:estilo] = 'dec' + decim.to_s
          else
            d[:ali] = 'i'
        end
      end
      data << d
    }

    render json: data
  end

  def graba_fic
=begin
    file = 'formatos/' + params[:file] + '.yml'
    if params[:ow] == 'n' and File.exists?(file)
      render text: 'n'
      return
    end

    data = eval(params[:data])
    File.write(file, data.to_yaml)
    render text: 's'
=end
    begin
      case params[:modulo]
        when ''
          render text: 'n'
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
      render text: 's'
    rescue Exception => e
      pinta_exception(e)
      render text: 'n'
    end
  end

  def before_edit
    #@form = GI.formato_read(params[:modulo], params[:formato], @usu.codigo)
    @formato = GI.new(params[:modulo], params[:formato], @usu.codigo, nil)
    @form = @formato.formato
    @form ? nil : {file: '/public/404.html', status: 404}
  end

  def before_envia_ficha
    @fact.form_type = 'pdf'
    @fact.form_modulo = params[:modulo]
    @fact.form_file = params[:formato]

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

    if @form[:descripcion]
      @titulo = @form[:descripcion].strip.empty? ? tit : @form[:descripcion]
    else
      @titulo = tit
    end
  end

  def mi_render
    if params[:go]
      flash[:vista] = @v.id
      redirect_to '/gi/abrir'
    end
  end

  def after_save
    #@ajax << 'window.open("/gi/abrir/' + @fact.form_file + '?vista=' + params[:vista] + '", "_blank", "location=no, menubar=no, status=no, toolbar=no ,height=800, width=1000 ,left=" + (window.screenX + 10) + ",top=" + (window.screenY + 10));'
    @ajax << (@fact.form_type == 'pdf' ? 'window.open("/gi/abrir");' : 'window.location.href="/gi/abrir";')
    flash[:vista] = @v.id
  end

  def abrir
    vid = flash[:vista]
    @v = Vista.find_by id: vid
    if @v
      @fact = @v.data[:fact]
    else
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    lim = {}
    @fact.campos.each {|c, v|
      lim[c] = v[:cmph] ? @fact[c.to_s[0..-4]].try(v[:cmph]) : @fact[c]
    }

    lim[:eid], lim[:jid] = get_empeje

    g = GI.new(@fact.form_modulo, @fact.form_file, @usu.codigo, lim)

    fns = "/tmp/nim#{vid}" #file_name_server

    g.gen_xls("#{fns}.xlsx")

    #fnc = g.formato[:modelo] ? g.formato[:modelo].table_name : 'listado' #file_name_client
    fnc = @fact.form_file

    case @fact.form_type
      when 'pdf'
        `libreoffice --headless --convert-to pdf --outdir /tmp #{fns}.xlsx`
        send_data File.read("#{fns}.pdf"), filename: "#{fnc}.pdf", type: :pdf, disposition: 'inline'
        FileUtils.rm "#{fns}.pdf", force: true
      when 'xls'
        `libreoffice --headless --convert-to xls --outdir /tmp #{fns}.xlsx`
        send_data File.read("#{fns}.xls"), filename: "#{fnc}.xls"
        FileUtils.rm "#{fns}.pdf", force: true
      when 'xlsx'
        send_data File.read("#{fns}.xlsx"), filename: "#{fnc}.xlsx"
      else
        render nothing: true
    end

    FileUtils.rm "#{fns}.xlsx", force: true
  end
end

=begin
Clase GI

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

Nomenclaturas de 'modulo'
-------------------------

privado: se refiere a "formatos/_usuarios/usuario"
publico: "formatos/_publico"
gestion: "formatos" (sustituir gestión por el nombre apropiado: cope, consejo, etc.)
modulo: "modulos/modulo/formatos"

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
  como título en cada página) a todo lo que pinte este método.

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

val_select(cmp)
  Devuelve el valor del campo 'cmp'. El valor de 'cmp' puede ser o bien 'Sn'
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

Variables disponibles para usar en los métodos de usuario
---------------------------------------------------------

@form       Es un hash conteniendo el formato (tal cual está en el .yml)
@e          Es la ficha de la empresa por defecto
@dat        Es un hash vacío para poder almacenar variables de usuario
@data       Es un array de arrays conteniendo todas las filas de datos
            que se pintarán
@wb         Referencia al workbook
@sh         Hoja (sheet) principal
@di         Índice de datos (indica el índice en @data que se está procesando)
@ri         Índice de fila (row) por el que vamos en la Excel en la hoja @sh
@ris[hoja]  Índice de fila (row) por el que vamos en la Excel en la hoja 'hoja'
            @ris[@sh] sería equivalente a @ri. Si hemos creado una hoja p.ej.:
            @dat[:mi_hoja] = nueva_hoja name: 'mi_hoja'
            sabríamos el índice de fila por el que vamos con @ris[@dat[:mi_hoja]]
@rupa       Ruptura con fila anterior actual
@rup        Ruptura con fila siguiente actual
@rup_ini[i] Índice de la primera fila de detalle correspondiente a la ruptura i.
            Siendo 0 el índice de la ruptura más exterior.
@fx         Es un hash con el valor calculado de las fórmulas de usuario.
            @fx[:F1] nos daría el valor de la fórmula 'F1'
@lim        Es un hash con el valor de los campos usados para límites.
            @lim[:L1] nos daría el valor del campo asociado al límite 'L1'

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
=end

class GI
  Colors = %w(4D4D4D 5DA5DA FAA43A 60BD68 F17CB0 B2912F B276B2 DECF3F F15854)
  Colors20 = %w(278ECF 4BD762 FFCA1F FF9416 D42AE8 535AD7 FF402C 83BFFF 6EDB8F FFE366 FFC266 D284BD 8784DB FF7B65 CAEEFC 9ADBAD FFF1B2 FFE0B2 FFBEB2 B1AFDB)
  Colors20d = %w(278ECF 4BD762 FFCA1F FF9416 D42AE8 535AD7 FF402C 83BFFF 6EDB8F 4D4D4D FFC266 D284BD 8784DB FF7B65 CAEEFC 9ADBAD FFF1B2 FFE0B2 FFBEB2 B1AFDB)

  def self.formato_read(modulo, file, user, cl=nil)
    case modulo
      when '', '_', Rails.app_class.to_s.split(':')[0].downcase
        path = "formatos/"
      when 'publico'
        path = "formatos/_publico/"
      when 'privado'
        path = "formatos/_usuarios/#{user}/"
      else
        path = "modulos/#{modulo}/formatos/"
    end

    # Cargar formato
    form = YAML.load(File.read(path + file + '.yml'))

    # Cargar fuentes si existen
    if cl
      cl.instance_eval(File.read(path + form[:fuente] + '.rb')) if File.exists?(path + form[:fuente].to_s + '.rb')
      cl.instance_eval(File.read(path + file + '.rb')) if File.exists?(path + file + '.rb')
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

  def val_select(ali)
    #i = (ali[0] == 'S' ? @ali_sel.index(ali.to_sym) : @vpluck.index(ali))
    i = (ali[0] == 'S' ? @ali_sel.index(ali.to_sym) : @ali_cmp[ali])
    i ? @d[i] : nil
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
    if !cad.is_a?(String)
      cad
      return
    end
    begin
      cad.gsub!('#e', @e.codigo)
      cad.gsub!('#E', @e.nombre)
      cad.gsub!('#j', @j.codigo)
      cad.gsub!('#J', @j.descripcion)
    rescue
    end
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

    #@form[:tit_i] = '&B' + (lim[:eid] ? Empresa.find_by(id: lim[:eid]).nombre : '') + '&B' if @form[:tit_i].empty?
    @form[:tit_i] = @form[:tit_i].empty? ? '&B' + @e.try(:nombre) + '&B' : eval_tit_macros(@form[:tit_i])
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
    @alias[@ban][ali][:col] + (@ri_act - @bi + @alias[@ban][ali][:row]).to_s
  end

  def tot(ali, niv=@rupi)
    col = @alias[:det][ali][:col]
    "=SUBTOTAL(9,#{col}#{@rup_ini[niv]}:#{col}#{@ri_act - 1})"
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
        Rails.logger.fatal "######## ERROR al evaluar '#{c}'"
        Rails.logger.fatal e.message
        Rails.logger.fatal e.backtrace[0..10]
        Rails.logger.fatal '############################'
        '¡ERROR!'
      end
    else
      nil
    end
  end

  def _add_banda(ban, valores={}, sheet)
    @ri_act = @ris[sheet]
    merg = []
    ban.each_with_index {|r, i|
      @bi = i
      res = []
      r.each_with_index {|c, i|
        res << (valores[c[:alias].to_s.to_sym] || val_campo(c[:campo]))
        if c[:colspan].to_i > 0 or c[:rowspan].to_i > 0
          merg << "#{('A'.ord + i).chr}#{@ri_act}:#{('A'.ord + i + c[:colspan].to_i).chr}#{@ri_act + c[:rowspan].to_i}"
        end
      }
      sty = r.map {|c| c[:estilo].to_s.empty? ? @sty[:def] : @sty[c[:estilo].to_sym]}
      typ = r.map {|c| c[:tipo] ? (c[:tipo].empty? ? nil : c[:tipo].to_sym) : nil}
      #sheet.add_row res, style: r.map {|c| c[:estilo].to_s.empty? ? @sty[:def] : @sty[c[:estilo].to_sym]}, types: r.map {|c| c[:tipo] ? (c[:tipo].empty? ? nil : c[:tipo].to_sym) : nil}, height: @form[:row_height]
      sheet.add_row res, style: sty, types: typ, height: @form[:row_height]
      @ris[sheet] += 1
      @ri_act += 1
      @ri += 1 if sheet == @sh
    }
    merg.each {|m| sheet.merge_cells(m)}
  end

  def add_banda(rupa: @rupa, rup: @rup, ban: :det, valores: {}, sheet: @sh)
    if ban == :_blank
      _add_banda([[]], {}, sheet)
      return
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
      _add_banda(@form[ban], valores, sheet)
    end

    (@nr - 1).downto(@nr - rup).each {|i|
      @ban = "rp#{i}"
      @rupi = i + 1
      _add_banda(@form[:rup][i][:pie], valores, sheet)
      sheet.add_page_break("A#{@ris[sheet]}") if @form[:rup][i][:salto]
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

  def gen_xls(name=nil)
    name ||= Dir::Tmpname.make_tmpname('/tmp/', '.xlsx')

    # Procesar la banda de detalle para extraer campos a totalizar
=begin
    @ctot = {}
    @form[:det][:row][0].each_with_index {|c, i|
      if c.is_a? Array
        @ctot[c[0]] = {col: ('A'.ord + i).chr}
      end
    }
=end
    @ris = {} # Hash para llevar la fila (row index) de las páginas adicionales que se puedan crear

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
    ds = @data.size - 1

    # Añadir banda de cabecera (si no hay método específico)
    row_ini_cab = @ri
    if self.respond_to?(:cabecera)
      method(:cabecera).call
    else
      add_banda rupa: 0, rup: 0, ban: :cab
    end

    # Fijar las filas de cabecera para repetir en cada página
    #@wb.add_defined_name("Uno!$1:$#{@form[:cab].size}", :local_sheet_id => @sh.index, :name => '_xlnm.Print_Titles')
    @wb.add_defined_name("Uno!$#{row_ini_cab}:$#{@ri - 1}", :local_sheet_id => @sh.index, :name => '_xlnm.Print_Titles')

    # Inicializar vector de rupturas (para llevar la fila de inicio de cada una)
    @rup_ini = [@form[:cab].size + @ri - 1]

    @data.each_with_index {|dat, di|
      dat = [dat] unless dat.is_a?(Array)
      @d = dat
      @di = di

      # Procesar fórmulas
      f = dat
      @form[:formulas].each {|k, v|
        @fx[k] = eval(v)
      }

=begin

      # Añadir bandas de cabecera de ruptura
      if nr
        if di == 0
          add = true
        else
          add = false
          dat_a = @data[di-1]
        end

        @form[:rup].each_with_index {|r, i|
          @ban = "rc#{i}"
          @rupi = i + 1
          if add
            add_banda(r[:cab])
            @rup[i+1] = @ri
          else
            if val_campo(r[:campo], dat) != val_campo(r[:campo], dat_a)
              add_banda(r[:cab])
              @rup[i+1] = @ri
              add = true
            end
          end
        }
      end

      # Añadir banda de detalle
      @ban = :det
      @rupi = 0
      if self.respond_to?(:detalle)
        method(:detalle).call
      else
        add_banda(@form[:det]) unless eval(@form[:detalle_cond])
      end

      # Añadir bandas de pie de ruptura
      if nr
        if di == ds
          ir = 0
        else
          ir = nr
          dat_s = @data[di+1]
          @form[:rup].each_with_index {|r, i|
            if val_campo(r[:campo], dat) != val_campo(r[:campo], dat_s)
              ir = i
              break
            end
          }
        end

        (nr - 1).downto(ir).each {|i|
          @ban = "rp#{i}"
          @rupi = i + 1
          add_banda(@form[:rup][i][:pie])
          @sh.add_page_break("A#{@ri - 1}") if @form[:rup][i][:salto]
        }
      end
    }
=end

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
        if di == ds
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
