unless Nimbus::Config[:excluir_paises]

class NimtestMod < Pais
  @campos = {
    codigo: {tab: 'pre', gcols: 2, grid:{cellattr: '~style_codigo~'}},
    nombre: {tab: 'pre', gcols: 4, grid:{}},
    tipo: {tab: 'pre', gcols: 2, grid:{}},
    codigo_cr: {tab: 'pre', title: "Código para el Consejo regulador.\nNo es necesario rellenarlo.", gcols: 2, grid:{}},
    upl: {tab: 'pre', title: 'Subir fichero', gcols: 0, label: 'Upload File', type: :upload},
    upl2: {tab: 'pre', title: 'Subir múltiples ficheros', gcols: 2, label: 'Upload varios ficheros', type: :upload, multi: true},
    final: {tab: 'pre', gcols: 2},
    bool: {tab: 'pre', gcols: 2, type: :boolean, title: 'Campo booleano'},
    combo: {tab: 'pre', gcols: 2, type: :integer, sel: {1 => 'Opción A', 2 => 'Opción B'}},
    pxa: {tab: 'post', type: :div, gcols: 12},
    pxb: {tab: 'post', type: :div, gcols: 12},
    pxc: {tab: 'post', type: :div, gcols: 12},
    fact_emp: {tab: 'post', label: '@fact.grid_emp', ro: :all, gcols: 12},
    grid_emp: {tab: 'post', type: :div, gcols: 12},

    campo_x: {dlg: 'uno', gcols: 6},
    mig1: {dlg: 'uno', type: :div, gcols: 6, br: true},
    mig0: {dlg: 'uno', type: :div, gcols: 6},

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
    {id: 'dos', titulo: 'Diálogo dos', menu: 'Diálogo 2', menu_id: 'mr_d2', js: :mi_funcion},
  ]

  @menu_l = [
    {label: 'Listado de Países', url: '/gi/run/nimbus-core/paises'},
  ]

  @menu_r = [
    {label: 'Opción 1', accion: 'mi_funcion', side: :ambos},
    {id: 'tag_1', label: '<hr>'},
    {label: 'Diálogo 1', accion: 'diag_1', id: 'mr_1'},
    {label: 'Upload file', upload: :upl},
    {label: 'Proceso en segundo plano', accion: :proc2plano},
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

  include MantMod
end

class NimtestController < ApplicationController
  def before_envia_ficha
    return if @fact.id.to_i == 0

    texto = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'

    cols = [
      {name: 'codigo', label: 'Código', editable: false, width: 40},
      {name: 'nombre'},
      {name: 'pais_id', label: nt('pais')},
      {name: 'nombre2', width: 50},
      {name: 'double', type: :decimal, decim: 3, signo: true, width: 65, editable: '~vali_edit_pxa_double~', cellattr: '~style_cell_pxa_double~'},
      {name: 'bool', type: :boolean, width: 30},
      {name: 'fecha', type: :date, width: 80},
      {name: 'Sel', sel: {a: 'Uno', b: 'Dos'}, width: 40},
      {name: 'Time', type: :datetime, width: 40, seg: true},
      {name: 'Text', type: :text, width: 200},
    ]
    pl = @fact.nombre[0]
    q = Pais.where('nombre like ?', "#{pl}%")

    crea_grid cmp: :pxa, modo: :ed, export: 'paises', cols: cols,  sel: :cel, bsearch: true, bcollapse: true, search: true, grid: {rowattr: '~style_row_pxa~', caption: "Países que empiezan por #{pl}", height: 300},
              data: q.map {|p|
                d = rand(28) + 1
                m = rand(12) + 1
                [p.id, p.codigo, p.nombre, 3, p.nombre[-4..-1], (p.id.odd? ? 12345.67 : -9876.54), true, Date.new(2017, m, d), 'a', Nimbus.now, texto]
              }

    cols2 = cols.deep_dup
    crea_grid cmp: :pxb, modo: :ed, cols: cols2, grid: {caption: "Países que empiezan por #{pl}", height: 300}, data: q.map{|p| [p.id, p.codigo, p.nombre, nil, p.nombre[-4..-1], 0, false, Date.today, 'b']}

    @ajax << 'creaMiBoton_pxa();'

    set_auto_comp_filter('pxa_11_pais_id', "nombre like 'B%'")

    @fact.add_campo :cmpx, tab: 'post', gcols: 12, type: :decimal

    # Grid de usuarios con foto
    cols3 = [
      {name: 'codigo', label: 'Código', width: 70},
      {name: 'nombre', label: 'Nombre', width: 200},
      {name: 'Imagen', type: :img, width: 60}
    ]

    q = Usuario.pluck :id, :codigo, :nombre
    crea_grid cmp: :pxc, cols: cols3, grid: {multiselect: true, caption: "Usuarios", height: 200}, data: q.map{|u| u + [nim_image(mod: Usuario, id: u[0], tag: :foto)]}

    # Grid de empresas con subgrid de ejercicios
    cols_emp = [
      {name: 'cod', label: 'Código', width: 70},
      {name: 'nom', label: 'Nombre', width: 200},
      {name: 'cif', label: 'C.I.F.', width: 60},
      {name: 'dir', label: 'Dirección', width: 200},
      {name: 'pob', label: 'Población', width: 200}
    ]
    cols_eje= [
      {name: 'cod', label: 'Código', width: 70},
      {name: 'fi', label: 'Inicio', type: :date},
      {name: 'ff', label: 'Final', type: :date},
    ]

    dat_emp = Empresa.order(:codigo).pluck(:id, :codigo, :nombre, :cif, :direccion, :poblacion)
    dat_eje = {}
    Ejercicio.order(:codigo).pluck(:empresa_id, :id, :codigo, :fec_inicio, :fec_fin).each{|j|
      dat_eje[j[0]] ||= []
      dat_eje[j[0]] << j[1..-1]
    }

    crea_grid(
      cmp: :grid_emp,
      cols: cols_emp,
      grid: {caption: "Empresas", multiselect: true, height: 400},
      export: 'empresas',
      data: dat_emp,
      subgrid: {
        cols: cols_eje,
        grid: {multiselect: true, height: 100},
        data: dat_eje
      }
    )
  end

  def on_grid_emp
    @fact.fact_emp = @fact.grid_emp.to_s
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
    q = Pais.where('nombre like ?', 'A%')

    crea_grid cmp: :mig1, cols: cols, grid: {multiselect: true, height: 250}, data: q.map{|p| [p.id, p.codigo, p.nombre]}
    crea_grid cmp: :mig0, cols: cols, grid: {multiselect: true, height: 250}, data: q.map{|p| [p.id, p.codigo, p.nombre]}
    #@fact.mig1 = [3,8,14]
    @fact.mig1 = []
    @fact.mig0 = []
  end

  def fin_diag_1
    mensaje "Id's seleccionados: #{@fact.mig1} #{@fact.mig1.class}"
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
    @fact.codigo_cr.upcase!
    nil
  end
  def on_codigo_cr
    select_options :combo, 5, 4 => 'Opción c', 5 => 'Opción d', 6 => 'Opción e'
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

  def on_campo_x
    @fact.mig1 = 8
  end

  def on_mig1
    return unless params[:cmp].nil? || params[:cmp] == 'mig1'
    pp 'on_mig1'
    if params[:sel] == 'true'
      @fact.mig0 << params[:row].to_i
    else
      @fact.mig0.delete params[:row].to_i
    end
  end
  def on_mig0
    return unless params[:cmp] == 'mig0'
    pp 'on_mig0'
    if params[:sel] == 'true'
      @fact.mig1 << params[:row].to_i
    else
      @fact.mig1.delete params[:row].to_i
    end
  end

  def on_upl(f)
    puts '*******************************************************************'
    puts 'Fichero: ' + f.original_filename
    puts 'Ruta temporal: ' + f.path
    puts '*******************************************************************'
    puts f.read
    puts '***************** FIN DEL FICHERO *********************************'
    puts
  end

  def on_upl2(files)
    files.each {|f|
      puts '*******************************************************************'
      puts 'Fichero: ' + f.original_filename
      puts 'Ruta temporal: ' + f.path
      puts '*******************************************************************'
      puts f.read
      puts '***************** FIN DEL FICHERO *********************************'
      puts
    }
  end

  def final
    mensaje 'FIN'
  end

  def proc2plano
    lbl = 'Primera fase'
    exe_p2p(tit: 'Hola', label: lbl, pbar: :fix, width: 400, cancel: true, info: 'Mi propio p2p', tag: :proc, fin: {label: 'Adios', met: :final}) {
      begin
        #Código de la primera fase
        sleep 3
        p2p label: lbl << '<br>Segunda fase.<br>Duración ~ 12sg.', pbar: 20
        #a = 5/0
        sleep 4
        p2p pbar: 27
        sleep 4
        p2p pbar: 33
        sleep 4

        p2p label: 'Tercera fase', pbar: 40
        sleep 5

        p2p label: 'Cuarta fase', pbar: 60
        sleep 5

        p2p label: 'Quinta fase', pbar: 80
        sleep 5

        p2p label: 'Hecho', pbar: 100
      rescue P2PCancel
        p2p label: lbl + '<br>Cancelado.'
        sleep 2
      rescue ZeroDivisionError
        p2p label: 'División por cero', st: :err
      end
    }
  end
end

end
