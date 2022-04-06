class MensajesMod < Mensaje
  @campos = {
    fecha: {tab: 'pre', manti: 6, gcols: 3, ro: :edit, grid:{width: 120}},
    from_id: {tab: 'pre', manti: 40, gcols: 4, ro: :all, grid:{}},
    to_id: {tab: 'pre', manti: 40, gcols: 4, grid:{}},
    leido: {tab: 'pre', gcols: 1, grid:{width: 50}},
    texto: {tab: 'pre', gcols: 12, grid:{}},
  }

  @grid = {
    cellEdit: false,
    sortname: 'fecha',
    sortorder: 'desc',
  }

  include MantMod
end

class MensajesController < ApplicationController
  def before_index
    Nimbus::Config[:noticias]
  end

  def before_envia_ficha
    return if @fact.id == 0

    if @fact.id.nil?
      @fact.from_id = @usu.id
      @fact.fecha = Nimbus.now
      @fact.leido = false
    end
    disable(:leido) if @fact.to_id != @usu.id
    disable(:to_i) if @fact.leido
  end

  def show
    unless Nimbus::Config[:noticias]
      head :no_content
      return
    end

    @assets_javascripts = %w(noticias)
    @assets_stylesheets = %w(noticias)

    @titulo = 'Notificaciones'
  end

  def cargar_noticias
    noti = Mensaje.where(to_id: @usu.id, leido: false).order('fecha desc')
    Mensaje.where('id in (?)', noti.map{|n| n.id}).update_all(leido: true)

    render json: noti.map {|n|
      d = Nimbus.now - n.fecha
      if d < 60
        fec = "#{d.floor} seg"
      elsif d < 3600
        fec = "#{(d/60).floor} min"
      elsif d < 3600*24
        fec = "#{(d/3600).floor} h"
      elsif d < 3600*24*7
        fec = "#{(d/(3600*24)).floor} d"
      else
        fec = I18n.l(n.fecha, format: '%-d %b %y')
      end
      {tex: n.texto, from: n.from.nombre, fec: fec, fel: n.fecha.strftime('%-d %b %Y %H:%M:%S'), uid: n.from_id, img: nim_path_image('Usuario', n.from_id, :foto)}
    }
  end

  def cargar_usuarios
    render json: Usuario.order(:nombre).pluck(:id, :nombre).map {|u| {id: u[0], nom: u[1], img: nim_path_image('Usuario', u[0], :foto)}}
  end

  File_msg = 'tmp/nim_mensaje.html'
  File_stp = 'tmp/nim_stop'

  def nuevas
    n = Nimbus::Config[:noticias] ? Mensaje.where(to: @usu.id, leido: false).count : 0
    js = "nimActData(#{n},#{File.exist?(File_stp)},"
    js << (File.exist?(File_msg) ? File.read(File_msg).to_json : 'null')
    render js: js + ');'
  end

  def enviar_mensaje
    params[:uids].each {|uid| Mensaje.create(from_id: @usu.id, to_id: uid, fecha: Nimbus.now, texto: params[:msg], leido: false)}
  end
end
