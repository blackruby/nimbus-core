class AuditoriasMod < Auditoria
  @campos = {
    usuario_id: {tab: 'pre', gcols: 3, label: 'usuario', grid: {width: 70}},
    fecha: {tab: 'pre', gcols: 3, grid: {width: 40}},
    controlador: {tab: 'pre', gcols: 3, grid: {width: 60}},
    accion: {tab: 'pre', gcols: 1, title: :acciones_audit, grid: {width: 15}},
    rid:{tab: 'pre', gcols: 2, label: 'Id del registro', grid: {width: 18}},
    texto:{tab: 'pre', gcols: 12, type: :div},
  }

  @grid = {
    gcols: [4,8],
  }

  @hijos = [{tab: 'post'}]
end
