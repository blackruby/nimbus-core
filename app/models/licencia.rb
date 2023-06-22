class Licencia < ActiveRecord::Base
  @propiedades = {
    usuario_id: {},
    fecha: {},
    sid: {},
  }

  belongs_to :usuario, :class_name => 'Usuario'

  def self.get_licencia(usu, sid)
    return true if usu.codigo == 'admin' || !Nimbus::Config[:licencias]

    res = false
    Licencia.transaction {
      sql_exe 'LOCK TABLE licencias IN EXCLUSIVE MODE'
      l = Licencia.find_by sid: sid

      if l || Licencia.count < Nimbus::Config[:licencias]
        l = Licencia.new unless l
        l.usuario_id = usu.id
        l.fecha = Nimbus.now
        l.sid = sid
        l.save
        res = true
      end
    }
    return res
  end
end

