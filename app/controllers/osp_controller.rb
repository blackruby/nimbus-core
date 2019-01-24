# Controlador para gestionar la oficina sin papeles (OSP)
#
# OSP proporciona un nuevo botón (una grapa) en cada ficha de todos
# los mantenimientos. Al pulsarlo se abrirá una carpeta en la que podemos
# subir archivos que quedarán asociados a la ficha en curso. También se 
# pueden crear subcarpetas. En cada archivo tenemos un menú contextual
# desde el que podemos descargar el archivo (si éste es susceptible de
# vista previa se mostrará ésta y desde ella se podrá descargar); borrarlo;
# renombrarlo; y si es un pdf y además existen otros pdfs nos ofrecerá otra
# opción para poder añadir dicho pdf a cualquiera de los existentes. Después
# de añadirlo, el original se borrará o no en función de la configuración.
#
# Para activar OSP es necesario añadir en el fichero config/nimbus-core.yml
# la directiva :osp: Su valor puede ser true o un hash.
# Si es true (:osp: true) estará activo con las opciones por defecto.
# Si es un hash, éstas son las posibles claves y valores (los que llevan un *
# entre paréntesis son los valores por defecto):
# :osp:
#   :pdf_add_rm: true|false(*)
#   :upload:
#     :pdf: :pre|:post|:version(*)
#     :version: :new(*)|:old|:no
# 
# Explicación de las posibles opciones:
#
# :pdf_add_rm: indica si después de añadir un pdf a otro (desde el menú
# contextual) el primero ha de ser borrado.
#
# :upload: => :pdf tiene tres valores:
# :pre => Indica que al subir un pdf, si ya existe un archivo con ese nombre
# el contenido del fichero subido se empalmará por delante al fichero existente.
# :post => Indica que al subir un pdf, si ya existe un archivo con ese nombre
# el contenido del fichero subido se empalmará por detrás al fichero existente.
# :version => Indica que al subir un pdf, si ya existe un archivo con ese nombre
# no se hará ninguna acción especial y el comportamiento será como el de cualquier
# otro tipo de archivo siguiendo las pautas indicadas en la opción (:upload: :version:)
#
# :upload: => :version tiene tres valores:
# :new => Indica que si al subir un archivo ya existe uno con ese nombre,
# se renombrará el archivo subido añadiéndole un número de versión entre
# paréntesis.
# :old => Indica que si al subir un archivo ya existe uno con ese nombre,
# se renombrará el archivo existente añadiéndole un número de versión entre
# paréntesis y subiendo el nuevo con el nombre inalterado.
# :no => Indica que si al subir un archivo ya existe uno con ese nombre,
# se reemplazará (machacará) con el nuevo.
#
# Nota: para poder empalmar pdfs se usa el comando de linux pdfunite.
# En las distribuciones estándar de Centos ya viene por defecto, en caso
# de no estar disponible habría que instalar con yum el paquete poppler-utils.

class OspController < ApplicationController
  def index
    @assets_javascripts = @assets_stylesheets = %w(osp)

    unless Nimbus::Config[:osp] && flash[:ruta]
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    @titulo = flash[:tit]
    path = "#{flash[:ruta]}/#{flash[:dir]}/*"
    @files = {}
    Dir.glob(path).sort.each {|f|
      name = f.split('/')[-1]
      h = @files[name] = {}
      if File.directory?(f)
        h[:type] = :folder
      else
        ty = name.split('.')
        if ty.size == 1
          h[:type] = :file
        else
          case ty[-1].downcase
            when 'pdf'
              h[:type] = :pdf
            when 'xls', 'xlsx', 'csv', 'ods'
              h[:type] = :xls
            when 'jpg', 'jpeg', 'svg', 'gif', 'png'
              h[:type] = :pic
            when 'txt'
              h[:type] = :txt
            when 'doc', 'docx', 'odt'
              h[:type] = :doc
            when 'ppt', 'pptx', 'odf'
              h[:type] = :ppt
            when 'zip', 'gzip', 'tar', 'tgz', 'bz2', 'gz'
              h[:type] = :zip
            else
              h[:type] = :file
          end
        end
      end
    }

    @dir = flash[:dir].to_s
    @prm = flash[:prm]

    @v = Vista.new
    @v.data = {ruta: flash[:ruta], dir: flash[:dir], tit: flash[:tit], prm: flash[:prm]}
    @v.save
  end

  def osp_flash_to_dat
    flash[:ruta] = @dat[:ruta]
    flash[:tit] = @dat[:tit]
    flash[:dir] = @dat[:dir]
    flash[:prm] = @dat[:prm]
  end

  def osp_abrir
    return unless params[:fol] && !params[:fol].include?('/') && @dat && @dat[:ruta]

    osp_flash_to_dat

    if params[:fol] == '..'
      dir_a = @dat[:dir].to_s.split('/')
      flash[:dir] = dir_a[0..-2].join('/')
    else
      flash[:dir] = "#{@dat[:dir]}/#{params[:fol]}"
    end

    @ajax << 'location.reload();'
  end

  def osp_mover
    return unless params[:org] && params[:dest] && @dat && @dat[:ruta] && @dat[:prm] != 'c'

    dest = params[:dest][0..1] == '..' ? '..' : params[:dest]
    return if dest == '..' && @dat[:dir].to_s.empty? || dest.include?('/')

    begin
      FileUtils.mv params[:org].select{|f| !f.include?('/')}.map{|f| "#{@dat[:ruta]}/#{@dat[:dir]}/#{f}"}, "#{@dat[:ruta]}/#{@dat[:dir]}/#{dest}", force: true
    rescue Exception => e
      pinta_exception(e, 'Error al mover los archivos')
      return
    end

    osp_flash_to_dat

    @ajax << 'location.reload();'
  end

  def osp_add
    return unless params[:org] && !params[:org].include?('/') && params[:dest] && !params[:dest].include?('/') && @dat && @dat[:ruta] && @dat[:prm] != 'c'

    conf = Nimbus::Config[:osp].is_a?(Hash) ? Nimbus::Config[:osp] : {}
    begin
      f1 = "#{@dat[:ruta]}/#{@dat[:dir]}/#{params[:dest]}".gsub(' ', '\ ')
      fo = "#{@dat[:ruta]}/#{@dat[:dir]}/#{params[:org]}"
      f2 = fo.gsub(' ', '\ ')
      fd = "/tmp/#{@v.id}"
      `pdfunite #{f1} #{f2} #{fd} && mv #{fd} #{f1}`
      if conf[:pdf_add_rm]
        FileUtils.rm_f(fo) if conf[:pdf_add_rm]
        osp_flash_to_dat
        @ajax << 'location.reload();'
      else
        mensaje 'Añadido'
      end
    rescue Exception => e
      pinta_exception(e, 'Error al añadir')
      return
    end
  end

  def osp_new_version(f)
    n = 1
    fa = f.split('.')
    s = fa.size == 1 ? 0 : -2
    nn = fa[s]
    nf = ''
    loop do
      fa[s] = "#{nn} (#{n})"
      nf = fa.join('.')
      break unless File.exist?(nf)
      n += 1
    end
    nf
  end

  def osp_upload
    return unless params[:osp] && @dat && @dat[:ruta] && @dat[:prm] != 'c'

    conf = Nimbus::Config[:osp].is_a?(Hash) ? Nimbus::Config[:osp] : {}

    params[:osp].each {|f|
      d = "#{@dat[:ruta]}/#{@dat[:dir]}/#{f.original_filename}"
      da = f.original_filename.split('.')
      dx = File.exist?(d)

      cpdf = conf.dig(:upload, :pdf) || :version

      if da[-1].downcase == 'pdf' && dx && cpdf != :version
        fo = d.gsub(' ', '\ ')
        fd = "/tmp/#{@v.id}"
        if cpdf == :pre
          f1 = f.path
          f2 = fo
        else
          f1 = fo
          f2 = f.path
        end

        `pdfunite #{f1} #{f2} #{fd} && mv -f #{fd} #{fo}`
      else
        if dx
          case conf.dig(:upload, :version) || :new
            when :new
              d = osp_new_version(d)
            when :old
              FileUtils.mv(d, osp_new_version(d))
          end
        end

        FileUtils.cp(f.path, d)
      end
    }

    osp_flash_to_dat

    render html: %Q(
          <script>
            $(window).load(function(){parent.location.reload();});
          </script>
        ).html_safe, layout: 'basico'
  end

  def osp_borrar
    return unless params[:files] && @dat && @dat[:ruta] && @dat[:prm] == 'p'

    begin
      FileUtils.rm_r params[:files].select{|f| !f.include?('/')}.map{|f| "#{@dat[:ruta]}/#{@dat[:dir]}/#{f}"}, force: true
    rescue Exception => e
      pinta_exception(e, 'Error al eliminar los archivos')
      return
    end

    osp_flash_to_dat

    @ajax << 'location.reload();'
  end

  def osp_new
    return unless params[:fol] && !params[:fol].include?('/') && @dat && @dat[:ruta] && @dat[:prm] != 'c'

    begin
      FileUtils.mkdir "#{@dat[:ruta]}/#{@dat[:dir]}/#{params[:fol]}"
    rescue Exception => e
      pinta_exception(e, 'Error al crear carpeta')
      return
    end

    osp_flash_to_dat

    @ajax << 'location.reload();'
  end

  def osp_rename
    return unless params[:org] && !params[:org].include?('/') && params[:dest] && !params[:dest].include?('/') && @dat && @dat[:ruta] && @dat[:prm] != 'c'

    begin
      FileUtils.mv "#{@dat[:ruta]}/#{@dat[:dir]}/#{params[:org]}", "#{@dat[:ruta]}/#{@dat[:dir]}/#{params[:dest]}"
    rescue Exception => e
      pinta_exception(e, 'Error al crear carpeta')
      return
    end

    osp_flash_to_dat

    @ajax << 'location.reload();'
  end

  def osp_descargar
    return unless params[:files] && @dat && @dat[:ruta]

    files = params[:files].select {|f| !f.include?('/')}
    return if files.empty?

    file = "#{@dat[:ruta]}/#{@dat[:dir]}/#{files[0]}"
    if files.size == 1 and !File.directory?(file)
      envia_fichero(file: file, rm: false, disposition: %w(pdf jpg jpeg gif png svg txt).include?(files[0].split('.')[-1].downcase) ? 'inline' : 'attachment', popup: true)
    else
      file = "/tmp/nim#{@v.id}.zip"
      dir = "#{@dat[:ruta]}/#{@dat[:dir]}".gsub(' ', '\ ')
      `cd #{dir}; zip -qr #{file} #{files.map {|f| "#{f}".gsub(' ', '\ ')}.join(' ')}`
      envia_fichero(file: file, rm: true, popup: true)
    end

  end
end
