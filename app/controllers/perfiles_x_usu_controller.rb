class PerfilesXUsuMod
  @campos = {
    panel: {type: :div, tab: 'pre', gcols: 12},
  }

  include MantMod
end

class PerfilesXUsuController < ApplicationController
  def before_edit
    @usu.admin
  end

  def before_envia_ficha
    @head = 0

    @titulo = 'Perfiles por Usuario'

    cols = [
      {name: 'codigo', label: nt('codigo'), width: 130},
      {name: 'nombre', label: nt('nombre'), width: 250},
      {name: 'admin', label: nt('admin'), type: :boolean, width: 50},
      {name: 'empresa_id', label: nt('empresa'), ref: 'Empresa', width: 250},
      {name: 'perfil_id', label: nt('perfil'), ref: 'Perfil', width: 250},
      {name: 'permiso', label: nt('permiso'), width: 50}
    ]

    q = Usuario.order(:codigo)

    data = []
    id = 1
    Usuario.order(:codigo).each {|u|
      if u.pref[:permisos][:emp].empty?
        data << [id, u.codigo, u.nombre, u.admin, nil, nil, '']
        id += 1
      else
        u.pref[:permisos][:emp].each {|e|
          data << [id, u.codigo, u.nombre, u.admin, e[0], e[2], e[1]]
          id += 1
        }
      end
    }

    crea_grid(
      cmp: :panel,
      modo: :ed,
      export: 'usuarios',
      cols: cols,
      del: false,
      ins: false,
      sel: :cel,
      bsearch: true,
      search: false,
      grid: {
        cellEdit: false,
        multiselect: false,
        altRows: false,
        caption: @titulo,
        height: 800,
        #gridComplete: '~gridCargado~'
      },
      data: data
    )
  end
end