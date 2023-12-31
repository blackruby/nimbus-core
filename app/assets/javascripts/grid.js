var winBus = null;

function openWinBus() {
  if (winBus) {
    winBus.focus();
  } else {
    winBus = window.open("/bus", "_blank", "width=700, height=500");
    winBus._autoCompField = "mant";
  }
}

function editInLine() {
  id = grid.jqGrid('getGridParam','selrow');
  if (id != null)
    grid.jqGrid('editRow', id, true);
  else
    alert("Seleccione un registro");
}

function searchBar() {
  vgrid[0].toggleToolbar();
  redimWindow();
}

function fichaLoaded() {
  fichaLoading = false;
}

function editInForm(id) {
  if (fichaLoading || checkNimServerStop()) return;

  if (id != null) {
    // Seguimos el convenio de que si el "id" tiene un underscore significa
    // que la parte izquierda es el id principal y el de la derecha sería
    // el del primer hijo. Si hubiera más de un hijo (o más underscores)
    // habría que tratarlo.
    var ids = id.toString().split("_");
    var hijos = "";
    if (ids.length > 1) {
      id = ids[0];
      hijos = '&hijos="' + varView.hijos[0].url + '":' + ids[1]
    }

    grid.jqGrid('setSelection', id);
  } else
    id = grid.jqGrid('getGridParam', 'selrow');

  if (id != null) {
    fichaLoading = true;
    $("#ficha").attr('src', varView.url_base + id + '/edit' + varView.arg_edit + hijos);
    if (varView.grid.gcols[0] == 0) id == 0 ? gridShow() : gridHide();
  } else
    alert("Seleccione un registro");
}

function newFicha(lastId) {
  if (checkNimServerStop()) return;

  if ($("button.cl-crear").attr('disabled') == 'disabled') return;
  $("#ficha").attr('src', varView.url_new + (lastId ? '&last_id=' + lastId : ''));
  if (varView.grid.gcols[0] == 0) gridHide();
}

/*
 $("#ficha").load(function() {
 h = this.contentWindow._altura;
 if (h == undefined) h = this.contentWindow.document.body.offsetHeight + 100 + 'px';
 $(this).parent().css("height", h);
 w = this.contentWindow._anchura;
 if (w == undefined) w = "400px"
 $(this).parent().css("width", w);
 //$(this).css("height", $("#ficha").contents().find('.mdl-layout__content')[0].scrollHeight + 130 + "px");
 });
 */
function grid_historico() {
  $("#ficha")[0].contentWindow.historico();
}

function grid_historico_pk() {
  $("#ficha")[0].contentWindow.historico_pk();
}

function grid_reload() {
  grid.trigger('reloadGrid', [{current:true}]);
}

function liFon(li, fon, tipo, side) {
  if ($(li).attr("disabled") == "disabled") return;
  if (typeof fon == 'function')
    fon.call();
  else if (tipo == 'dlg') {
    if (side) $("#ficha")[0].contentWindow[side]();
    $("#ficha")[0].contentWindow.abreDialogo(fon);
  } else {
    if (side == 'js' || side == 'ambos') $("#ficha")[0].contentWindow[fon]();
    if (side != 'js') $("#ficha")[0].contentWindow.callFonServer(fon);
  }
}

// Mostrar/Ocultar el grid

var classFicha, displayGrid = true;

// $("#b-collapse").click(function() {gridCollapse();});

function gridCollapse() {
  if (displayGrid) {
    $("#cell-grid").css('display', 'none');
    $(".only-grid").attr("disabled", true);
    if (varView.grid.gcols[0] == 0) {
      $("#cell-ficha").css("display", "block");
    } else {
      classFicha = $("#cell-ficha").attr('class');
      $("#cell-ficha").attr('class', 'mdl-cell mdl-cell--8-col-tablet mdl-cell--4-col-phone mdl-cell--12-col');
    }
    displayGrid = false;
  } else {
    $("#cell-grid").css('display', 'block');
    $(".only-grid").attr("disabled", false);
    $("#cell-ficha").attr('class', classFicha);
    displayGrid = true;
    $("#ficha").height(0);
  }
  redimWindow();
}

function gridHide() {
  if (displayGrid) gridCollapse();
}
function gridShow() {
  if (!displayGrid) gridCollapse();
}

function redimWindow() {
  var tf = $("#cell-ficha").offset().top;
  if (displayGrid) {
    grid.setGridWidth($("#gbox_grid").parent().width()-2, grid.jqGrid('getGridParam', 'shrinkToFit'));
    var tg = $("#cell-grid").offset().top;
    if (tg == tf || varView.grid.gcols[0] == 0) {
      var h = $(window).height() - tg - $(".ui-jqgrid-hbox").height() - 10; 
      if (varView.grid.gcols[0] != 0) $("#ficha").css("height", h);
      grid.setGridHeight(h);
      $("#gbox_grid").css("height", 'auto');
    } else {
      var h = $(window).height() / 2;
      var hg = $("#cell-grid").height();
      var hgn = hg;
      if (hg < 40 || hg > h) hgn = grid.jqGrid('getGridParam', 'height_def');
      if (hgn > h) hgn = h;

      if (hgn != hg) {
        grid.setGridHeight(hgn);
        $("#gbox_grid").css("height", 'auto');
      }
      $("#ficha").css("height", $(window).height() - (tg>tf ? tf : 40) - $("#cell-grid").height() - 40);
    }
  } else {
    $("#ficha").css("height", $(window).height() - tf - 10);
  }
}

function mantGrabarGrid() {
  if (varView.grid.gcols[0] == 0) gridHide();
  $("#ficha")[0].contentWindow.mant_grabar();
}

function mantBorrarGrid() {
  if (varView.grid.gcols[0] == 0) gridHide();
  $("#ficha")[0].contentWindow.mant_borrar();
}

function ospGrid() {
  if (varView.grid.gcols[0] == 0) gridHide();
  $("#ficha")[0].contentWindow.callFonServer('osp');
}

function pkSearch() {
  $(".mdl-navigation").css('display', 'none');
  if ($(window).width() <= 600) $(".grid-title").css('display', 'none');
  $("#_pk-label").css('display', 'none');
  $("#_pk-input").css('display', 'block').val('').focus();
}

function pkBlur() {
  $("#_pk-input").css('display', 'none');
  $(".grid-title").css('display', 'block');
  $("#_pk-label").css('display', 'block');
  $(".mdl-navigation").css('display', 'flex');
}

function selNewEjercicio() {
  var ej = $("#sel-nim-ejer");
  var url = new URL(window.location.href);
  url.searchParams.set("eid", eid);
  url.searchParams.set("jid", ej.val());
  window.location.replace(url.href);
  // Reponemos el ejercicio original por si el location.replace no tiene lugar
  // porque lo ha aboratdo el usuario en el diálogo que sale si hay cambios sin guardar.
  ej.val(jid);
}

$(window).load(function () {
  grid = $("#grid");
  toolgrid = '#grid_toppager';

  vgrid = grid.jqGrid({
    colModel: eval(varView.col_model),
    datatype: "json",
    mtype: 'POST',
    sortname: varView.grid.sortname,
    sortorder: varView.grid.sortorder,
    url: varView.url_list,
    cellurl: varView.url_cell,
    beforeProcessing: jqg_before_processing,
    beforeEditCell: jqg_before_edit_cell,
    beforeSubmitCell: jqg_before_submit_cell,
    afterSubmitCell: jqg_after_submit_cell,
    afterSaveCell: jqg_after_save_cell,

    height: varView.grid.height,
    height_def: varView.grid.height,
    rowNum: varView.grid.rowNum,

    cellEdit: varView.grid.cellEdit,
    gridview: true,

    toppager: !varView.grid.scroll,
    rowList:[10,20,30,50,100,500,1000],
    altRows: varView.grid.altRows,
    sortable: true,
    viewrecords: true,

    ondblClickRow: editInForm,

    shrinkToFit: varView.grid.shrinkToFit,
    multiSort: varView.grid.multiSort,
    scroll: varView.grid.scroll,
    beforeRequest: function() {return !checkNimServerStop()},

    search: !$.isEmptyObject(varView.grid.reglas),
    postData: $.isEmptyObject(varView.grid.reglas) ? {} : {filters: JSON.stringify(varView.grid.reglas)}
  });

  grid.jqGrid('gridResize', {handles: "s", minHeight: 80});
  grid.jqGrid('bindKeys');
  grid.jqGrid('filterToolbar', {stringResult: true, searchOperators: true});
  if (!varView.grid.filtros) vgrid[0].toggleToolbar();

  /*
   grid.jqGrid('navGrid', toolgrid, {edit: false, add: false, del: true}, {}, {}, {}, {multipleSearch: true, multipleGroup: true, showQuery: true});
   grid.jqGrid('navButtonAdd', toolgrid, {caption:"",title:"Barra de búsqueda", buttonicon :'ui-icon-pin-s', onClickButton:function(){vgrid[0].toggleToolbar()}});
   grid.jqGrid('navButtonAdd', toolgrid, {caption:"",title:"Formulario", buttonicon :'ui-icon-carat-2-n-s', onClickButton: editInForm});
   grid.jqGrid('navButtonAdd', toolgrid, {caption:"",title:"Nueva Alta", buttonicon :'ui-icon-plus', onClickButton: newFicha});
   */

  $(document).keydown(function (e) {
    if (e.altKey) {
      if (e.which == 70) { // Alt-f
        e.preventDefault();
        searchBar();
      } else if (e.which == 66) { // Alt-b
        e.preventDefault();
        pkSearch();
      } else if (e.which == 78) { // Alt-n
        e.preventDefault();
        newFicha();
      } else if (e.which == 86) { // Alt-v
        e.preventDefault();
        gridCollapse();
      }
    }
  });

  $("#_pk-label").contextmenu(function(e) {
    e.preventDefault();
    callFonServer("bus_call_pk");
  });

  $("#_pk-input").blur(pkBlur).autocomplete({
    //source: "/application/auto?mod=<%= (@view[:model] + @view[:arg_auto]).html_safe %>",
    source: "/application/auto?mod=" + varView.model + varView.arg_auto,
    minLength: 1,
    autoFocus: true,
    select: function (e, ui) {
      //$("#ficha").attr('src', varView.url_base + ui.item.id + '/edit' + varView.arg_edit);
      editInForm(ui.item.id);
      pkBlur();
    }
    //change: function(e, ui){vali_auto_comp(ui, $(this));},
    //response: function(e, ui){auto_comp_error(e, ui);}
  });

  /*
  $("#dialog-nim-alert").dialog({
    autoOpen: false,
    resizable: false,
    modal: true,
    width: "auto",
    buttons: {
      "Aceptar": function () {
        $(this).dialog("close");
      }
    }
  });
  */

  // Activar menú derecho si existe
  if (varView.menu_r.length > 0) $("#menu-r").css("display", "block");

  // Recalcular la anchura y altura del grid cuando se redimensione la ventana

  //$("#ficha").css("height", $(window).height() - $("#ficha").offset().top - 40);
  //$(".ui-pg-input").height(14); // Para que salga de la altura correcta el input del número de página del grid

  $(window).resize(redimWindow);

  //$("#ficha").attr('src', '<%= @view[:url_base] %>0/edit' + '<%= @view[:arg_edit] %>');
  if (varView.id_edit == -1)
    $("#ficha").attr('src', varView.url_new);
  else {
    //$("#ficha").attr('src', varView.url_base + varView.id_edit + '/edit' + varView.arg_edit);
    editInForm(varView.id_edit);
  }

  eid = varView.eid;
  jid = varView.jid;
  //if (varView.grid.visible) redimWindow(); else gridCollapse();
  if (varView.grid.visible) {
    redimWindow();
    if (varView.grid.gcols[0] == 0) $("#cell-ficha").css("display", "none");
  } else gridCollapse();

  // Acuñar la pestaña por defecto del hijo
  var url = new URL(window.location.href);
  nimDefaultTab = url.searchParams.get("tab");
});

$(window).unload(function() {
  if (winBus) winBus.close();
});