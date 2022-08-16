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

##nim-doc {sec: 'Miscelánea', met: 'Campos :text'}
<pre>
El problema con las celdas que contienen campos con mucho texto es determinar qué altura
deben de tener, ya que no existe un modo automático que la adapte.
En primer lugar hay que tener en cuenta que en el estilo habría que habilitar la opción
de "wrap" (alignment: {wrap_text: true}) para que el texto se "doble". Si no, el texto
se truncaría al final de la celda. Es importante especificar una anchura concreta, ya que 
si no, la anchura se iría expandiendo hasta conseguir acomodar todo el texto.
Una vez establecida una anchura y la opción "wrap" habilitada ya conseguimos que el texto
se vaya "doblando" ocupando las filas que necesite.
Por defecto, una fila de la hoja de cálculo va a tener una altura fija y por lo tanto
no veríamos las líneas extra que se nos han podido crear. Para controlar la altura de la celda
podemos especificar un valor en el campo "Caracteres/Línea" (esto es una estimación que
tenemos que hacer de cuántos caracteres cabrán, de media, en una línea teniendo en cuenta la
anchura de la columna y el font elegido). Con esto se hará un cálculo del número de líneas
que se necesitan para pintar el texto. Una vez sabido el número de líneas, éste se 
multiplicartá por la altura que se haya especificado para esa fila (si no hay, se usará
el valor "Altura filas" de la configuración, y, si tampoco hay, se usará 13).
Si no especificamos "Caracteres/Línea" pero sí una altura de fila, se asumirá que esa
es la altura total (sin multiplicar por nada). GI interpreta que sólo hay una línea aunque
en realidad haya varias por el wrap. Esto es útil para "cajas" de texto fijas
en cabeceras o piés.
En cualquier caso, si no se especifica nada (ni altura de fila, ni caracteres/línea, ni
"Filas extra"), se ha fijado una anchura para la columna y en el estilo está hailitado el
"wrap", el GI hará un cálculo automático de esos valores (altura de fila y caracteres/línea)
basados el tipo de font y su tamaño.
Para evitar el automatismo sólo hay que especificar alguno de los valores indicados en
función del resultado que busquemos.
Otra forma de conseguir altura en una celda es utilizar "Filas extra", aunque en este
caso es sólo la celda la que gana altura, no toda la fila. Este método también es muy útil
para cajas en cabecra/piés y se puede compaginar con todo lo anterior.
Un último apunte: si el texto es enriquecido, para que el GI lo procese, hay que añadir
la clave "rich: true" en el estilo (si es un campo de un modelo y en @propiedades ya tiene
puesto "rich: true", se elegirá automáticamente el estilo "rich", que ya incluye dicha
clave). Si el texto no fuera enriquecido, no pasa nada por añadir la clave (salvo pérdida
de eficiencia).

</pre>
##
=end

class GiFormError < StandardError
end

class GI
  Colors = %w(4D4D4D 5DA5DA FAA43A 60BD68 F17CB0 B2912F B276B2 DECF3F F15854)
  Colors20 = %w(278ECF 4BD762 FFCA1F FF9416 D42AE8 535AD7 FF402C 83BFFF 6EDB8F FFE366 FFC266 D284BD 8784DB FF7B65 CAEEFC 9ADBAD FFF1B2 FFE0B2 FFBEB2 B1AFDB)
  Colors20d = %w(278ECF 4BD762 FFCA1F FF9416 D42AE8 535AD7 FF402C 83BFFF 6EDB8F 4D4D4D FFC266 D284BD 8784DB FF7B65 CAEEFC 9ADBAD FFF1B2 FFE0B2 FFBEB2 B1AFDB)

  def self.formato_read(modulo, file, user, cl=nil)
    case modulo
      when '', '_', Nimbus::Gestion
        path = "#{Nimbus::GiPath}/"
      when 'publico'
        path = "#{Nimbus::GiPath}/_publico/"
      when 'privado'
        path = "#{Nimbus::GiPath}/_usuarios/#{user}/"
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

  def self.run(modulo: '', formato:, lim: {}, fichero: nil)
    lim[:form_type] ||= 'pdf'

    g = GI.new(modulo, formato, '', lim)

    fx = g.gen_xls(fichero, lim[:form_type] == 'pdf')

    if lim[:form_type] == 'pdf'
      # LibreOffice, de momento, no es capaz de rodar instancias en paralelo. Parece que esto se va a
      # solucionar en la versión 5.3.0
      # Mientras tanto y como "workaround" se puede solventar forzando en cada instancia un directorio
      # distinto de configuración con la opción: -env:UserInstallation=file:///directorio_de_conf
      # Cuando el tema esté resuelto habría que quitar esta opción de la llamada a libreoffice.

      #`libreoffice --headless --convert-to pdf --outdir /tmp #{fns}.xlsx`
      dirtmp = "#{fx[0..-6]}_lo_dir"
      #`libreoffice -env:UserInstallation=file://#{dirtmp} --headless --convert-to pdf --outdir /tmp #{fx}`
      `libreoffice -env:UserInstallation=file://#{dirtmp} --headless --convert-to pdf --outdir #{Pathname(fx).dirname} #{fx}`
      FileUtils.rm_rf [fx, dirtmp]
      return fx[0..-5] + 'pdf'
    else
      return fx
    end
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

    if @form.nil?
      raise GiFormError, 'Formato inexistente o erróneo'
    end

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
    @form[:tit_d] = @form[:tit_d].empty? ? '&D   &P de &N' : eval_tit_macros(@form[:tit_d])
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
      @data = @form[:modelo].joins(@join).joins(@form[:join]).group(@form[:group]).order(@form[:order])
      @data = @data.where(@where, lim) if @where.present?
      @data = @data.having(@having, lim) if @having.present?
      @data = @data.pluck(*@vpluck)
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
    if c
      begin
        eval(c)
      #rescue Exception => e
      rescue StandardError, ScriptError => e
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

  # Parsea "text" para generar un objeto Axlsx::RichText
  # Devuelve el objeto y el nº de líneas estimado que ocupa

  def parse_rich(text, sz_def, cxl)
    ini_cont = lambda {|cont, n|
      (n..9).each {|i| cont[i] = i.even? ? '0' : '`'}
      cont
    }

    # Si el texto no es rich añadirle un tag para forzarlo
    text = '<p>' + text if text[0] != '<'

    tab_unit = ' ' * 4
    li = nil
    cont = ini_cont[[], 0]
    estilo_def = {font_name: 'Helvetica', sz: sz_def}
    estilo_def_c = {font_name: 'Courier', sz: sz_def}
    estilo = estilo_def.dup
    nnl = 0
    nlxsz = 0

    rt = Axlsx::RichText.new

    # Escaneo de todos los tags html del texto. En tt[0] estará el tag y en tt[1] el texto (de ese tag).
    text.scan(/<(.+?)>([^<]*)/).each {|tt|
      tag = tt[0]

      tab = tag.match(/indent-([1-9])/)
      tab = tab ? tab[1].to_i : 0
      rt.add_run(tab_unit * tab, estilo_def) if tab > 0

      color = tag.match(/rgb\((.+?)\)/)
      estilo[:color] = Prawn::Graphics::Color.rgb2hex(color[1].split(',')) if color

      if tag.include?('serif')
        estilo[:font_name] = 'Times New Roman'
      elsif tag.include?('monospace')
        estilo[:font_name] = 'Courier'
      end

      if tag.include?('small')
        estilo[:sz] = (sz_def * 0.7).round
      elsif tag.include?('large')
        estilo[:sz] = (sz_def * 1.8).round
        nlxsz = 1
      elsif tag.include?('huge')
        estilo[:sz] = (sz_def * 2.5).round
        nlxsz = 1
      end

      if tag.start_with? 'ol'
        li = :o
        ini_cont[cont, 0]
      elsif tag.start_with? 'ul'
        li = :u
      elsif tag.start_with? 'li'
        ini_cont[cont, tab + 1]
        rt.add_run(tab_unit, estilo_def)
        rt.add_run((li == :u ? "\u2022" : cont[tab].next! + '.'), estilo_def_c)
        rt.add_run(' ', estilo_def)
      elsif tag.start_with? 'strong'
        estilo[:b] = true
      elsif tag.start_with? 'em'
        estilo[:i] = true
      elsif tag == 'u' || tag.start_with?('u ')
        estilo[:u] = true
      elsif tag == 's' || tag.start_with?('s ')
        estilo[:strike] = true
      end

      if tt[1] != ''
        t = tt[1].gsub('&lt;', '<').gsub('&gt;', '>')
        rt.add_run(t, estilo)
        nnl += t.size / cxl if cxl > 0
        estilo = estilo_def.dup
      end

      if %w(/p /l).include?(tag[0..1])
        rt.add_run("\n")
        if cxl > 0
          nnl += 1 + nlxsz
          nlxsz = 0
        end
      end
    }

    nnl -= 1 if text.ends_with?('</p>') || text.ends_with?('</li>')

    [rt, nnl]
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
      
      sty = r.map {|c| c[:estilo].to_s.empty? ? @sty[:def] : @sty[c[:estilo].to_sym]}
      typ = r.map {|c| c[:tipo] ? (c[:tipo].empty? ? nil : c[:tipo].to_sym) : nil}
      
      res = []
      num_rows = 0
      r.each_with_index {|c, i|
        estilo = @estilos[sty[i]]
        texto = Nimbus.nimval(valores[c[:alias].to_s.to_sym] || val_campo(c[:campo]))
        if estilo[:rich]
          rt = parse_rich(texto, estilo[:sz] || 10, c[:charxlin].to_i)
          res << rt[0]
          num_rows = rt[1] if rt[1] > num_rows
        else
          res << texto
          cxl = c[:charxlin].to_i
          if cxl > 0 && res[-1]
            l = res[-1].size / cxl
            num_rows = l if l > num_rows
          end
        end

        if c[:colspan].to_i > 0 or c[:rowspan].to_i > 0
          merg << "#{col_code(i)}#{@ri_act}:#{col_code(i + c[:colspan].to_i)}#{@ri_act + c[:rowspan].to_i}"
        end
      }
      altura = r[0] ? r[0][:height].to_i : 0
      altura = @form[:row_height] if altura == 0
      sheet.add_row res, style: sty, types: typ, height: (num_rows == 0 ? altura : (altura ? altura : 13) * (num_rows+1))
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
    #name ||= '/tmp/' + Dir::Tmpname.make_tmpname('nim', '.xlsx')
    name ||= nim_tmpname('/tmp/', '.xlsx')
    name << '.xlsx' unless name.ends_with?('.xlsx')
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

    after_create_workbook if self.respond_to?(:after_create_workbook)

    @sh = nueva_hoja name: 'Uno'

    # Añadir estilos
    @estilos = []
    if @form[:style]
      @sty = {}
      @form[:style].each {|c, v|
        st = {}
        new_style(v, st)
        @sty[c] = @wb.styles.add_style(st)
        @estilos[@sty[c]] = st
      }
    end

    # Calcular valores razonables para alturas de fila y nº de caracteres por fila (si está
    # activado wrap_text) en función del tipo de fuente y su tamaño.
    # El cálculo sólo se hará si no hay valores especificados y si la versión del GI > 1

    if @form[:version].to_f > 1
      cw = @form[:col_widths].split(',').map(&:to_i)
      # mu es un hash con los valores del ancho medio que ocupa un carácter en cada font (el default es Arial)
      mu = {'Times New Roman' => 2.48, 'Courier' => 1.67}
      mu.default = 2.25
      ([:cab, :det, :pie] + @form.keys.select{|b| b[0..2] == 'bu_'}).each {|ban|
        @form[ban].each {|r|
          if r[0] && r[0][:height].to_i == 0 
            msz = 10
            r.each_with_index {|c, i|
              st = c[:estilo] ? @estilos[@sty[c[:estilo].to_sym]] : {}
              msz = [msz, st[:sz].to_i].max
              if cw[i].to_i != 0 && st.dig(:alignment, :wrap_text) && c[:charxlin].to_i == 0 && c[:rowspan].to_i == 0
                c[:charxlin] = (12.0 * mu[st[:font_name]] * cw[i].to_i / (mu.default * ((st[:sz] || 10).to_i))).round
              end
            }
            r[0][:height] = msz * 13 / 10 if @form[:row_height].to_i == 0
          end
        }
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

    set_col_widths

    xls.serialize(name)
    return name
  end
end

class Gi < GI
end
