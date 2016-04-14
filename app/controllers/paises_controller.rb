class PaisesMod < Pais
  @campos = {
    codigo: {tab: 'pre', gcols: 2, grid:{cellattr: '~fon~'}},
    nombre: {tab: 'pre', gcols: 4, grid:{}},
    tipo: {tab: 'pre', gcols: 2, grid:{}},
    codigo_cr: {tab: 'pre', gcols: 2, grid:{}},
    pxa: {tab: 'post', type: :div, gcols: 12},

    campo_x: {dlg: 'uno', gcols: 6},
    mig1: {dlg: 'uno', type: :div, gcols: 6},

    campo_1: {dlg: 'dos', gcols: 12},
    campo_2: {dlg: 'dos', gcols: 12},
    campo_3: {dlg: 'dos', gcols: 12},
    campo_4: {dlg: 'dos', gcols: 12},
    campo_5: {dlg: 'dos', gcols: 12, on: :habilita_menu},
    campo_6: {dlg: 'dos', gcols: 12, on: :habilita_menu},
    mig2: {dlg: 'dos', type: :div, gcols: 12},
  }

  @grid = {
    height: 250,
    scroll: true,
    wh: "nombre like 'B%'"
  }

  @dialogos = [
    {id: 'uno', titulo: 'Diálogo uno', botones: [{label: 'Hecho', accion: 'fin_diag_1', close: false}]},
    {id: 'dos', titulo: 'Diálogo dos', menu: 'Diálogo 2', menu_id: 'mr_d2'},
  ]

  @menu_l = [
    {label: 'Listado de Países', url: '/gi/edit/pais'},
  ]

  @menu_r = [
    {label: 'Opción 1', accion: 'mi_funcion'},
    {label: 'Diálogo 1', accion: 'diag_1', id: 'mr_1'},
  ]

  #@hijos = []

  #def ini_campos_ctrl
  #end
end

class PaisesMod < Pais
  include MantMod
end

class PaisesController < ApplicationController
  def before_envia_ficha
    return if @fact.id.to_i == 0

    cols = [
      {name: 'código', width: 70},
      {name: 'nombre'},
    ]
    pl = @fact.nombre[0];
    q = Pais.where('nombre like ?', "#{pl}%")

    crea_grid cmp: :pxa, cols: cols, grid: {caption: "Países que empiezan por #{pl}"}, data: q.map{|p| [p.id, p.codigo, p.nombre]}

    @fact.add_campo :cmpx, tab: 'post', gcols: 12
  end

  # Métodos asociados a dialogo 1

  def diag_1
    abre_dialogo('uno')

    cols = [
      {name: 'código', width: 70},
      {name: 'nombre'},
    ]
    q = Pais.where('nombre like ?', 'A%a')

    crea_grid cmp: :mig1, cols: cols, grid: {multiselect: true, height: 250}, data: q.map{|p| [p.id, p.codigo, p.nombre]}
  end

  def fin_diag_1
    mensaje "Id's seleccionados: #{@fact.mig1}"
  end

  # Métodos asociados a dialogo 2

  def on_campo_1
    cols = [
      {name: 'código', width: 70},
      {name: 'nombre'},
      {name: 'fecha', type: :date, width: 100},
      {name: 'entero', type: :integer},
      {name: 'decimal', type: :decimal, dec: 3},
      {name: 'bool', type: :boolean, width: 50}
    ]

    data = [
      [11, '01', 'Uno', Date.today, 1567, 12345.321, true],
      [12, '02', 'Dos', Date.tomorrow, 1234567, 98, false],
      [13, '03', 'Tres', Date.tomorrow+1, 5234567, 34.5, true],
    ]

    crea_grid cmp: :mig2, search: true, cols: cols, data: data
  end

  def on_campo_2
    add_data_grid :mig2, [14, '04', 'Cuatro', Date.today+3, 67, 2345.31, true]
  end

  def on_mig2
    mensaje "Has seleccionado el id: #{@fact.mig2}"
  end

  def on_campo_3
    disable('campo_5')
    #mensaje tit: 'Hola', msg: 'Un texto cualquiera', bot: [{label: 'Ok', accion: 'mi_funcion'}]
    @fact.campo_4 = 'HOLA'
    foco('campo_6')
  end

  def on_campo_4
    disable_menu(:mr_1)
  end

  def habilita_menu(cmp)
    # cmp es el nombre del campo que ha disparado este método
    enable_menu(:mr_1)
  end

  # Otros Métodos

  def mi_funcion
    mensaje tit: 'Hola', msg: '<h1>HOLA</h1><hr><h3>Adios</h3>'
  end
end
