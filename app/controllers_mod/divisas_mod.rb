class DivisasMod < Divisa
  @campos = {
    codigo: {tab: 'pre', grid:{}},
    descripcion: {tab: 'pre', grid:{}},
    decimales: {tab: 'pre', grid:{}},
  }

  @grid = {
    scroll: true,
    cellEdit: false,
  }

  @hijos = [{url: 'divisalineas', tab: 'post'}]

  #def ini_campos_ctrl
  #end
end
