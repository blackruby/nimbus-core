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

function selCampo(event, modo) {
  if (event.node.load_on_demand != undefined) return;
  z=event.node;

  var name = event.node.name;
  var p = event.node.parent;
  while (p.name != undefined) {
    name = p.name + '.' + name;
    p = p.parent;
  }

  // Calcular los decimales (son el último carácter del estilo)
  if (event.node.estilo == undefined)
    var dec = 0;
  else {
    var dec = parseInt(event.node.estilo.slice(-1));
    if (isNaN(dec)) dec = 0;
  }


  // Construir el vector de columnas
  if (typeof(grid) == "undefined") {
    lastScrollH = 0;
    lastScrollV = 0;
    lastPage = 1;
  } else {
    lastScrollH = $("#d-grid .ui-jqgrid-bdiv").scrollLeft();
    lastScrollV = $("#d-grid .ui-jqgrid-bdiv").scrollTop();
    lastPage = grid.jqGrid('getGridParam', 'page');
  }

  callFonServer("nueva_col", {dat: JSON.stringify({col: name, modo: modo, type: event.node.type, dec: dec, cols: gridCols()})});
}

function generaGrid(colMod, sortname, sortorder, postdata, keepScrollH, keepScrollV) {
  $('#d-grid').html('');
  $("#d-grid").append("<table id='grid'></table>");
  grid = $("#grid");
  //var toolgrid = '#grid_toppager';

  var vgrid = grid.jqGrid({
    colModel: colMod,
    sortname: sortname,
    sortorder: sortorder,
    postData: postdata,
    page: (keepScrollV ? lastPage : 1),
    url: '/bus/list?vista=' + _vista,
    datatype: "json",
    mtype: 'POST',
    rowNum: 100,
    search: !$.isEmptyObject(postdata), // Para indicar que hay búsqueda activa o no

    gridview: true,

    toppager: true,
    scroll: false,

    rowList: [100, 500, 1000],
    altRows: true,	// filas tipo cebra
    sortable: true,	// Si las columnas se pueden reordenar (cambiar de sitio)
    viewrecords: true,	// Muestra información del total de registros en la toolbar

    ondblClickRow: gridSelect,

    shrinkToFit: false,
    multiSort: true,
    loadComplete: function() {
      $("#d-grid .ui-jqgrid-bdiv").scrollLeft(keepScrollH ? lastScrollH : 90000).scrollTop(keepScrollV ? lastScrollV : 0);
      //eval(onload);
      //setTimeout(function(){console.log('ya', onload);grid.jqGrid('setGridParam', {loadComplete: null});eval(onload);},100);
      //onload = ""
    }
  });

  //grid.jqGrid('gridResize', {handles: "s,e", minHeight: 80});
  grid.jqGrid('bindKeys');
  grid.jqGrid('filterToolbar', {stringResult: true, searchOperators: true});
  //vgrid[0].toggleToolbar();

  //$(".ui-pg-input").height(14); // Para que salga de la altura correcta el input del número de página del grid

  gridLeft();
  gridDim();

  //$("#grid").jqGrid('setGridParam', {url: '/bus/list?vista=' + _vista, datatype: 'json', mtype: 'POST', postData: {filters: '{"groupOp":"AND","rules":[{"field":"anunciantes.codigo","op":"cn","data":"000"}]}'}})
  //grid.trigger('reloadGrid')

  /**
   $(".ui-search-input").on("change", "input", function(e) {
      var gsi = $(this);
      z = $(this);
      console.log('Cambio');
      //setTimeout(function(){gsi.val('')}, 100);
    });
   **/
}

function gridSelect(id) {
  if (id)
    grid.jqGrid('setSelection', id)
  else
    id = grid.jqGrid('getGridParam', 'selrow');

  if (!id) {
    alert("Seleccione un registro");
    return;
  }

  if (typeof(_autoCompField) == "undefined") _autoCompField = 'auto';

  switch (_autoCompField) {
    case 'mant':
      window.opener.editInForm(id);
      window.close();
      break;
    case 'auto':
      //if (_controlador_edit != 'no') window.open("/" + _controlador_edit + "/" + id + "/edit");
      if (_controlador_edit != 'no') window.open("/" + _controlador_edit + "?id_edit=" + id);
      break;
    default:
      callFonServer("bus_value", {id: id}, null, true);

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

function gridLeft() {
  $("#d-grid").css("left", ($("#tree-campos").width() + 8) + "px");
}

function gridDim() {
  if (typeof(grid) == "undefined") return;
  var w = $(window).width() - $("#tree-campos").width() - 12;
  var h = $(window).height() - $("#d-titulo").height() - 77;
  grid.setGridWidth(w);
  grid.setGridHeight(h);
}

function redimWindow() {
  var h = $(window).height() - $("#d-titulo").height();
  $("#tree-campos").css("height", h);
  gridDim();
}

function gridExport(tipo) {
  ponBusy();
  callFonServer("bus_export", {tipo: tipo}, quitaBusy);
}

function busNew() {
  $("#bus-sel").prop("selectedIndex", -1);
  generaGrid([],'','',{},false,false);
}

function busSave() {
  ficheros = [];
  $("#bus-sel optgroup[label=" + usuCod + "] option").each(function() {ficheros.push($(this).text())});
  var fs = $("#bus-sel option:selected");
  var fn = (fs.length > 0 && fs.val().slice(0, 14)) == "bus/_usuarios/" ? fs.text() : "";
  $("#inp-save").val(fn);
  $("#dialog-save").dialog("open");
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

  $("#tree-campos").tree({
    selectable: false,
    dataUrl: '/gi/campos?node=' + modelo
  });

  $('#tree-campos')
    .bind('tree.click', function(event) {selCampo(event, 'add')})
    .bind('tree.contextmenu', function(event) {selCampo(event, 'del')})
    .bind('tree.open', gridLeft)
    .bind('tree.close', gridLeft)
    .bind('tree.init', function(event) {
      if (fic_pref) {
        callFonServer('bus_sel', {fic: fic_pref});
        $('#bus-sel').val(fic_pref);
      }
    });

  /*
   $("body").on("click", ".clearsearchclass", function(e) {
   var gsi = $(this).parent().prev().find('input');
   setTimeout(function(){gsi.val('')}, 100);
   });
   */

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

  $(window).resize(redimWindow);

  redimWindow();
});
