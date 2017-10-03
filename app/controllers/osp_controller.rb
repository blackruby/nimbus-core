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
    Dir.glob(path).each {|f|
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
          h[:type] = %w(pdf xls txt zip doc ppt).include?(ext) ? ext : 'file'
        end
      end
    }

    @dir = flash[:dir].to_s

    @v = Vista.new
    @v.data = {ruta: flash[:ruta], dir: flash[:dir], tit: flash[:tit]}
    @v.save
  end

  def abrir
    flash[:ruta] = @dat[:ruta]
    flash[:tit] = @dat[:tit]

    if params[:fol] == '..'
      dir_a = @dat[:dir].to_s.split('/')
      flash[:dir] = dir_a[0..-2].join('/')
    else
      flash[:dir] = "#{@dat[:dir]}/#{params[:fol]}"
    end

    @ajax << 'location.reload();'
  end
end
