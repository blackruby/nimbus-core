class PerfilesMod < Perfil
  @campos = {
    codigo: {tab: 'pre', grid: {}, gcols: 4},
    descripcion: {tab: 'pre', grid: {}, gcols: 6},
  }

  @grid = {
    gcols: 3,
    cellEdit: false,
    scroll: true,
  }

  #@hijos = []

  #def ini_campos_ctrl
  #end
end
