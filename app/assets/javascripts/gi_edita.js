var lastWindowPrint;
var abrirInforme = false;
var celda, nRup = 0, nCol = 0, nCel = 0;
var lastCmp;

function setTitulo() {
  $("#d-titulo").html(titMain + '&nbsp;&nbsp;&nbsp;&nbsp; Modelo: ' + modelo + '&nbsp;&nbsp;&nbsp;&nbsp; Módulo: ' + modulo + (fileName == '' ? '' : '&nbsp;&nbsp;&nbsp;&nbsp; Formato: ' + fileName));
  document.title = titMain + ' Modelo: ' + modelo + ' Módulo: ' + modulo + (fileName == '' ? '' : ' Formato: ' + fileName);
}

function nextItem(lista, pref, suf) {
  var n = 0, ali, it, i, m;
  $("#" + lista + " td:nth-child(1):not(.subtit)").each(function() {
    it = $(this).text();
    if (it[0] != pref) return;
    if (suf) {
      i = it.indexOf(suf);
      if (i == -1) i = undefined;
    } else
      i = undefined;

    m = it.slice(1, i);
    if (isFinite(m)) n = Math.max(m, n);
  });
  return(pref + (n + 1));
}

function giPrint() {
  abrirInforme = true;
  if (fileName == "")
    $("#grabar").dialog("open");
  else
    grabaFic();
}

function genArrayBan(rows) {
  var ar = [], r;
  rows.each(function() {
    r = [];
    var altura_fila = $(this).find("input").val();
    $(this).find(".celda").each(function() {
      altura_fila == "" ? delete $(this).data('prop').height : $(this).data('prop').height = altura_fila;
      r.push($(this).data("prop"));
      altura_fila = "";
    });
    ar.push(r);
  });

  return(ar);
}

function grabaFic() {
  var data = {}
  if (Object.keys(formato).length == 0) {
    // Si es nuevo.
    data.version = 2.0;
  } else if (formato.version) {
    // Si ya existía y tenía versión, respetarla.
    data.version = formato.version;
  }
  data.modelo = modelo;

  var th, cl, h, trup;

  // Generamos la cadena de anchuras de columnas en el input col_widthd
  // para que se siga grabando como en la versión anterior
  var cw = [];
  $("#t_width input").each(function() {
    var val = $(this).val();
    cw.push(val == "" ? 0 : val);
  });
  var numCerosFinales = 0;
  for (let i = cw.length - 1; i >= 0; i--) if (cw[i] == 0) numCerosFinales++; else break;
  cw.length = cw.length - numCerosFinales;
  $("#col_widths").val(cw.join(','));

  $("#config :input").each(function() {
    th =$(this);
    if (th.attr("type") == "checkbox")
      data[th.attr("id")] = th.is(':checked');
    else
      data[th.attr("id")] = th.val();
  });

  data.formulas = {};
  $("#t_formulas textarea").each(function() {
    var el = $(this);
    data.formulas[el.parent().prev().text()] = el.val();
  });

  data.select = {};
  $("#t_select textarea").each(function() {
    var el = $(this);
    data.select[el.parent().prev().text()] = el.val();
  });

  data.where = {};
  $("#t_where textarea").each(function() {
    var el = $(this);
    data.where[el.parent().prev().text()] = el.val();
  });

  data.order = $("#order").val();
  data.group = $("#group").val();

  data.having = {};
  $("#t_having textarea").each(function() {
    var el = $(this);
    data.having[el.parent().prev().text()] = el.val();
  });

  data.join = $("#join").val();

  data.cab = genArrayBan($("#t_cab tr"));
  data.det = genArrayBan($("#t_det tr"));
  data.pie = genArrayBan($("#t_pie tr"));
  data.rup = [];
  $("#t_rup [class^=rup]").each(function(){
    cl = $(this).attr("class");
    h = {};
    h.campo = $(this).find("textarea").val();
    h.salto = $(this).find("input").is(":checked");
    trup = $("table." + cl);
    h.cab = genArrayBan(trup.first().find("tr"));
    h.pie = genArrayBan(trup.last().find("tr"));
    data.rup.push(h);
  });
  $("table[class^=bu_]").each(function() {
    var cl = $(this).attr('class');
    cl = cl.slice(0, cl.indexOf(' '));
    data[cl] = genArrayBan($(this).find("tr"));
  });

  data.lim = {};
  $("#t_lim textarea").each(function() {
    var el = $(this);
    data.lim[el.parent().prev().text()] = el.val();
  });

  data['style'] = {};
  $("#estilos input").each(function() {
    var e = $(this);
    data['style'][e.val()] = e.parent().next().children().val();
  });

  var fn = $("#filename").val();
  var mod = $("#destino").val();

  $.post('/gi/graba_fic', {modulo: mod, formato: fn, data: JSON.stringify(data)}, function(d) {
    if (d == 's') {
      fileName = fn;
      modulo = mod;
      if ($.inArray(fn, allFiles[mod]) == -1) allFiles[mod].push(fn);
      setTitulo();
      if (abrirInforme) {
        if (lastWindowPrint != undefined) lastWindowPrint.close();
        lastWindowPrint = window.open('/gi/run/' + mod + '/' + fn);
      }
    } else {
      alert('Se ha producido un error en la grabación.');
    }
    $("#grabar").dialog("close");
  });
}

function iniGrabar() {
  $("#filename").val(fileName);
  $("#destino").val(modulo);
  $("#filename").removeClass('file_exists');
  $("#b_grabar").button(fileName == '' ? "disable" : "enable");
}

function checkFile(vb) {
  var dest = $("#destino").val();
  if ((vb != fileName || dest != modulo) &&  $.inArray(vb, allFiles[dest]) >= 0)
    $("#filename").addClass('file_exists');
  else
    $("#filename").removeClass('file_exists');
}

function nuevaBanUsu() {
  addBanUsu($("#banda_usu_name").val(), genCadRow());
  iniPropCell();
  $("#banda_usu").dialog("close");
}

function genCoal(ali, ty, lim) {
  switch(ty) {
    case 'integer':
    case 'decimal':
      return("COALESCE(:" + ali + "," + (lim == 'g' ? "-9999999999" : "9999999999") + ")");
    default:
      return("COALESCE(:" + ali + "," + (lim == 'g' ? "''" : "'zzzzzzz'") + ")");
  }
}

function generaLim(ali, node, prop, cond) {
  var label, wh;

  if (node.pk && $("#asist_lim_pk").is(":checked")) {
    ali += '_id';
    var ref = node.parent.id;
    if (!ref) ref = modelo;
    prop += ", ref: '" + ref + "', cmph: '" + node.name + "'";
    prop += ", sinil: :b";
    switch(cond) {
      case 'eq':
        label = node.name;
        wh = $("#asist_lim_ref").val() + ' = ' + ':' + ali;
        break;
      case 'ge':
        label = 'Desde ' + node.name;
        wh = $("#asist_lim_ref").val() + ' >= ' + genCoal(ali, node.type, 'g');
        break;
      case 'le':
        label = 'Hasta ' + node.name;
        wh = $("#asist_lim_ref").val() + ' <= ' + genCoal(ali, node.type, 'l');
        break;
    }
  } else {
    if (node.id) {
      prop += ", ref: '" + node.id + "'";
      prop += ", sinil: :b";
      ali += '_id';
    }

    if (cond != 'rg') prop += ", type: :" + node.type;

    if (node.type == 'date' || node.type == 'datetime' || node.type == 'time') prop += ', req: true';

    switch(cond) {
      case 'eq':
        label = node.name;
        wh = $("#asist_lim_ref").val() + ' = ' + ':' + ali;
        break;
      case 'ge':
        label = 'Desde ' + node.name;
        wh = $("#asist_lim_ref").val() + ' >= ' + ':' + ali;
        break;
      case 'le':
        label = 'Hasta ' + node.name;
        wh = $("#asist_lim_ref").val() + ' <= ' + ':' + ali;
        break;
      case 'rg':
        prop += ', rango: true'
        label = node.name;
        wh = $("#asist_lim_ref").val() + ' in (:' + ali + ')';
        break;
    }
  }

  if ($("#asist_lim_label").is(":checked")) prop += ", label: '" + label + "'";
  if ($("#asist_lim_wh").val() == 'wh') {
    addWhere(ali, wh);
    $("#where").dialog("open");
  } else if ($("#asist_lim_wh").val() == 'ha') {
    addHaving(ali, wh);
    $("#having").dialog("open");
  }

  addLim(ali, prop);
}

function asistLim() {
  var prop = "tab: 'pre', gcols: 3";

  var ali = $("#asist_lim_alias").val();
  var node = $("#asist_lim_ref").data("cmp");
  if (node) {
    if (node.manti && !(node.pk && $("#asist_lim_pk").is(":checked"))) prop += ", manti: " + node.manti;
    /*
    if (node.decim) {
      var ia = node.decim.toString().indexOf('#{');
      if (ia == -1)
        prop += ", decim: " + node.decim;
      else
        prop += ", decim: " + node.decim.slice(ia + 2, node.decim.lastIndexOf('}'));
    }
    */
    if (node.decim) prop += ", decim: " + node.decim;

    var cond = $("#asist_lim_cond").val();
    if (cond == 'dh') {
      generaLim(ali + '_d', node, prop, 'ge');
      generaLim(ali + '_h', node, prop, 'le');
    } else
      generaLim(ali, node, prop, cond);
  } else {
    addLim(ali, prop);
  }
}

function addLim(name, val) {
  if (lastCmp && lastCmp.is("#lim :input"))
    lastSelectLim = lastCmp.parent().parent();
  else
    lastSelectLim = $("#t_lim tr").last();

  if (name == undefined) {
    $("#asist_lim_ref").val('').data('cmp', null);
    $("#asist_lim_alias").val(nextItem('t_lim', 'L', '_'));
    $("#asist_lim_cond").val('eq');
    $("#asist_lim_wh").val('wh');
    $("#asist_lim_pk").attr("disabled", true).prop("checked", false);
    $("#asist_lim").dialog('open');
    return;
  }

  if (val == undefined) val = "";

  lastSelectLim.after("<tr><td class='alias_lim'>" + name + "</td><td><textarea rows=1 class='i_cmp'>" + val + "</textarea></td></tr>");
  if (val == "") lastSelectLim.next().find("textarea").focus();
}

function delLim() {
  if (lastCmp && lastCmp.is("#lim :input") && lastCmp.parent().parent().index() > 0) {
    var ali = lastCmp.parent().prev().text();
    $(".alias_where:contains(" + ali + ")").parent().remove();
    lastCmp.parent().parent().remove();
  }
}

function addFormula(name, val) {
  if (name == undefined) name = nextItem("t_formulas", 'F');
  if (val == undefined) val = "";

  var elem;
  if (lastCmp && lastCmp.is("#formulas :input"))
    elem = lastCmp.parent().parent();
  else
    elem = $("#t_formulas tr").last();

  elem.after("<tr><td class='alias_formulas'>" + name + "</td><td><textarea rows=1 class='i_cmp admite_campo admite_sel admite_for admite_lim1'>" + val + "</textarea></td></tr>");
  if (val == "") elem.next().find("textarea").focus();
}

function delFormula() {
  if (lastCmp && lastCmp.is("#formulas :input")) lastCmp.parent().parent().remove();
}

function addSelect(name, val) {
  if (name == undefined) name = nextItem("t_select", 'S');
  if (val == undefined) val = "";

  var elem;
  if (lastCmp && lastCmp.is("#select :input"))
    elem = lastCmp.parent().parent();
  else
    elem = $("#t_select tr").last();

  elem.after("<tr><td class='alias_select'>" + name + "</td><td><textarea rows=1 class='i_cmp admite_campo'>" + val + "</textarea></td></tr>");
  if (val == "") elem.next().find("textarea").focus();
}

function delSelect() {
  if (lastCmp && lastCmp.is("#select :input")) lastCmp.parent().parent().remove();
}

function addWhere(name, val) {
  if (name == undefined) name = nextItem("t_where", 'W');
  if (val == undefined) val = "";

  var elem;
  if (lastCmp && lastCmp.is("#where :input"))
    elem = lastCmp.parent().parent();
  else
    elem = $("#t_where tr").last();

  elem.after("<tr><td class='alias_where'>" + name + "</td><td><textarea rows=1 class='i_cmp admite_campo admite_lim2'>" + val + "</textarea></td></tr>");
  if (val == "") elem.next().find("textarea").focus();
}

function delWhere() {
  if (lastCmp && lastCmp.is("#where :input")) lastCmp.parent().parent().remove();
}

function addHaving(name, val) {
  if (name == undefined) name = nextItem("t_having", 'H');
  if (val == undefined) val = "";

  var elem;
  if (lastCmp && lastCmp.is("#having :input"))
    elem = lastCmp.parent().parent();
  else
    elem = $("#t_having tr").last();

  elem.after("<tr><td class='alias_where'>" + name + "</td><td><textarea rows=1 class='i_cmp admite_campo admite_lim2'>" + val + "</textarea></td></tr>");
  if (val == "") elem.next().find("textarea").focus();
}

function delHaving() {
  if (lastCmp && lastCmp.is("#having :input")) lastCmp.parent().parent().remove();
}

function llenaEstilos() {
  var est = "";
  $("#t_estilos input").each(function(){
    var v = $(this).val();
    if (v.trim() != "") est += '<option value="' + (v == "def" ? "" : v) + '">' + v + '</option>';
  });
  var v = $("#estilo").val();
  $("#estilo").html(est);
  $("#estilo").val(v);
}

function addEstilo(name, val) {
  var elem;

  if (name == undefined) name = "";
  if (val == undefined) val = "";

  if (lastCmp && lastCmp.is("#estilos :input"))
    elem = lastCmp.parent().parent();
  else
    elem = $("#t_estilos tr").last();

  elem.after("<tr><td><input class='i_cmp' value='" + name +"'/></td><td><textarea class='i_cmp' rows=1>" + val + "</textarea></td></tr>");
  if (name == "") elem.next().find("input").focus();
}

function delEstilo() {
  if (lastCmp && lastCmp.is("#estilos :input") && lastCmp.parent().parent().index() > 1) lastCmp.parent().parent().remove();
  llenaEstilos();
}

function checkEstilo(esti, decim) {
  if (esti == "dyn") {
    var mnd = 0;
    var estiV = ":def_d, {format_code: '#,##0.'+'0'*" + decim + "}";

    $("#t_estilos textarea").each(function() {
      var e = $(this).parent().prev().find("input").val();
      if ($(this).val() == estiV) {
        esti = e;
        return false;
      }
      if (e.substr(0, 4) == "dyn_") {
        var nd = parseInt(e.slice(4));
        if (!isNaN(nd) && nd > mnd) mnd = nd;
      }
    });
    if (esti == "dyn") {
      esti = "dyn_" + (mnd + 1);
      addEstilo(esti, estiV);
      llenaEstilos();
    }
  } else {
    var a = true;

    $("#t_estilos input").each(function() {
      if ($(this).val() == esti) {
        a = false;
        return false;
      }
    });
    if (a) {
      var n = esti.slice(3);
      var c = "0000000000".slice(10-n);
      addEstilo("dec" + n, ":def_d, {format_code: '#,##0." + c + "'}");
      llenaEstilos();
    }
  }

  return(esti);
}

function fullCampo(node) {
  var label;

  node = node || $("#tree_campos").tree('getSelectedNode');
  if (node) {
    label = node.name;
    if (node.id) label += '_id';
    node = node.parent;
    while (node.name != undefined) {
      label = node.name + '.' + label;
      node = node.parent;
    }
    return(label);
  } else
    return('');
}

function bBandaStatus() {
  $(".b_banda").button("enable");
  if (celda.prev().length == 0) $("#swp_w").button("disable");
  //if (celda.next().length == 0) $("#swp_e").button("disable");
  if (!celda.next().hasClass("celda")) $("#swp_e").button("disable");
  if (celda.parent().prev().length == 0) $("#swp_n").button("disable");
  if (celda.parent().next().length == 0) $("#swp_s").button("disable");
  if (nCol == 1) $("#del_c").button("disable");
}

function setCell(c) {
  celda = c;
  //$(".t_banda td").css("background-color", "#ffffff");
  $(".t_banda .celda").css("background-color", "#ffffff");
  celda.css("background-color", "#d3d3d3");
  bBandaStatus();
  var prop = celda.data('prop');
  $("#prop-celdas .i_cmp").each(function() {
    $(this).attr("disabled", false).val(prop[$(this).attr("id")]);
  });
  /*
   $("#prop-celdas .i_cmp").attr("disabled", false);
   $("#campo").val(prop.campo);
   $("#estilo").val(prop.estilo);
   $("#tipo").val(prop.tipo);
   $("#alias").val(prop.alias);
   */

  $("#campo").focus();
}

function noCell() {
  $(".b_banda").button("disable");
  $("#prop-celdas .i_cmp").attr("disabled", true).val('');
}

function iniPropCell() {
  $(".cell-new").each(function() {
    $(this).data('prop', {});
  });
  $(".cell-new").removeClass('cell-new');
}

function genColWidth(val = "") {
  setTimeout(function() {$(".anchura-columnas input").entryn(3, 0, false, true);}, 0);
  return `<td class='anchura-columnas'><input value='${val}' /></td>`;
}

function genCell() {
  nCel += 1;
  return('<td class="celda cell-new">&nbsp;</td>');
}

function genCol(ew) {
  var i = celda.index() + 1;
  $(".t_banda td:nth-child(" + i + ")").each(function () {
    var ia = $(this).hasClass("anchura-columnas");
    (ew == 'w') ? $(this).before(ia ? genColWidth() : genCell()) : $(this).after(ia ? genColWidth() : genCell());
  });
  nCol += 1;
  bBandaStatus();
  iniPropCell();
}

function genRowHeight(val = "") {
  setTimeout(function() {$(".altura-filas input").entryn(3, 0, false, true);}, 0);
  return `<td class='altura-filas'><input value='${val}' title='Altura de la fila' /></td>`;
}

function genCadRow() {
  var cad = '<tr>';
  for (var i = 0; i < nCol; i++) {
    cad += genCell();
  }
  cad += genRowHeight();
  cad += '</tr>';

  return cad;
}

function genRow(ns) {
  var cad = genCadRow();
  (ns == 'n') ? $(celda.parent()).before(cad) : $(celda.parent()).after(cad);
  bBandaStatus();
  iniPropCell();
}

function swpCell(cd) {
  var prop = cd.data('prop');
  cd.data('prop', celda.data('prop'));
  celda.data('prop', prop);
  var ht = cd.html();
  cd.html(celda.html());
  celda.html(ht);
  var ti = cd.attr('title');
  cd.attr('title', celda.attr('title'));
  celda.attr('title', ti);
  setCell(cd);
}

function banLeft() {
  $("#bandas").css("left", ($("#tree_campos").width() + 10) + "px");
}

function redimWindow() {
  var h = $(window).height() - $("#d-titulo").height() * 2 - 2;
  $("#tree_campos").css("height", h);
}

function addRup(htm, cmp, salto) {
  if (cmp == undefined) cmp = '';
  if (salto == undefined) salto = false;

  var cl = 'rup_' + ++nRup;
  $("#tt_det").before(
    '<p class="' + cl + ' tit_band tit ui-widget-header ui-corner-all">Cabecera de Ruptura</p>' +
    '<table id="' + cl + '_h" class="' + cl + ' t_banda"><tbody>' + htm + '</tbody></table>'
  );
  $("#t_det").after(
    '<p class="' + cl + ' tit_band tit ui-widget-header ui-corner-all">Pie de Ruptura</p>' +
    '<table id="' + cl + '_p" class="' + cl + ' t_banda"><tbody>' + htm + '</tbody></table>'
  );

  $("#t_rup tr").last().after(
    '<tr class="' + cl +'">' +
    '<td><textarea rows="1" class="i_cmp admite_campo admite_sel admite_for admite_lim1">' + cmp +'</textarea></td>' +
    '<td style="vertical-align: top;text-align: center"><input type="checkbox" class="i_cmp" style="width: auto"' + (salto ? ' checked' : '') + '/></td>' +
    '</tr>'
  );
  return cl;
}

function addBanUsu(name, htm) {
  var cl = 'bu_' + name;
  $(".t_banda").last().after(
    '<p class="' + cl + ' tit_band tit ui-widget-header ui-corner-all">Banda de usuario: ' + name + '</p>' +
    '<table id="' + cl + '" class="' + cl + ' t_banda"><tbody>' + htm + '</tbody></table>'
  );
}

function leeFormBanda(tabla, arr_ban) {
  $.each(arr_ban, function(i, ban) {
    $("#" + tabla + " tbody").append("<tr></tr>");
    var el = $("#" + tabla + " tr").last();
    $.each(ban, function(j, cel) {
      el.append("<td class='celda'>" + (cel.alias ? cel.alias : "&nbsp;") + "</td>");
      el.find("td").last().attr('title', cel.campo).data('prop', cel);
      nCol = Math.max(nCol, j+1);
    });
    el.append(genRowHeight(ban[0].height));
  });
}

function linXPag() {
  var lxp = $("#linxpag");
  var cd = $("#cab_din");
  var v = lxp.val();
  if (v <= 0 || v == '') {
    lxp.val('');
    cd.attr("disabled", true);
    $("#cab_din_pdf").attr("disabled", true);
  } else {
    cd.attr("disabled", false);
    $("#cab_din_pdf").attr("disabled", !cd.is(":checked"));
  }
}

$(window).load(function () {
  // Diálogo de grabar

  $("#grabar").dialog({
    autoOpen: false,
    modal: true,
    width: 400,
    resizable: false,
    buttons: [{
      id: 'b_grabar',
      text: "Aceptar",
      click: grabaFic
    }],
    close: iniGrabar
  });

  $("#filename").on("input", function () {
    var c;
    var v = $(this).val();
    var cur = $(this).caret().begin;

    var vb = "";
    for (var i = 0; c = v[i]; i++) if (c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') vb += c; else cur--;

    checkFile(vb);

    $(this).val(vb);
    $(this).caret(cur);

    $("#b_grabar").button(vb == '' ? "disable" : "enable")
  });

  $("#filename").keypress(function (e) {
    if (e.which == 13 && $(this).val() != '') grabaFic();
  });

  $("#destino").on("change", function () {
    checkFile($("#filename").val());
    $("#filename").focus();
  });

  // Diálogo de nueva banda de usuario

  $("#banda_usu").dialog({
    autoOpen: false,
    modal: true,
    width: 400,
    resizable: false,
    buttons: [{
      id: 'b_busu',
      text: "Aceptar",
      click: nuevaBanUsu
    }]
  });

  $("#banda_usu_name").on("input", function () {
    var c;
    var v = $(this).val();
    var cur = $(this).caret().begin;

    var vb = "";
    for (var i = 0; c = v[i]; i++) if (c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') vb += c; else cur--;

    $(this).val(vb);
    $(this).caret(cur);

    var hb = (vb == '' || $('.bu_' + vb).length > 0);
    $("#b_busu").button(hb ? "disable" : "enable")
  }).on("keypress", function (e) {
    if (e.which == 13 && $("#b_busu").attr("disabled") != 'disabled') nuevaBanUsu();
  });

  // Diálogo de configuración

  $("#config").dialog({
    autoOpen: false,
    width: 600,
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });

  // Diálogo de límites

  $("#lim").dialog({
    autoOpen: false,
    width: 650,
    position: {my: "left top", at: "left+90 bottom+120", of: "#bandas"},
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });
  $("#t_lim tbody").sortable({items: "tr:not(.subtit)"});
  $("#b_add_lim").button({icons: {primary: "ui-icon-plus"}, text: false}).click(function () {
    addLim();
  });
  $("#b_del_lim").button({icons: {primary: "ui-icon-minus"}, text: false}).click(function () {
    delLim();
  });

  $("#asist_lim").dialog({
    autoOpen: false,
    width: 500,
    position: {my: "left top", at: "left+90 top+120", of: "#bandas"},
    resizable: false,
    buttons: {
      "Generar": function () {
        var ali = $("#asist_lim_alias").val();
        if (ali == '') {
          alert('Es obligatorio especificar un alias');
          $("#asist_lim_alias").focus();
          return;
        }
        var rep = false;
        $(".alias_lim").each(function () {
          var txt = $(this).text();
          if (txt == ali || txt.indexOf(ali + '_') == 0) {
            alert('Alias repetido');
            rep = true;
            return false;
          }
        });
        if (rep) {
          $("#asist_lim_alias").focus();
          return;
        }

        $(this).dialog("close");
        asistLim();
      }
    }
  });

  $("#asist_lim_ref").on("keydown", function (e) {
    if (e.keyCode != 9) e.preventDefault();
  }).bind("contextmenu", function (e) {
    return false;
  });


  $("#lim").on('dblclick', '.alias_lim', function (e) {
    if ($("#campo").is(":focus")) lastCmp = $("#campo");
    if (lastCmp && lastCmp.attr("disabled") != "disabled") {
      var v = lastCmp.val();
      var sel = lastCmp.caret();
      if (lastCmp.hasClass("admite_lim1")) {
        lastCmp.val(v.slice(0, sel.begin) + '@lim[:' + $(this).text() + ']' + v.slice(sel.end));
        lastCmp.focus();
      } else if (lastCmp.hasClass("admite_lim2")) {
        lastCmp.val(v.slice(0, sel.begin) + ':' + $(this).text() + v.slice(sel.end));
        lastCmp.focus();
      }
    }
  });

  // Diálogo de fórmulas

  $("#formulas").dialog({
    autoOpen: false,
    width: 600,
    position: {my: "left top", at: "left+100 bottom+150", of: "#bandas"},
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });
  $("#t_formulas tbody").sortable({items: "tr:not(.subtit)"});
  $("#b_add_formula").button({icons: {primary: "ui-icon-plus"}, text: false}).click(function () {
    addFormula();
  });
  $("#b_del_formula").button({icons: {primary: "ui-icon-minus"}, text: false}).click(function () {
    delFormula();
  });

  $("#formulas").on('dblclick', '.alias_formulas', function (e) {
    if ($("#campo").is(":focus")) lastCmp = $("#campo");
    if (lastCmp && lastCmp.attr("disabled") != "disabled" && lastCmp.hasClass("admite_for")) {
      var v = lastCmp.val();
      var sel = lastCmp.caret();
      lastCmp.val(v.slice(0, sel.begin) + '@fx[:' + $(this).text() + ']' + v.slice(sel.end));
      lastCmp.focus();
    }
  });

  // Diálogo de select

  $("#select").dialog({
    autoOpen: false,
    width: 400,
    position: {my: "left top", at: "left+10 bottom+10", of: "#bandas"},
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });
  $("#b_add_select").button({icons: {primary: "ui-icon-plus"}, text: false}).click(function () {
    addSelect();
  });
  $("#b_del_select").button({icons: {primary: "ui-icon-minus"}, text: false}).click(function () {
    delSelect();
  });

  $("#select").on('dblclick', '.alias_select', function (e) {
    if ($("#campo").is(":focus")) lastCmp = $("#campo");
    if (lastCmp && lastCmp.attr("disabled") != "disabled" && lastCmp.hasClass("admite_sel")) {
      var v = lastCmp.val();
      var sel = lastCmp.caret();
      lastCmp.val(v.slice(0, sel.begin) + '~' + $(this).text() + '~' + v.slice(sel.end));
      lastCmp.focus();
    }
  });

  // Diálogo de where

  $("#where").dialog({
    autoOpen: false,
    width: 600,
    position: {my: "left top", at: "left+30 bottom+40", of: "#bandas"},
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });
  $("#b_add_where").button({icons: {primary: "ui-icon-plus"}, text: false}).click(function () {
    addWhere();
  });
  $("#b_del_where").button({icons: {primary: "ui-icon-minus"}, text: false}).click(function () {
    delWhere();
  });


  // Diálogo de order

  $("#dorder").dialog({
    autoOpen: false,
    width: 400,
    position: {my: "left top", at: "left+50 bottom+70", of: "#bandas"},
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });

  // Diálogo de group

  $("#dgroup").dialog({
    autoOpen: false,
    width: 400,
    position: {my: "left top", at: "left+70 bottom+100", of: "#bandas"},
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });

  // Diálogo de having

  $("#having").dialog({
    autoOpen: false,
    width: 600,
    position: {my: "left top", at: "left+30 bottom+70", of: "#bandas"},
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });
  $("#b_add_having").button({icons: {primary: "ui-icon-plus"}, text: false}).click(function () {
    addHaving();
  });
  $("#b_del_having").button({icons: {primary: "ui-icon-minus"}, text: false}).click(function () {
    delHaving();
  });

  // Diálogo de join

  $("#djoin").dialog({
    autoOpen: false,
    width: 400,
    position: {my: "left top", at: "left+75 bottom+90", of: "#bandas"},
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });

  // Diálogo de estilos

  $("#estilos").dialog({
    autoOpen: false,
    width: 650,
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });
  $("#t_estilos tbody").sortable({items: "tr:not(.subtit)"});
  $("#b_add_estilo").button({icons: {primary: "ui-icon-plus"}, text: false}).click(function () {
    addEstilo();
  });
  $("#b_del_estilo").button({icons: {primary: "ui-icon-minus"}, text: false}).click(function () {
    delEstilo();
  });

  $("#estilos").on("blur", "input", llenaEstilos);

  /**
   $("#estilos").on("click", ":input", function(e){$("#b_del_estilo").button("enable");});
   $("#estilos").on("blur", ":input", function(e){$("#b_del_estilo").button("disable");});
   $("#b_del_estilo").button("disable");
   **/

  $("#help").dialog({
    autoOpen: false,
    width: 800,
    height: 800,
  });

  /*
   $( "#abrir" ).dialog({
   autoOpen: false,
   width: 700,
   height: 700
   });
   */

  //$("#bandas").on('click', 'td', function () {
  $("#bandas").on('click', '.celda', function () {
    if (window.event.ctrlKey) {
      if (lastCmp.is("#campo")) {
        var ban_click = $(this).parentsUntil('div').last().attr('id');
        var ban_act = celda.parentsUntil('div').last().attr('id');
        var h_click = $(this).data('prop');
        var ali = h_click.alias;
        var v = $("#campo").val();

        var ini;
        if (v == "") {
          ini = true;
          v = "'='+";
        } else
          ini = false;

        if (ban_click == ban_act) {
          if (ban_click == "t_det" && window.event.shiftKey)
            $("#campo").val(v + ' tot(:' + ali + ', 0)');
          else
            $("#campo").val(v + ' cel(:' + ali + ')');
        } else if (ban_click == "t_det") {
          $("#campo").val(v + ' tot(:' + ali + ')');
        } else
          ini = false;

        if (ini) {
          var h = celda.data('prop');
          if (ban_click != ban_act) {
            h.alias = ali;
            $("#alias").val(ali);
            celda.html(ali);
          }
          h.estilo = h_click.estilo;
          $("#estilo").val(h.estilo);
        }

        $("#campo").focus();
      }
    } else
      setCell($(this));
  });

  $("#bandas").resizable({handles: 'e'});

  $("#swp_w").button({icons: {primary: "ui-icon-arrowthick-1-w"}, text: false}).click(function () {
    swpCell(celda.prev());
  });
  $("#swp_e").button({icons: {primary: "ui-icon-arrowthick-1-e"}, text: false}).click(function () {
    swpCell(celda.next());
  });
  $("#swp_n").button({icons: {primary: "ui-icon-arrowthick-1-n"}, text: false}).click(function () {
    swpCell(celda.parent().prev().children().eq(celda.index()));
  });
  $("#swp_s").button({icons: {primary: "ui-icon-arrowthick-1-s"}, text: false}).click(function () {
    swpCell(celda.parent().next().children().eq(celda.index()));
  });
  $("#add_cw").button({icons: {primary: "ui-icon-triangle-1-w"}, text: false}).click(function () {
    genCol("w")
  });
  $("#add_ce").button({icons: {primary: "ui-icon-triangle-1-e"}, text: false}).click(function () {
    genCol("e")
  });
  $("#add_rn").button({icons: {primary: "ui-icon-triangle-1-n"}, text: false}).click(function () {
    genRow("n")
  });
  $("#add_rs").button({icons: {primary: "ui-icon-triangle-1-s"}, text: false}).click(function () {
    genRow("s")
  });
  $("#del_r").button({icons: {primary: "ui-icon-circle-minus"}, text: false}).click(function () {
    var cl = celda.parent().parent().parent().attr('class');
    if (cl.slice(0, 3) == 'bu_' && celda.parent().parent().children().length == 1)
      $("." + cl.slice(0, cl.indexOf(' '))).remove();
    else
      celda.parent().remove();

    noCell();
  });
  $("#del_c").button({icons: {primary: "ui-icon-circle-arrow-n"}, text: false, disabled: true}).click(function () {
    var i = celda.index() + 1;
    $(".t_banda td:nth-child(" + i + ")").remove();
    noCell();
    nCol -= 1;
  });
  $("#add_rup").button().click(function () {
    var cl = addRup(genCadRow());
    iniPropCell();
    $("#rupturas").dialog("open");
    $("." + cl + " textarea").focus();
  });
  $("#del_rup").button().click(function () {
    var cl = celda.parentsUntil('div').last().attr('class').split(/\s+/);
    $.each(cl, function (i, c) {
      if (c.slice(0, 4) == 'rup_') {
        $('.' + c).remove();
        noCell();
        return false;
      }
    });
  });
  $("#add_busu").button().click(function () {
    $("#banda_usu_name").val('');
    $("#b_busu").button("disable");
    $("#banda_usu").dialog('open');
  });

  $("#bandas").on('dblclick', 'p', function (e) {
    //if ($(this).next().children().children().length == 0) {
    if ($(this).next().find("tr").length == 0) {
      //$(this).next().children().html(genCadRow());
      $(this).next().first().html(genCadRow());
      iniPropCell();
    }
  });

  $("body").on("blur", ".i_cmp", function (e) {
    lastCmp = $(this);
  });

  $("#prop-celdas .i_cmp").blur(function (e) {
    var f = $(this);
    var v = f.val().trim();
    var p = f.attr('id');
    celda.data('prop')[p] = v;
    if (p == 'campo')
      celda.attr('title', v);
    else if (p == 'alias')
      celda.html(v == "" ? "&nbsp;" : v);
  });

  $("#tree_campos")
    .tree({
      selectable: false,
      dataUrl: '/gi/campos?node=' + modelo, onCanSelectNode: function (node) {
        return node.load_on_demand != undefined ? false : true;
      },
      onCreateLi: function (node, $li, is_selected) {
        if (node.title) $li.attr("title", node.title);
      }
    })
    .bind('tree.dblclick', function (event) {
      /*
       if (lastCmp && lastCmp.is('textarea') && lastCmp.attr("disabled") != "disabled") {
       v = lastCmp.val();
       if (lastCmp.hasClass("admite_campo")) {
       */
      if (lastCmp && lastCmp.attr("disabled") != "disabled" && lastCmp.hasClass("admite_campo")) {
        var v = lastCmp.val();
        var sel = lastCmp.caret();
        if (lastCmp.is("#asist_lim_ref")) {
          lastCmp.val('~' + fullCampo(event.node) + '~').data("cmp", event.node);
          if (event.node.pk) $("#asist_lim_pk").attr("disabled", false).prop("checked", true); else $("#asist_lim_pk").attr("disabled", true);
        } else
          lastCmp.val(v.slice(0, sel.begin) + '~' + fullCampo(event.node) + '~' + v.slice(sel.end));

        if (lastCmp.is("#prop-celdas textarea") && $("#alias").val() == "") {
          var prop = celda.data('prop');
          var a = (event.node.parent.name == undefined) ? "" : $(event.node.table.split('_')).get(-1) + '_';
          var name = a + event.node.name;
          $("#alias").val(name);
          celda.html(name);
          prop.alias = name;
          // Estilo
          var esti = event.node.estilo;
          if (event.node.type == 'decimal') esti = checkEstilo(esti, event.node.decim);
          $("#estilo").val(esti);
          prop.estilo = esti;
          // Tipo
          prop.tipo = event.node.type == 'string' ? 'string' : '';
          //if (prop.tipo == 'decimal') prop.tipo = 'float';
          $("#tipo").val(prop.tipo);
          // Celda de cabecera
          if (celda.is("#t_det td")) {
            var cc = $("#t_cab tr").last().children().eq(celda.index());
            if (cc.length > 0) {
              prop = cc.data('prop');
              if (prop.alias == undefined || prop.alias == "") {
                prop.campo = "nt('" + event.node.name + "')";
                prop.alias = name;
                prop.estilo = "tit" + (event.node.ali == "i" ? "" : "_" + event.node.ali);
                cc.attr('title', prop.campo);
                cc.html(name);
              }
            }
          }
        }
        lastCmp.focus();
      }
    }
  )
    .bind('tree.open', banLeft)
    .bind('tree.close', banLeft)
    .bind('tree.init', function (event) {
      banLeft();
      $("#bandas").css("display", "block");
      $("#prop-celdas").dialog("open").dialog("option", "position", {my: "left top", at: "right+8 top", of: "#bandas"});
    });

  /*
   $("body").on('keypress', 'textarea', function(e){
   if (e.which == 10) $(this).val($(this).val() + fullCampo());
   });
   */

  $("document").tooltip();

  $("#prop-celdas").dialog({
    title: 'Propiedades',
    width: 400,
    autoOpen: false,
    dialogClass: "no-close",
    resizable: true,
    closeOnEscape: false,
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });

  $("#rupturas").dialog({
    title: 'Rupturas',
    width: 500,
    autoOpen: false,
    resizeStop: function () {
      $(this).dialog('option', 'height', 'auto')
    }
  });

  $("body").on("change", ".anchura-columnas input, .altura-filas input", function () {
    if (this.value == "0") this.value = "";
  });

  // A partir de aquí es ya inicialización

  $(window).resize(redimWindow);
  redimWindow();

  // Inicializar componentes a partir del fichero de formato
  $.each(formato, function (k, v) {
    switch (k) {
      case 'style':
        $.each(v, addEstilo);
        break;
      case 'formulas':
        $.each(v, addFormula);
        break;
      case 'select':
        $.each(v, addSelect);
        break;
      case 'where':
        $.each(v, addWhere);
        break;
      case 'having':
        $.each(v, addHaving);
        break;
      case 'cab':
      case 'det':
      case 'pie':
        leeFormBanda('t_' + k, v);
        break;
      case 'rup': //[]
        $.each(v, function (i, rup) {
          var el = addRup('', rup.campo, rup.salto);
          leeFormBanda(el + '_h', rup.cab);
          leeFormBanda(el + '_p', rup.pie);
        });
        break;
      case 'lim':
        $.each(v, addLim);
        break;
      default:
        if (k.slice(0, 3) == 'bu_') { // Bandas de usuario
          addBanUsu(k.slice(3), '');
          leeFormBanda(k, v);
        } else { // Parámetros de configuración
          var el = $("#" + k);
          el.attr("type") == "checkbox" ? el.prop('checked', v) : el.val(v);
        }
    }
  });

  // Añadir estilos por defecto si no hay ninguno en el formato
  if ($("#t_estilos tr").length == 1) {
    addEstilo("def", "{sz: 10}");
    addEstilo("def_c", ":def, {alignment: {horizontal: :center}}");
    addEstilo("def_d", ":def, {alignment: {horizontal: :right}}");
    addEstilo("def_n", ":def, {b: true}");
    addEstilo("def_nc", ":def_c, {b: true}");
    addEstilo("def_nd", ":def_d, {b: true}");
    addEstilo("int", ":def_d, {format_code: '#,##0'}");
    addEstilo("int_n", ":def_nd, :int");
    addEstilo("dec2", ":def_d, {format_code: '#,##0.00'}");
    addEstilo("dec2_n", ":def_n, :dec2");
    addEstilo("date", ":def_c, {format_code: 'dd-mm-yyyy'}");
    addEstilo("time", ":def_c, {format_code: 'HH:MM:SS'}");
    addEstilo("datetime", ":def_c, {format_code: 'dd-mm-yyyy HH:MM:SS'}");
    addEstilo("tit", ":def, {bg_color: 'AAAAAA', fg_color: 'FFFFFF', b: true, alignment: {vertical: :center}}");
    addEstilo("tit_c", ":def_c, :tit");
    addEstilo("tit_d", ":def_d, :tit");
    addEstilo("borde", ":def, {border: {style: :thin, color: 'AAAAAA', edges: [:left, :right, :top, :bottom]}}");
    addEstilo("text", ":def, {alignment: {horizontal: :justify, vertical: :top, wrap_text: true}}");
    addEstilo("rich", ":def, {alignment: {horizontal: :left, vertical: :top, wrap_text: true}, rich: true}");
  }
  llenaEstilos();

  // Añadir columnas en cabecera y detalle si no hay columnas en el formato
  if (nCol == 0) {
    nCol = 2; // Por defecto añadir dos columnas vacías
    $("#t_cab tbody").append(genCadRow());
    $("#t_det tbody").append(genCadRow());
    iniPropCell();
  }

  // Generar los inputs de las anchuras de cada columna
  var cw = formato.col_widths ? formato.col_widths.split(",") : [];
  for (var i = 0; i < nCol; i++) {
    $("#t_width tr").append(genColWidth(cw[i] == 0 ? "" : cw[i]));
  }
  // Generar celda vacía al final de las anchuras para compensar la columna de las alturas de filas
  $("#t_width tr").append("<td class='altura-filas anchura-columnas'></td>");

  // Deshabilitar lo que proceda
  if ($("#linxpag").val() == '') {
    $("#cab_din").attr("disabled", true);
    $("#cab_din_pdf").attr("disabled", true);
  } else if (!$("#cab_din").is(":checked"))
    $("#cab_din_pdf").attr("disabled", true);

  iniGrabar();

  // Deshabilitar todos los botones de las bandas (hasta que se seleccione una celda)
  noCell();

  // Poner título
  setTitulo();
});
