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
end
