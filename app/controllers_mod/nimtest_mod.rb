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
end
