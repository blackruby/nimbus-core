# Para convertir pdf a png y usarlo como fondo:
# pdftoppm input.pdf outputname -png
# Si hiciera falta mayor resolución (densidad dpi) se puede usar
# pdftoppm input.pdf outputname -png -r 300
# Por defecto usa  una dpi de 150, que en general es suficiente, e incluso
# para que no ocupe mucho el pdf final hasta se podría bajar un poco:
# pdftoppm input.pdf outputname -png -r 120
# El comando pdftoppm es parte de la suite poppler-utils. Si no está instalado
# hay que instalarlo con "yum -y install poppler-utils"

Prawn::Font::AFM.hide_m17n_warning = true

class NimbusPDF < Prawn::Document
  # Clase para pintar un rectángulo en textos rich con background-color.
  # Se irá creando un objeto de esta clase por cada nuevo color y se
  # guardarán en @rich_bg_colors para reaprovecharlos.

  class RichBgColor
    def initialize(color, doc)
      @color = color
      @doc = doc
    end

    def render_behind(text)
      oc = @doc.fill_color
      @doc.fill_color = @color
      @doc.fill_rectangle(text.top_left, text.width, text.height)
      @doc.fill_color = oc
    end
  end

  # Sobrecarga de métodos originales

  def initialize(opts = {})
    @documentos = {}
    @documentos_pag = []
    opts[:skip_page_creation] = true
    @rich_bg_colors = {}
    super
  end

  def start_new_page(h = {})
    # Ponemos el pie de la página anterior (antes de llamar a super)
    # Solo en el caso de páginas regulares (!orphan) y cuando
    # no sea la primera página de un documento (!nuevo)
    unless h[:orphan] || h[:nuevo]
      pon_pie
    end

    super

    @fondo = h[:fondo] if h[:nuevo]

    unless h[:orphan]
      canvas {image @fondo, :at => bounds.top_left, width: bounds.right, height: bounds.top} if @fondo

      pon_draw @documento[:draw]
      pon_cabecera
    end
  end

  def page_number(formato = nil)
    formato ? format(formato, {p: super(), tp: page_count}) : super()
  end
    
  # Métodos propios

  attr_reader :documento

  def cabecera(lam)
    @cabecera = lam 
  end

  def pie(lam)
    @pie = lam 
  end

  def page_number_doc(formato = nil)
    p = page_number

    if p < @documentos_pag[-1][0]
      pag = tp = 0
      @documentos_pag.each_with_index {|d, i|
        if p < d[0]
          pag = p - @documentos_pag[i - 1][0] + 1
          tp = d[0] - @documentos_pag[i - 1][0]
          break
        end
      }
    else
      pag = p - @documentos_pag[-1][0] + 1
      tp = page_count - @documentos_pag[-1][0] + 1
    end

    formato ? format(formato, {p: pag, tp: tp}) : pag
  end
    
  def nuevo_doc(doc: '', tit: nil, cab: nil, pie: nil)
    @documentos_pag << [page_number + 1, doc]
    cargar_documento(doc)

    @cabecera = cab if cab
    @pie = pie if pie
    @cabecera ||= {}
    @pie ||= {}

    start_new_page @documento[:pag]
    outline.page title: tit, destination: page_number if tit

    if block_given?
      yield
      fin_doc
    end
  end

  def fin_doc
    pon_pie true
  end

  def nuevo_doc_banda(doc:, val: {})
    doc_act = @documento
    cargar_documento(doc)
    doch = @documento.deep_dup
    @documento = doc_act

    start_new_page if doch[:_altura_si_banda_] > cursor

    offset = cursor - doch[:_max_y_] + @documento[:pag][:bottom_margin]
    [doch[:cab], doch[:draw]].compact.each {|b|
      b.each {|k, v|
        v[:at][1] += offset if v[:at]
        v[:at_r][1] += offset if v[:at_r]
      }
    }

    pon_draw doch[:draw]
    nueva_banda_cp(doch[:cab], val)
    move_cursor_to cursor - doch[:_altura_si_banda_]
  end

  def nueva_banda(ban: :det, val: {})
    ban = @documento[:ban][ban]
    max_pag = act_pag = page_number
    min_cur = act_cur = cursor
    ban.each {|k, v|
      go_to_page act_pag
      move_cursor_to act_cur

      if v[:font]
        fo = font
        font v[:font]
      end
      span(v[:ancho], position: v[:pos]) {
        t = (val[k] || v[:texto]).to_s
        if t[0] == '<' && %w(p o u).include?(t[1])
          # Asumimos que es texto enriquecido (rich)
          formatted_text rich2prawn(t, v[:size] || 12), v
        else
          text t, v
        end
      }
      set_font fo if v[:font]

      pag = page_number
      if pag > max_pag
        max_pag = pag
        min_cur = cursor
      elsif pag == max_pag
        min_cur = cursor if cursor < min_cur
      end
    }

    go_to_page max_pag
    move_cursor_to min_cur
  end

  def pon_elementos(ban, els)
    ban = ban.to_sym
    return unless ban == :cab || ban == :pie

    ind = -1
    @documentos_pag.each_with_index {|p, i|
      if page_number < p[0]
        ind = i - 1
        break
      end
    }
    cargar_documento @documentos_pag[ind][1]

    els.each {|k, v| canvas {_pon_elemento(@documento[ban][k], v)} if @documento[ban][k]} if @documento[ban]
  end

  private

  def cargar_documento(doc)
    # Si ya está cargado, usar su hash
    if @documentos[doc]
      @documento = @documentos[doc]
      return
    end

    if doc.is_a? String
      file = doc.ends_with?('.yml') ? doc.dup : doc + '.yml'
      if file[0] == '/'
        # Path absoluto. Usamos la ruta tal cual
        yml = file
      elsif file[0..1] == '~/'
        # Asumimos que el path es desde la raíz del proyecto
        yml = Rails.root.to_s + file[1..-1]
      else
        # Asumimos que la ruta es relativa a la carpeta donde reside el controlador
        # que hace la llamada o a una carpeta con el nombre base del controlador
        # Asumimos también que si doc es una cadena vacía el nombre del yml será igual al nombre base del controlador
        ctrl = caller_locations[1].path
        us = ctrl.rindex('/')
        file = ctrl[us+1..-15] + '.yml' if doc.empty?
        yml = ctrl[0..-15] + '/' + file
        yml = ctrl[0..us] + file unless File.file? yml
      end
      ndoc = YAML.load(File.read(yml))
      path = yml[0..yml.rindex('/')]
    elsif doc.is_a? Hash
      ndoc = doc.deep_dup
      path = caller_locations[1].path
      path = path[0..path.rindex('/')]
    else
      raise ArgumentError, 'El documento tiene que ser un String o un Hash'
    end

    # Adecuar valores del hash del documento

    # Valores por defecto
    t = ndoc[:def] ||= {}
    t[:font] ||= 'Helvetica'
    t[:font_size] = t[:font_size] ? t[:font_size].to_f : 12
    t[:leading] = t[:leading] ? t[:leading].to_f : 0

    # Valores de página
    t = ndoc[:pag] ||= {}
    t[:size] = [t[:size][0].to_f, t[:size][1].to_f] if t[:size].is_a? Array
    t[:size] ||= 'A4'
    t[:layout] = t[:layout] ? t[:layout].to_sym : :portrait
    t[:top_margin] = t[:top_margin] ? t[:top_margin].to_f : 0
    t[:bottom_margin] = t[:bottom_margin] ? t[:bottom_margin].to_f : 0
    t[:left_margin] = 0
    t[:right_margin] = 0
    t[:fondo] = ruta_imagen(t[:fondo], path) if t[:fondo]
    t[:nuevo] = true  # Para distinguir que es un nuevo doc.

    fix_common_vals = -> (v) {
      v[:align] = v[:align].to_sym if v[:align]
      v[:style] = v[:style].to_sym if v[:style]
      v[:size] = v[:size].to_f if v[:size]
      v[:leading] = v[:leading].to_f if v[:leading]
      v[:color] = v[:color][1..-1] if v[:color]
    }

    min_y = 99999.0
    max_y = 0

    fix_vals = Proc.new {|k, v|
      if v[:borde] || v[:bgcolor]
        pl = v[:pad_l].to_f
        pr = v[:pad_r].to_f
        pt = v[:pad_t].to_f
        pb = v[:pad_b].to_f
        v[:at_r] = [v[:at][0].to_f, v[:at][1].to_f]
        v[:at] = [v[:at_r][0] + pl, v[:at_r][1] - pt]
        v[:width_r] = v[:width].to_f
        v[:width] = v[:width_r] - pl - pr
        v[:height_r] = v[:height].to_f
        v[:height] = v[:height_r] - pt - pb
        min_y = [min_y, v[:at_r][1] - v[:height_r]].min
        max_y = [max_y, v[:at_r][1]].max
      else
        v[:at] = [v[:at][0].to_f, v[:at][1].to_f]
        v[:width] = v[:width].to_f
        v[:height] = v[:height].to_f
        min_y = [min_y, v[:at][1] - v[:height]].min
        max_y = [max_y, v[:at][1]].max
      end
      v[:valign] = v[:valign] ? v[:valign].to_sym : :center
      v[:overflow] = v[:overflow].to_sym if v[:overflow]
      v[:min_font_size] = v[:min_font_size].to_f if v[:min_font_size]
      v[:imagen] = ruta_imagen(v[:imagen], path) if v[:imagen]
      v[:bgcolor] = v[:bgcolor][1..-1] if v[:bgcolor]
      fix_common_vals[v]
      v[:borde] = v[:borde].to_f if v[:borde]
      v[:brcolor] = v[:brcolor][1..-1] if v[:brcolor]
    }

    # Bandas de cabecera y draw
    [:cab, :draw].each {|b| ndoc[b].each(&fix_vals) if ndoc[b]}
    ndoc[:_max_y_] = max_y
    ndoc[:_altura_si_banda_] = max_y - min_y

    # Banda de pie
    ndoc[:pie].each(&fix_vals) if ndoc[:pie]

    # Bandas de detalle
    if ndoc[:ban]
      ndoc[:ban].each {|_k, b|
        b.each {|_k, v|
          v[:pos] = v.delete(:at)[0].to_f
          v[:ancho] = v.delete(:width).to_f
          fix_common_vals[v]
        }
      }
    end

    # Almacenar los hashes de cada documento para que al reutilazarlos no haya que procesarlos de nuevo
    @documentos[doc] = ndoc
    @documento = ndoc
  end

  def ruta_imagen(img, path)
    if img[0] == '/'
      # Path absoluto. Usamos la ruta tal cual
      return img
    elsif img[0..1] == '~/'
      # Asumimos que el path es desde la raíz del proyecto
      return Rails.root.to_s + img[1..-1]
    else
      # Asumimos que la ruta es relativa a la carpeta donde reside el yml
      return path + img
    end
  end

  def _pon_elemento(v, val = nil)
    if v[:borde]
      lw = line_width
      line_width v[:borde]
      if v[:brcolor]
        sc = stroke_color
        stroke_color v[:brcolor]
      end
      stroke_rectangle v[:at_r], v[:width_r], v[:height_r]
      line_width lw
      stroke_color sc if v[:brcolor]
    end

    if v[:bgcolor]
      fc = fill_color
      fill_color v[:bgcolor]
      fill_rectangle v[:at_r], v[:width_r], v[:height_r]
      fill_color fc
    end

    image v[:imagen], at: v[:at], fit: [v[:width], v[:height]] if v[:imagen]
    
    if v[:font]
      fo = font
      font v[:font]
    end

    if v[:color]
      fc = fill_color
      fill_color v[:color]
    end

    t = (val || v[:texto]).to_s
    if t[0] == '<' && %w(p o u).include?(t[1])
      # Asumimos que es texto enriquecido (rich)
      formatted_text_box rich2prawn(t, v[:overflow] == :shrink_to_fit ? 0 : (v[:size] || 12)), v
    else
      text_box t, v
    end

    set_font fo if v[:font]
    fill_color fc if v[:color]
  end

  def nueva_banda_cp(ban, val)
    canvas {
      ban.each {|k, v|
        _pon_elemento(v, val[k]) unless v[:render]
      }
    }
  end
        
  def pon_draw(banda)
    return unless banda
    canvas {
      banda.each {|_k, v|
        if v[:color]
          fc = fill_color
          fill_color v[:color]
        end
        fill_rectangle [v[:at][0], v[:at][1]], v[:width], v[:height]
        fill_color fc if v[:color]
      }
    }
  end

  def pon_cabecera
    return unless @documento[:cab]

    if @cabecera.is_a? Hash
      val_cab = @cabecera
    else
      # Asumimos que @cabecera es un lambda
      val_cab = @cabecera.call
    end

    nueva_banda_cp(@documento[:cab], val_cab)
  end

  def pon_pie(fin = false)
    return unless @documento[:pie]

    if @pie.is_a? Hash
      val_pie = @pie
    else
      # Asumimos que @pie es un lambda
      val_pie = @pie.arity == 1 ? @pie.call(fin) : @pie.call
    end

    nueva_banda_cp(@documento[:pie], val_pie)
  end

  def rich2prawn(htm, sz = 0)
    estilo_def = lambda {
      h = {font: 'Helvetica', styles: []}
      h[:size] = sz if sz > 0
      h
    }

    ini_cont = lambda {|cont, n|
      (n..9).each {|i| cont[i] = i.even? ? '0' : '`'}
      cont
    }

    tab_unit = Prawn::Text::NBSP * 8
    li = nil
    cont = ini_cont[[], 0]
    estilo_d = estilo_def[]
    estilo_d_c = estilo_def[].merge({font: 'Courier'})
    estilo = estilo_def[]
    tb = []

    htm.scan(/<(.+?)>([^<]*)/).each {|tt|
      tag = tt[0]

      tab = tag.match(/indent-([1-9])/)
      tab = tab ? tab[1].to_i : 0
      tb << {text: tab_unit * tab}.merge(estilo_d) if tab > 0

      color = tag.match(/[^-]color: rgb\((.+?)\)/)
      estilo[:color] = format('%02X%02X%02X', *color[1].split(',')) if color

      bgcolor = tag.match(/[-]color: rgb\((.+?)\)/)
      if bgcolor
        rgb = format('%02X%02X%02X', *bgcolor[1].split(','))
        puts rgb
        @rich_bg_colors[rgb] = RichBgColor.new(rgb, self) unless @rich_bg_colors[rgb]
        estilo[:callback] = @rich_bg_colors[rgb]
      end

      if tag.include?('serif')
        estilo[:font] = 'Times-Roman'
      elsif tag.include?('monospace')
        estilo[:font] = 'Courier'
      end

      if sz > 0
        if tag.include?('small')
          estilo[:size] = sz * 0.7
        elsif tag.include?('large')
          estilo[:size] = sz * 1.8
        elsif tag.include?('huge')
          estilo[:size] = sz * 2.5
        end
      end

      if tag.starts_with? 'ol'
        li = :o
        ini_cont[cont, 0]
      elsif tag.starts_with? 'ul'
        li = :u
      elsif tag.starts_with? 'li'
        ini_cont[cont, tab + 1]
        tb << {text: tab_unit}.merge(estilo_d)
        tb << {text: (li == :u ? "\u2022" : cont[tab].next! + '.')}.merge(estilo_d_c)
        tb << {text: ' '}.merge(estilo_d)
      elsif tag.starts_with? 'strong'
        estilo[:styles] << :bold
      elsif tag.starts_with? 'em'
        estilo[:styles] << :italic
      elsif tag == 'u' || tag.starts_with?('u ')
        estilo[:styles] << :underline
      elsif tag == 's' || tag.starts_with?('s ')
        estilo[:styles] << :strikethrough
      end

      if tt[1] != ''
        tb << {text: tt[1].gsub('&lt;', '<').gsub('&gt;', '>')}.merge(estilo)
        estilo = estilo_def[]
      end

      tb << {text: "\n"} if %w(/p /l).include?(tag[0..1])
    }
    tb
  end
end
