class EjerciciosMod < Ejercicio
  @campos = {
    codigo: {tab: 'pre', grid:{}},
    descripcion: {tab: 'pre', grid:{}},
    ej_anterior_id: {tab: 'pre'},
    ej_siguiente_id: {tab: 'pre'},
    divisa_id: {tab: 'pre', manti: 10, req: true},
    fec_inicio: {tab: 'pre', grid:{}, req: true},
    fec_fin: {tab: 'pre', grid:{}, req: true},
  }

  @grid = {
    height: 100,
    scroll: true,
    cellEdit: false,
  }
  #@hijos = []

  #def ini_campos_ctrl
  #end
end
