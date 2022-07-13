class MensajesMod < Mensaje
  @campos = {
    fecha: {tab: 'pre', manti: 6, gcols: 3, ro: :edit, grid:{width: 120}},
    from_id: {tab: 'pre', manti: 40, gcols: 4, req: true, grid:{}},
    to_id: {tab: 'pre', manti: 40, gcols: 4, req: true, grid:{}},
    leido: {tab: 'pre', gcols: 1, grid:{width: 50}},
    separador: {tab: 'pre', gcols: 2, type: :div},
    texto: {tab: 'pre', gcols: 8, label: '', rich: true, grid:{label: 'Mensaje'}},
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

  def before_edit
    @usu.admin || @fact.from_id == @usu.id || @fact.to_id == @usu.id
  end

  def control_botones
    unless @usu.admin
      status_botones(borrar: false) if @fact.from_id != @usu.id
    end
  end

  def before_envia_ficha
    return if @fact.id == 0

    if @fact.id.nil?
      @fact.from_id = @usu.id
      @fact.fecha = Nimbus.now
    end

    unless @usu.admin
      disable(:from_id)
      [:to_id, :texto].each{|c| disable(c)} if @fact.from_id != @usu.id
    end

    control_botones
  end

  def after_save
    control_botones
  end

  def show
    unless Nimbus::Config[:noticias]
      head :no_content
      return
    end

    @assets_javascripts = %w(noticias quill/nim_quill)
    @assets_stylesheets = %w(noticias quill/nim_quill)

    @titulo = 'Notificaciones'
  end

  def cargar_noticias
    noti = Mensaje.where("to_id = ? AND leido IS #{params[:nuevas] ? 'NULL' : 'NOT true'}", @usu.id).order('fecha')
    Mensaje.where('id in (?)', noti.map{|n| n.id}).update_all(leido: false)

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
      {id: n.id, new: n.leido.nil?, tex: n.texto, from: n.from.nombre, fec: fec, fel: I18n.l(n.fecha, format: '%-d %b %Y %H:%M'), uid: n.from_id, img: nim_path_image('Usuario', n.from_id, :foto)}
    }
  end

  def cargar_usuarios
    render json: Usuario.order(:nombre).pluck(:id, :nombre).map {|u| {id: u[0], nom: u[1], img: nim_path_image('Usuario', u[0], :foto)}}
  end

  File_msg = Nimbus::GestionPath + 'tmp/nim_mensaje.html'
  File_stp = Nimbus::GestionPath + 'tmp/nim_stop'

  def nuevas
    jsn = {
      stop: File.exist?(File_stp),
      htm: File.exist?(File_msg) ? File.read(File_msg) : nil
    }
    jsn[:n] = Mensaje.where(to: @usu.id, leido: nil).count if Nimbus::Config[:noticias]

    render json: jsn
  end

  def enviar_mensaje
    params[:uids].each {|uid| Mensaje.create(from_id: @usu.id, to_id: uid, fecha: Nimbus.now, texto: params[:msg])}
  end
    
  def marcar_leidos
    Mensaje.where('id in (?)', params[:ids]).update_all(leido: true)
  end
end
