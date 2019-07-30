loadEnCurso = false;
nimRld = false;

function gridCols() {
  var gcols = [];
  if (typeof(grid) != "undefined") {
    gcols = grid.jqGrid('getGridParam', 'colModel');
  }

  var cols = {};
  for (var i in gcols) {
    cols[gcols[i].name] = {label: gcols[i].label, w: gcols[i].width, type: gcols[i].type};
  }

  return cols;
}

function setLastScroll() {
  if (typeof(grid) == "undefined") {
    lastScrollH = 0;
    lastScrollV = 0;
    lastPage = 1;
  } else {
    lastScrollH = $("#d-grid .ui-jqgrid-bdiv").scrollLeft();
    lastScrollV = $("#d-grid .ui-jqgrid-bdiv").scrollTop();
    lastPage = grid.jqGrid('getGridParam', 'page');
  }
}

function selCampo(event, modo) {
  if (loadEnCurso) return;
  if (event.node.load_on_demand != undefined) return;

  z=event.node;

  var name = event.node.name;
  var p = event.node.parent;
  while (p.name != undefined) {
    name = p.name + '.' + name;
    p = p.parent;
  }

  if (modo == "del") {
    if (typeof(grid) == "undefined") return;
    var cols = grid.jqGrid('getGridParam', 'colModel');
    for (var i = cols.length - 1; i >= 0; i--) {
      if (cols[i].label == name) break;
    }
    if (i >= 0) {
      nimColToDelete = cols[i].name;
      $("#menu-r").css("display", "block").position({my: "left top", at: "left bottom", of: event.node.element});
    }
  } else {
    // Calcular los decimales (son el último carácter del estilo)
    if (event.node.estilo == undefined)
      var dec = 0;
    else {
      var dec = parseInt(event.node.estilo.slice(-1));
      if (isNaN(dec)) dec = 0;
    }

    setLastScroll();

    callFonServer("nueva_col", {dat: JSON.stringify({col: name, modo: modo, type: event.node.type, dec: dec, cols: gridCols()})});
  }
}

function nimSetUrlRld () {
  nimRld = true;
  grid.setGridParam({url: nimGridUrlRld});
}

function nimReload() {
  nimSetUrlRld();
  //$(".ui-search-table").first().find("input").trigger($.Event('keypress', {keyCode: 13}));
  grid[0].triggerToolbar();
}

function generaGrid(colMod, rows, sortname, sortorder, postdata, keepScrollH, keepScrollV) {
  var sch = keepScrollH;
  if (typeof(sch) == "boolean") sch = sch ? lastScrollH : 0;

  $('#d-grid').html('');
  $("#d-grid").append("<table id='grid'></table>");
  grid = $("#grid");
  //var toolgrid = '#grid_toppager';
  var pVez = true;

  nimGridUrl = '/bus/list?vista=' + _vista;
  nimGridUrlRld = nimGridUrl + "&rld=1";

  var vgrid = grid.jqGrid({
    colModel: colMod,
    sortname: sortname,
    sortorder: sortorder,
    postData: postdata,
    page: (keepScrollV ? lastPage : 1),
    //url: '/bus/list?vista=' + _vista,
    url: nimGridUrl,
    datatype: "json",
    mtype: 'POST',
    rowNum: rows,
    search: !$.isEmptyObject(postdata), // Para indicar que hay búsqueda activa o no

    gridview: true,

    toppager: true,
    scroll: false,

    rowList: [0, 50, 100, 200, 500, 1000],
    altRows: true,	// filas tipo cebra
    sortable: true,	// Si las columnas se pueden reordenar (cambiar de sitio)
    viewrecords: true,	// Muestra información del total de registros en la toolbar

    ondblClickRow: gridSelect,

    shrinkToFit: false,
    multiSort: true,
    beforeRequest: function() {
      if (loadEnCurso || checkNimServerStop()) {
        return false;
      } else {
        loadEnCurso = true;
        // Ocultamos el viewport del grid para evitar parpadeos al redimensionar en el evento loadComplete
        $("#d-grid .ui-jqgrid-view").css("display", "none");
        return true;
      }
    },
    loadComplete: function() {
      grid.setGridParam({url: nimGridUrl});
      setTimeout(function() {
        redimWindow();
        $("#d-grid .ui-jqgrid-view").css("display", "block");
        //if (pVez) $("#d-grid .ui-jqgrid-bdiv").scrollLeft(keepScrollH ? lastScrollH : 90000).scrollTop(keepScrollV ? lastScrollV : 0);
        if (pVez) $("#d-grid .ui-jqgrid-bdiv").scrollLeft(sch).scrollTop(keepScrollV ? lastScrollV : 0);
        if (!nimRld && nimRldServer) nimPopup("Recargue datos para obtener reultados", {of: window});
        nimRld = loadEnCurso = pVez = false;
      }, 100);
    },
    resizeStart: function() {
      lastScrollH = $("#d-grid .ui-jqgrid-bdiv").scrollLeft();
    },
    resizeStop: function() {
      redimWindow();
      $("#d-grid .ui-jqgrid-bdiv").scrollLeft(lastScrollH);
    },
    onPaging: nimSetUrlRld
  });

  //grid.jqGrid('gridResize', {handles: "s,e", minHeight: 80});
  grid.jqGrid('bindKeys');
  grid.jqGrid('filterToolbar', {stringResult: true, searchOperators: true});
  //vgrid[0].toggleToolbar();

  //$(".ui-pg-input").height(14); // Para que salga de la altura correcta el input del número de página del grid

  // Botón para recargar el grid
  $("#grid_toppager_left").html('<i class="material-icons nim-reload" onclick="nimReload()" title="Recargar datos">autorenew</i>');
}

function gridSelect(id) {
  if (id)
    grid.jqGrid('setSelection', id)
  else
    id = grid.jqGrid('getGridParam', 'selrow');

  if (id == 0) return;

  if (!id) {
    alert("Seleccione un registro");
    return;
  }

  if (typeof(_autoCompField) == "undefined") _autoCompField = 'auto';

  switch (_autoCompField) {
    case 'mant':
      window.opener.editInForm(id);
      if (!$("#no_cerrar").is(":checked")) window.close();
      break;
    case 'auto':
      //if (_controlador_edit != 'no') window.open("/" + _controlador_edit + "/" + id + "/edit");
      if (_controlador_edit != 'no') window.open("/" + _controlador_edit + "?id_edit=" + id);
      break;
    case '*hb':
      // histórico de borrados
      callFonServer("histo_borrados_sel", {mod: modelo, ctr: _controlador_edit, id: id});
      break;
    default:
      callFonServer("bus_value", {id: id, type: _autoCompField.data("type")}, null, true);

      // Si el id contiene underscores (hijos) nos quedamos con el id del padre
      id = id.toString().split("_")[0];

      _autoCompField.attr("dbid", id);
      if (_autoCompField.data("fon_auto")) // función asociada propia
        _autoCompField.data("fon_auto").call(null, _autoCompField, id);
      else if (_autoCompField.attr("cmp")) // grids embebidos
        _autoCompField.parents('table').attr('last_autocomp_id', id);
      else {
        //_autoCompField.attr("dbid", id);
        window.opener.send_validar(_autoCompField, id);
      }
  }
}

function redimWindow() {
  var wtc = $("#tree-campos").width();
  $("#d-grid").css("left", (wtc + 8) + "px");

  var h = $(window).height() - $("#d-titulo").height();
  $("#tree-campos").css("height", h);

  if (typeof(grid) != "undefined") {
    grid.setGridWidth($(window).width() - wtc - 12);
    grid.setGridHeight(h - 77);
  }
}

function viewSel() {
  view = $("#view-sel").val();
  $('#tree-campos').tree('loadDataFromUrl', '/gi/campos?node=' + view + '&emp=' + empresa);
  callFonServer("view_sel", {view: view});
}

function gridExport(tipo) {
  //ponBusy();
  //callFonServer("bus_export", {tipo: tipo}, quitaBusy);
  callFonServer("bus_export", {tipo: tipo});
}

function busNew() {
  $("#bus-sel").prop("selectedIndex", -1);
  view = modelo;
  $('#tree-campos').tree('loadDataFromUrl', '/gi/campos?node=' + view + '&emp=' + empresa);
  $('#view-sel').val(view).attr("disabled", false);
  callFonServer("view_sel", {view: view});
}

function busSave() {
  ficheros = [];
  $("#bus-sel optgroup[label='" + usuCod + "'] option").each(function() {ficheros.push($(this).text())});
  var fs = $("#bus-sel option:selected");
  var fn = (fs.length > 0 && fs.val().slice(0, 14)) == "bus/_usuarios/" ? fs.text() : "";
  $("#inp-save").val(fn);
  $("#dialog-save").dialog("open");
}

function resetFiltros() {
  callFonServer("reset_filtros");
}

function busDel() {
  var fic = $("#bus-sel").val();
  if (fic && fic.slice(0, 14) == "bus/_usuarios/") {
    $("#dialog-del").dialog("open");
  }
}

function busSel() {
  callFonServer("bus_sel", {fic: $("#bus-sel").val()});
}

function busPref() {
  var fic = $("#bus-sel").val();
  if (fic && fic != "") {
    $("#dialog-pref").dialog("open");
  }
}

function busHelp() {
  $("#dialog-help").dialog("open");
}

function delColumna() {
  setLastScroll();
  callFonServer("nueva_col", {dat: JSON.stringify({col: nimColToDelete, modo: "del", cols: gridCols()})});
}

$(window).load(function() {
  _controlador = 'bus';
  ficPrefijo = "bus/_usuarios/" + usuCod + "/" + modelo + "/";

  $("#dialog-save").dialog({
    title: "Guardar búsqueda",
    autoOpen: false,
    resizable: false,
    modal: true,
    width: "auto",
    buttons: {
      "Aceptar": function() {
        $(this).dialog("close");
        var fi = $("#inp-save").val();
        if (fi == "") return;

        callFonServer("bus_save", {fic: fi, dat: JSON.stringify({cols: gridCols()})});

        var fic = ficPrefijo + fi + '.yml';
        var nuevo = true;
        $("#bus-sel option").each(function() {
          if ($(this).val() == fic) {
            $(this).attr("selected", true);
            nuevo = false;
            return false;
          }
        });

        if (nuevo) {
          var usugr = $("#bus-sel optgroup").first();
          if (usugr.attr("label") != usuCod) {
            $("#bus-sel").prepend("<optgroup label=" + usuCod + "></optgroup>");
            usugr = $("#bus-sel optgroup").first();
          }
          usugr.append("<option value=" + fic + " selected>" + fi + "</option>");
        }
      },
      "Cancelar": function() {
        $(this).dialog("close");
      }
    }
  });

  $("#dialog-del").dialog({
    title: "Eliminar",
    autoOpen: false,
    resizable: false,
    modal: true,
    width: "auto",
    buttons: {
      "No": function() {
        $(this).dialog("close");
      },
      "Si": function() {
        $(this).dialog("close");
        callFonServer("bus_del", {fic: $("#bus-sel").val()});
        $("#bus-sel option:selected").remove();
        busNew();
      }
    }
  });

  $("#dialog-pref").dialog({
    title: "Predeterminar",
    autoOpen: false,
    resizable: false,
    modal: true,
    width: "auto",
    buttons: {
      "No": function() {
        $(this).dialog("close");
      },
      "Si": function() {
        $(this).dialog("close");
        callFonServer("bus_pref", {fic: $("#bus-sel").val()});
      }
    }
  });

  $("#dialog-help").dialog({
    title: "Ayuda",
    autoOpen: false,
    resizable: false,
    modal: true,
    width: "auto"
  });

  $("#tree-campos").tree({
    selectable: false,
    //dataUrl: '/gi/campos?node=' + view
    dataUrl: '/gi/campos?node=' + view + '&emp=' + empresa,
    onCreateLi: function (node, $li, is_selected) {
      if (node.title) $li.attr("title", node.title);
    }
  });

  $('#tree-campos')
    .bind('tree.click', function(event) {selCampo(event, 'add')})
    .bind('tree.contextmenu', function(event) {selCampo(event, 'del')})
    .bind('tree.open', redimWindow)
    .bind('tree.close', redimWindow)
    .bind('tree.init', function(event) {
      if (fic_pref) {
        callFonServer('bus_sel', {fic: fic_pref});
        $('#bus-sel').val(fic_pref);
      }
    });

  $("#d-grid").on("keydown", ".ui-search-table input", function(e) {
    if (e.keyCode == 13) nimSetUrlRld();
  });

  $("#d-grid").on("contextmenu", ".ui-jqgrid-labels th", function(e) {
    e.preventDefault();
    $("#menu-r").css("display", "block").position({my: "top", at: "bottom+5", of: this});
    nimColToDelete = grid.jqGrid('getGridParam', 'colModel')[$(this).index()].name;
  });

  $("#inp-save").on("input", function() {
    var c;
    var v = $(this).val();
    var cur = $(this).caret().begin;

    var vb = "";
    for (var i = 0; c = v[i]; i++) if (c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') vb += c; else cur--;

    $(this).css("color", $.inArray(vb, ficheros) >= 0 ? "red" : "black");
    $(this).val(vb);
    $(this).caret(cur);
  });

  $(window).unload(function() {
    if (_autoCompField == 'mant') opener.winBus = null;
  });

  $(window).resize(redimWindow);

  redimWindow();
});
