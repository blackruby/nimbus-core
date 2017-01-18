class NimtestMod < Pais
  @campos = {
    codigo: {tab: 'pre', gcols: 2, grid:{cellattr: '~style_codigo~'}},
    nombre: {tab: 'pre', gcols: 4, grid:{}},
    tipo: {tab: 'pre', gcols: 2, grid:{}},
    codigo_cr: {tab: 'pre', gcols: 2, grid:{}},
    final: {tab: 'pre', gcols: 2},
    bool: {tab: 'pre', gcols: 2, type: :boolean},
    combo: {tab: 'pre', gcols: 2, type: :integer, sel: {1 => 'Opción A', 2 => 'Opción B'}},
    pxa: {tab: 'post', type: :div, gcols: 12},
    pxb: {tab: 'post', type: :div, gcols: 12},

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
    #wh: "nombre like 'B%'"
  }

  @dialogos = [
    {id: 'uno', titulo: 'Diálogo uno', botones: [{label: 'Hecho', accion: 'fin_diag_1', close: false}]},
    {id: 'dos', titulo: 'Diálogo dos', menu: 'Diálogo 2', menu_id: 'mr_d2'},
  ]

  @menu_l = [
    {label: 'Listado de Países', url: '/gi/run/nimbus-core/paises'},
  ]

  @menu_r = [
    {label: 'Opción 1', accion: 'mi_funcion'},
    {id: 'tag_1', label: '<hr>'},
    {label: 'Diálogo 1', accion: 'diag_1', id: 'mr_1'},
  ]

  @titulo = 'Tests Nimbus'

  #@hijos = []

  def ini_campos_ctrl
    self.bool = true
    self.combo = 2
  end

  def final
    self.nombre[-4..-1]
  end
end

class NimtestMod < Pais
  include MantMod
end

class NimtestController < ApplicationController
  def before_envia_ficha
    return if @fact.id.to_i == 0

    cols = [
      {name: 'codigo', label: 'Código', editable: false, width: 40},
      {name: 'nombre'},
      {name: 'pais_id', label: nt('pais')},
      {name: 'nombre2', width: 50},
      {name: 'double', type: :decimal, decim: 3, signo: true, width: 65, editable: '~vali_edit_pxa_double~', cellattr: '~style_cell_pxa_double~'},
      {name: 'bool', type: :boolean, width: 30},
      {name: 'fecha', type: :date, width: 80},
      {name: 'Sel', sel: {a: 'Uno', b: 'Dos'}, width: 40},
      {name: 'Time', type: :time, width: 40},
    ]
    pl = @fact.nombre[0]
    q = Pais.where('nombre like ?', "#{pl}%")

    cols2 = cols.deep_dup
    crea_grid cmp: :pxa, modo: :ed, export: 'paises', cols: cols, ins: :pos, sel: :cel, grid: {rowattr: '~style_row_pxa~', caption: "Países que empiezan por #{pl}", height: 300},
              data: q.map{|p| [p.id, p.codigo, p.nombre, 3, p.nombre[-4..-1], (p.id.odd? ? 12345.67 : -9876.54), true, Date.today, 'a']}
    crea_grid cmp: :pxb, modo: :ed, cols: cols2, grid: {caption: "Países que empiezan por #{pl}", height: 300}, data: q.map{|p| [p.id, p.codigo, p.nombre, nil, p.nombre[-4..-1], 0, false, Date.today, 'b']}

    @ajax << 'creaMiBoton_pxa();'

    set_auto_comp_filter('pxa_11_pais_id', "nombre like 'B%'")

    @fact.add_campo :cmpx, tab: 'post', gcols: 12, type: :decimal
  end

  def new_pxa(pos)
    [@fact.pxa.max_id.next, '001', 'Santuro', 101, 'isla']
  end
  def vali_borra_pxa(id)
    return 'Argentina no' if id.to_i == 11
  end

  def vali_pxa_nombre(id, val)
    return nil
  end
  def on_pxa_nombre(id, val)
    @fact.pxa.data(id, :nombre2, val[-4..-1])
  end
  def vali_pxa_nombre2(id, val)
    return "#{val}: Nombre muy largo" if val.size > 5
  end
  def on_pxa_nombre2(id, val)
    @fact.pxa.data(id, :double, 12.1)
  end

  def on_cmpx
    mensaje @fact.pxa[:data].inspect
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
      {name: 'código', width: 70, editable: true},
      {name: 'nombre', editable: true},
      {name: 'fecha', type: :date, width: 100, editable: true},
      {name: 'entero', type: :integer, editable: true},
      {name: 'decimal', type: :decimal, dec: 3, editable: true},
      {name: 'bool', type: :boolean, width: 50, editable: true}
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

  def vali_codigo_cr
    @fact.codigo_cr = @fact.codigo_cr.upcase
    nil
  end
  def on_codigo_cr
    select_options :combo, 5, 4 => 'Opción c', 5 => 'Opción d', 6 => 'Opción e'
    #envia_fichero file: '/tmp/z.pdf', rm: false
  end

  def habilita_menu(cmp)
    # cmp es el nombre del campo que ha disparado este método
    enable_menu(:mr_1)
  end

  # Otros Métodos

  def mi_funcion
    mensaje tit: 'Hola', msg: '<h1>HOLA</h1><hr><h3>Adios</h3>'
  end

  def fun_mi_boton
    txt = ''
    @fact.pxa.each_row {|fila, new, edit, i|
      txt << format('fila: %d  id: %s  cod: %s  new: %s  ed: %s', i, fila[0].to_s, fila[1], new.inspect, edit.inspect)
      txt << '<br>'
    }
    txt << '<hr>IDs Borrados<br>'
    @fact.pxa.each_del {|fila, new, edit, i|
      txt << format('id: %s  cod: %s  new: %s  ed: %s', fila[0].to_s, fila[1], new.inspect, edit.inspect)
      txt << '<br>'
    }

    mensaje txt
  end
end
