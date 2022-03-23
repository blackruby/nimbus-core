class BloqueosMod < Bloqueo
  @campos = {
    controlador: {tab: 'pre', gcols: 2, grid:{}},
    clave: {tab: 'pre', gcols: 3, grid:{}},
    ir_a: {tab: 'pre', gcols: 1, type: :div},
    created_by_id: {tab: 'pre', gcols: 3, label: 'Usuario', grid:{}},
    created_at: {tab: 'pre', gcols: 3, label: 'Fecha', grid:{}},
  }

  @grid = {
    height: 250,
    scroll: true,
  }
end
