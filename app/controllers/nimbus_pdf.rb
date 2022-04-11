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
  # Sobrecarga de métodos originales

  def initialize(opts = {})
    @documentos = {}
    @documentos_pag = [[0, nil]]  # Lo inicializamos con un centinela para cuando haya que referenciar el elemento anterior
    opts[:skip_page_creation] = true
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

      if @documento[:draw]
        canvas {
          @documento[:draw].each {|_k, v|
            if v[:color]
              fc = fill_color
              fill_color v[:color]
            end
            fill_rectangle [v[:at][0], v[:at][1]], v[:width], v[:height]
            fill_color fc if v[:color]
          }
        }
      end

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
    pag = page_number - @documentos_pag[-1][0] + 1
    ind = -1
    if page_number != page_count
      @documentos_pag.each_with_index {|p, i|
        if page_number < p[0]
          ind = i
          pag = page_number - @documentos_pag[i - 1][0] + 1
          break
        end
      }
    end
    return formato ? format(formato, {p: pag, tp: @documentos_pag[ind][0] - @documentos_pag[ind - 1][0]}) : pag
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
      span(v[:ancho], position: v[:pos]) {text (val[k] || v[:texto]).to_s, v}
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

    fix_vals = -> (k, v) {
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
      else
        v[:at] = [v[:at][0].to_f, v[:at][1].to_f]
        v[:width] = v[:width].to_f
        v[:height] = v[:height].to_f
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

    # Bandas de cabecera, pie y draw
    [:cab, :pie, :draw].each {|b| ndoc[b].each(&fix_vals) if ndoc[b]}

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
    text_box (val || v[:texto]).to_s, v
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
end

class NimbusPdf < NimbusPDF
end
