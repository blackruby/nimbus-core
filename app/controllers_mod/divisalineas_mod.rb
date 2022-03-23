class DivisalineasMod < Divisalinea
  @campos = {
    divisacambio_id:  {tab: 'pre', grid:{}, req: true, label: nt('divisa')},
    fecha:            {tab: 'pre', grid:{}, req: true, br: true},
    cambio:           {tab: 'pre', grid:{}, req: true},
  }
end
