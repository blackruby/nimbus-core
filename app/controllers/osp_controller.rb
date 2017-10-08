class OspController < ApplicationController
  def index
    @assets_javascripts = @assets_stylesheets = %w(osp)

    unless Nimbus::Config[:osp] && flash[:ruta]
      Nimbus::Config[:excluir_paises]
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
      break unless File.exists?(nf)
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
      dx = File.exists?(d)

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
