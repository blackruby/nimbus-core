class ErdMod
  @campos = {
    modelos: {tab: 'pre', gcols: 12, manti: 200, label: 'Modelos/Módulos', title: 'Los modelos se introducen como se referencia la clase, los módulos en minúsculas.'},
    nivel: {tab: 'pre', gcols: 1, manti: 2, type: :integer, title: '0 = Todos los niveles'},
    erd: {tab: 'pre', gcols: 2, label: 'Diagrama ERD', type: :boolean},
    div: {tab: 'pre', gcols: 12, type: :div, br: true},
  }

  @titulo = 'Diagramas Entidad-Relación'
  @nivel = :g
end
