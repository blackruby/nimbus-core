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
        h[:type] = 'folder'
      else
        ty = name.split('.')
        if ty.size == 1
          h[:type] = 'file'
        else
          ext = ty[-1][0..2]
          #h[:type] = %w(pdf xls txt zip doc ppt).include?(ext) ? ext : 'file'
          h[:type] = %w(pdf xls).include?(ext) ? ext : 'file'
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

  def osp_upload
    return unless params[:osp] && @dat && @dat[:ruta] && @dat[:prm] != 'c'

    params[:osp].each {|f| FileUtils.cp(f.path, "#{@dat[:ruta]}/#{@dat[:dir]}/#{f.original_filename}")}

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
      envia_fichero(file: file, rm: false, disposition: files[0].split('.')[-1] == 'pdf' ? 'inline' : 'attachment', popup: true)
    else
      file = "/tmp/nim#{@v.id}.zip"
      dir = "#{@dat[:ruta]}/#{@dat[:dir]}".gsub(' ', '\ ')
      `cd #{dir}; zip -qr #{file} #{files.map {|f| "#{f}".gsub(' ', '\ ')}.join(' ')}`
      envia_fichero(file: file, rm: true, popup: true)
    end

  end
end
