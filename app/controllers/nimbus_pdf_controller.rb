class NimbusPdfController < ApplicationController
  def index
    unless @usu.codigo == 'admin'
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    @assets_stylesheets = %w(nimbus_pdf)
    @assets_javascripts = %w(nimbus_pdf ui_resizable_snap)

    if params[:yml]
      begin
        @yml = YAML.load(File.read(params[:yml]))
        raise ArgumentError unless @yml.is_a?(Hash)
        @yml_file = params[:yml]
      rescue
        @yml = {error: "#{params[:yml]}: El archivo no existe o es defectuoso."}
      end
    else
      @yml = {pag: {}, def: {}, cab: {}, pie: {}, ban: {}}
    end
    @yml = @yml.to_json
  end

  def help
    unless @usu.codigo == 'admin'
      render file: '/public/401.html', status: 401, layout: false
      return
    end
  end

  def grabar_doc
    fic = params[:fic][0] == '/' ? params[:fic][1..-1] : params[:fic]
    if params[:new] == 'true' && File.exist?(fic)
      render json: 'Ya existe el archivo. Grabación cancelada'.to_json
      return
    end

    begin
      dat = params[:dat] ? params[:dat].to_unsafe_hash.deep_symbolize_keys : {}
      File.write(fic, dat.to_yaml)
    rescue => e
      render json: "Grabación cancelada:\n\n#{e.message}".to_json
    else
      render json: 'ok'.to_json
    end
  end
end