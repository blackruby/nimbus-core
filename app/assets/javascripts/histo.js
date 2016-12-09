var classFicha, displayGrid = true;

function searchBar() {vgrid[0].toggleToolbar();}

function editInForm() {
  var id = $(grid).jqGrid('getGridParam','selrow');
  if (id != null) $("#ficha").attr('src', url_edit + '/h' + id + '/edit?head=0');
}

// Recalcular la anchura y altura del grid cuando se redimensione la ventana

function redimWindow() {
  var tf = $("#cell-ficha").offset().top;
  if (displayGrid) {
    grid.setGridWidth($("#gbox_grid").parent().width()-2, grid.jqGrid('getGridParam', 'shrinkToFit'));
    var tg = $("#cell-grid").offset().top;
    if (tg == tf) {
      var h = $(window).height() - tf - 35;
      $("#ficha").css("height", h);
      grid.setGridHeight(h);
      $("#gbox_grid").css("height", 'auto');
    } else {
      var h = $(window).height() / 2;
      if ($("#cell-grid").height() > h) {
        grid.setGridHeight(h);
        $("#gbox_grid").css("height", 'auto');
      }
      $("#ficha").css("height", $(window).height() - (tg>tf ? tf : 40) - $("#cell-grid").height() - 40);
    }
  } else {
    $("#ficha").css("height", $(window).height() - tf - 10);
  }
}


$(window).load(function () {
  grid = $("#grid");
  toolgrid = '#grid_toppager';

  vgrid = grid.jqGrid({
    colModel: [{name: 'fecha', index: 'created_at', label: 'Fecha', width: 12}, {
      name: 'usuario',
      index: 'created_by_id',
      label: 'Usuario',
      width: 8
    }],
    sortname: 'created_at',
    sortorder: 'asc',
    url: url_list,
    datatype: "json",
    mtype: 'POST',
    height: 400,
    rowNum: 100,
    gridview: true,	// Acelera la velocidad de renderizado. Poner a false con trees y subgrids
    altRows: true,	// filas tipo cebra
    sortable: true,	// Si las columnas se pueden reordenar (cambiar de sitio)
    viewrecords: true,	// Muestra información del total de registros en la toolbar
    ondblClickRow: editInForm,
    shrinkToFit: true,
    scroll: true,
    cellEdit: true,
    toppager: false,
  });

  grid.jqGrid('gridResize', {handles: "s", minHeight: 80});
  grid.jqGrid('bindKeys');
  grid.jqGrid('filterToolbar', {stringResult: true, searchOperators: true});
  vgrid[0].toggleToolbar();

  // Mostrar/Ocultar el grid

  $("#b-collapse").click(function () {
    if (displayGrid) {
      $("#cell-grid").css('display', 'none');
      $(".only-grid").attr("disabled", true)
      classFicha = $("#cell-ficha").attr('class');
      $("#cell-ficha").attr('class', 'mdl-cell mdl-cell--8-col-tablet mdl-cell--4-col-phone mdl-cell--12-col');
      displayGrid = false;
    } else {
      $("#cell-grid").css('display', 'block');
      $(".only-grid").attr("disabled", false)
      $("#cell-ficha").attr('class', classFicha);
      displayGrid = true;
      $("#ficha").height(0);
    }
    redimWindow();
  });

  // Recalcular la anchura y altura del grid cuando se redimensione la ventana
  //$(".ui-pg-input").height(14); // Para que salga de la altura correcta el input del número de página del grid
  $(window).resize(redimWindow);

  redimWindow();
  $("#ficha").attr('src', url_edit + '/0/edit?head=0');
});
