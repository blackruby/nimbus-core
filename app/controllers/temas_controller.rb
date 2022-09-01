class TemasMod < Tema
  @campos = {
    codigo: {tab: 'pre', gcols: 2, grid: {}},
    descripcion: {tab: 'pre', gcols: 4, grid: {}},
    privado: {tab: 'pre', gcols: 2, title: 'No permite la edición de este tema por parte de otros usuarios'},

    dumb: {tab: 'params', gcols: 0},

    fondo_menu: {tab: 'fondo_menu', gcols: 12, title: 'Imagen de fondo de la ventana principal', img: {height: 600}},
  }

  @grid = {
    gcols: 4
  }
  @menu_r = [
    {label: 'Opción 1'}
  ]

  include MantMod
end

class TemasController < ApplicationController
  def after_index
    t = Tema.scs_default
    td = Tema.find_by id: @usu.pref[:tema_id]
    t.merge!(td.params) if td
    @ajax << "cssVars=#{t.to_json};"
  end


  def before_new
    Nimbus::Config[:temas] ? true : {msg: 'No tiene habilitada la gestión de temas.<hr>Consulte con su administrador.'}
  end

  def before_envia_ficha
    return if @fact.id == 0

    @assets_stylesheets = %w(temas)
    @assets_javascripts = %w(temas)

    if @fact.id.nil?
      @fact.user_id = @usu.id
    end

    if !@usu.admin && @fact.id != @usu.id
      @fact.privado ? disable_all : disable(:privado)
    end
    
    if @fact.id
      # Asignar los parámetros a la variable cssVars del padre
      @fact.params.each {|k, v| @ajax << "parent.cssVars['#{k}']='#{v}';"}
    end
  end

  def before_save
    @fact.params = {}
    params[:css].each {|k, v| @fact.params[k] = v}
  end

  def after_save
    if params[:default] && @usu.pref[:tema_id] != @fact.id
      @usu.pref[:tema_id] = @fact.id
      @usu.update_column(:pref, @usu.pref)
    end
    @ajax << "grabarTema(#{@fact.params.to_json});" if @usu.pref[:tema_id] == @fact.id
  end
end