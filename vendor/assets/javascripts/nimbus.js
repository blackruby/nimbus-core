jQuery.fn.entrytime = function(segundos, nil) {
  var lt = (segundos ? 8 : 5);
  var vt = "00:00:00";
  var ov;

  $(this).on("input", function(e) {
    var v = $(this).val();
    if (v == "" && nil) return;
    var cur = $(this).caret().begin;
    var vn = "";
    var l = 0;
    var ncur = cur;

    for (var i = 0, c, valido; c = v[i]; i++) {
      if (c == ':') {
        if (l+1 >= cur) {
          switch (l) {
            case 0:
            case 3:
            case 6:
              vn += vt[0]; l++;
            case 1:
            case 4:
            case 7:
              vn += vt[0]; l++;
            case 2:
            case 5:
              if (l == cur) ncur++;
              vn += ':'; l++;
              break;
          }
        } else
          ncur--;
        continue;
      } else if (c == ' ')
        c = vt[0];

      valido = ((c >= '0' && c <= '9') || c == ' ' ? true : false);
      switch (l) {
        case 0:
          if (c > '2') valido = false;
          break;
        case 1:
          if (vn[0] == '2' && c > '3') {valido = false; ncur--;}
          break;
        case 2:
        case 5:
          if (c > '5') valido = false;
          break;
      }
      if (!valido) {
        if (cur >= l) ncur--;
        continue;
      }

      if (l < cur) {
        if (l == 2 || l == 5) {
          vn += ':'; l++;
          ncur++;
        }
      } else {
        if (l == 2 || l == 5) {
          if (l == cur && (v[l+2] == ':' || !v[l+2])) {
            vn = vn.substr(0,l-1)+vt[l-1];
            vn += ':'; l++;
            ncur--;
          } else
            continue;
        }
      }

      vn += c; l++;
      if (l == lt) break;
    }
    $(this).val(vn+vt.substr(l, lt-l));
    $(this).caret(ncur);
  }).on("focus", function(e) {
    ov = $(this).val();
  }).on("blur", function(e) {
    if ($(this).val() != ov) $(this).trigger("change");
  });

  return $(this);
}

jQuery.fn.entryn = function (manti, decim, signo) {
  var lastKey, old_value;

  $(this).on("focus", function(e) {
    old_value = $(this).val();
  });

  $(this).on("blur", function(e) {
    if (old_value != $(this).val()) $(this).trigger("change");
  });

  $(this).on("keydown", function(e) {
    lastKey = e.keyCode;
    if (lastKey == 46) lastKey = 7;
    if (lastKey == 8 || lastKey == 7) {
      $(this).trigger("keypress");
      e.preventDefault();
    }
  })

  $(this).on("keypress", function(e) {
    c = e.which;
    if (c == undefined)
      c = lastKey;
    else if (c == 0)
      return;
    else {
      if (e.ctrlKey || e.altKey || e.shiftKey) {
        e.preventDefault();
        return;
      }
    }

    valac = $(this).val();
    begin = $(this).caret().begin;
    end   = $(this).caret().end;

    if (begin < end) {
      pc = valac.indexOf(',');

      if (pc >= begin && pc < end)
        valac = valac.substr(0, begin) + ',' + valac.substr(end);
      else
        valac = valac.substr(0, begin) + valac.substr(end);
      if (c == 8 || c == 7) {
        if (pc >= 0 && valac == ",") valac = "";
        if (valac == "") {
          $(this).val("");
          return;
        }
        c = 0;
      }
    }

    val = arreglaN(valac);
    pc = val.indexOf(',');
    if (pc < 0) pc = val.length;

    if (val != valac)
      cur = pc;
    else
      cur = begin;

    switch (c >= 48 && c <= 57 ? 48 : c) {
      case 44:
      case 46:
        cur = val.indexOf(',');
        if (cur < 0) cur = val.length; else cur++;
        break;

      case 45:
        if (signo) {
          if (val[0] == '-') {
            val = val.substring(1);
            cur--;
          } else {
            if (pc == 0) {
              val = "0" + val;
              cur++;
              //	pc++;
            }
            val = "-" + val;
            cur++;
          }
        }
        break;

      case 48:
        if (cur <= pc) {
          pp = 0;
          for (i = 0; i < pc; i++) {
            if (val[i] == '0' && i >= cur) pp++;
            if (val[i] >= '1' && val[i] <= '9') pp++;
          }
          if (pp < manti) {
            val = val.substr(0, cur) + String.fromCharCode(c) + val.substr(cur);
            cur++;
          }
        } else {
          if (cur < val.length) {
            val = val.substr(0, cur) + String.fromCharCode(c) + val.substr(cur+1);
            cur++;
          }
        }
        break;

      case 8:
        if (cur > 0) {
          do {
            cur--;
          } while (val[cur] == '.' || val[cur] == ',');
          if (cur <= pc)
            val = val.substr(0, cur) + val.substr(cur + 1);
          else
            val = val.substr(0, cur) + '0' + val.substr(cur + 1);
        }
        break;

      case 7:
        if (cur < val.length) {
          while (val[cur] == '.' || val[cur] == ',') cur++;
          if (cur <= pc)
            val = val.substr(0, cur) + val.substr(cur + 1);
          else {
            val = val.substr(0, cur) + '0' + val.substr(cur + 1);
            cur++;
          }
        }
        break;
    }

    formateaN($(this), val, cur);
    e.preventDefault();
  });


  function arreglaN(val) {
    pc = val.length;
    var i = 0;
    if (val[0] == '-' && signo) i++;
    while (i < pc) {
      if (val[i] == ',') {
        pc = i;
        break;
      }
      if (val[i] == '.' || (val[i] >= '0' && val[i] <= '9'))
        i++;
      else {
        val = val.substr(0, i) + val.substr(i+1);
        pc--;
      }
    }
    /** para no poder dejar en blanco con <DEL>
     if (i == 0) {
					val = '0' + val;
					i++;
					pc++;
				}
     ******/

    if (decim > 0) {
      if (pc < val.length) {
        i++;
        while (i < val.length) {
          if (val[i] >= '0' && val[i] <= '9')
            i++;
          else
            val = val.substr(0, i) + val.substr(i+1);

        }
      }
      if (pc >= val.length) val += ','

      if (pc + decim + 1 < val.length)
        val = val.substr(0, pc+decim);

      i = pc + decim - val.length;
      if (i >= 0) {
        for (; i >= 0; i--) val += '0';
      }
    } else {
      if (pc < val.length) val = val.substr(0, pc);
    }

    return(val);
  };

  formateaN = function(t, val, cur) {
    if (val == "") {
      t.val("");
      return;
    }

    pc = val.indexOf(',');
    if (pc < 0) pc = val.length;

    if (cur < 0) cur = pc;

    for (pri = 0; pri < pc; pri++) {
      if (val[pri] >= '1' && val[pri] <= '9') break;
      if (val[pri] == '0') cur--;
    }

    num = "";
    pp = 3;
    for (i = pc-1; i >= pri; i--) {
      if (val[i] < '0' || val[i] > '9') {
        if (i > 0) cur--;
        continue;
      }
      if (pp == 0) {
        num = '.' + num;
        pp = 3;
        cur++;
      }
      num = val[i] + num;
      pp--;
    }
    if (num == "") {num = "0"; cur++;}
    if (val[0] == '-') num = '-' + num;
    num = num + val.substr(pc);

    t.val(num);
    t.caret(cur);
  };

  $(this).on("paste", function(e) {
    t = $(this);

    setTimeout(function() {
      val = arreglaN(t.val());
      formateaN(t, val, -1);
    }, 100);

  });

  /*** psa ***

   $(this).on("keyup", function(e) {
				// No sé si será necesario tratar este evento para algún caso raro.
			});
   ***/

  return $(this);
};

// Función para conseguir el próximo elemento en la rueda de focos

$.fn.focusNextInputField = function() {
  return this.each(function() {
      var fields = $(this).parents('form:eq(0),body').find('button,input,textarea,select');
      var index = fields.index( this );
      if ( index > -1 && ( index + 1 ) < fields.length ) {
      fields.eq( index + 1 ).focus();
      }
      return false;
      });
};

// Funciones para el mant

// Función para invocar a una función del servidor (tipo proc_FonC)
function callFonServer(fon_s, data, fon_ret) {
    $.ajax({
        url: '/' + _controlador + '/fon_server',
        type: "POST",
        data: $.extend(true, {vista: _vista, fon: fon_s}, data),
        success: fon_ret
    })
}

function send_validar(c, v) {
  $.ajax({
    url: '/' + _controlador + '/validar',
    type: "POST",
    async: false,
    data: {vista: _vista, valor: v, campo: c.attr("id")}
  });
}

function validar(c) {
  send_validar(c, c.val());
}

function vali_auto_comp(ui, c) {
  if (ui.item == null) {
    c.val('');
    send_validar(c, '');
    c.attr("dbid", null);
  } else {
    send_validar(c, ui.item.id);
    c.attr("dbid", ui.item.id);
  }
}

function vali_check(c) {
  if (c.is(':checked'))
    send_validar(c, 'true');
  else
    send_validar(c, 'false');
}

function calc_code(v, tam, pref, rell) {
  v = v.trim();
  if (v != '') {
    s = v.split('.');
    l = s.length;
    if (l > 2) {
      return('');
    } else {
      if (l == 1) {
        //s0 = pref;
        //s1 = v;
        return(v);
      } else {
        s0 = s[0];
        s1 = s[1];
      }
      lr = s0.length + s1.length;
      t = s0;
      for (i = lr; i < tam; i++) t += rell;
      t += s1;
      return(t.substr(t.length - tam));
    }
  } else
    return('');
}

function vali_code(c, tam, pref, rell) {
  c.val(calc_code(c.val(), tam, pref, rell));
  send_validar(c, c.val());
}

function mant_grabar() {
  var res;
  if (typeof jsGrabar == "function") {
    res = jsGrabar();
    if (res == null) return;
  }
  if (typeof res != 'object') res = {};

  $.ajax({
    url: '/' + _controlador + '/grabar',
    type: "POST",
    data: $.extend(true, {vista: _vista}, res)
  });
}

function parentGridReload() {
  if (parent != self && $.isFunction(parent.grid_reload)) parent.grid_reload();
}

function parentGridHide() {
  if (parent != self && $.isFunction(parent.gridHide)) parent.gridHide();
}

function parentGridShow() {
  if (parent != self && $.isFunction(parent.gridShow)) parent.gridShow();
}

function mant_borrar() {
  $("#dialog-borrar").dialog("open");
}

function mant_borrar_ok() {
  $.ajax({
    url: '/' + _controlador + '/borrar',
    type: "POST",
    data: {vista: _vista}
  });
  if (parent != self && $.isFunction(parent.grid_reload)) parent.grid_reload();
  head = $(".cl-borrar").length == 0 ? '0' : '1';
  window.location.replace('/' + _controlador + '/0/edit?head=' + head);
}

function mant_cancelar() {
  $.ajax({
    url: '/' + _controlador + '/cancelar',
    type: "POST",
    data: {vista: _vista}
  });
}

function mant_cerrar() {
  window.open('', '_parent', '');
  window.close();
}

function bus(a) {
  if (a.keyCode == 113) // F2
    alert('BUS');
}

// Función para controlar el estado de los botones de control (Grabar, Borrar...)

function statusBotones(b) {
  var cl;

  $.each(b, function(k, v) {
    cl = $(".cl-" + k);
    if (cl.size() > 0) {
      cl.attr("disabled", !v);
    } else {
      $(".cl-" + k, parent.document).attr("disabled", !v);
    }
  });
}

// Función para traducir textos en javascript
function js_t(label) {
  switch (label) {
    case "no_session":
      return("La sesión ha expirado.\n\nSi quiere seguir usando esta pantalla\ninicie sesión en otra ventana o pestaña y regrese.");
    case "no_emp":
      return("No hay empresa seleccionada");
    case "no_eje":
      return("No hay ejercicio seleccionado");
    default:
      return(label);
  }
}

function auto_comp_error(e, ui) {
  if (typeof(ui.content) != "undefined" && ui.content[0] != undefined && ui.content[0].error == 1) alert(js_t("no_session"));
}

function auto_comp(e, s, modelo, cntr) {
  $(e).autocomplete({
    source: s,
    minLength: 1,
    autoFocus: true,
    change: function(e, ui){vali_auto_comp(ui, $(this));},
    response: function(e, ui){auto_comp_error(e, ui);}
  });

  $(e).attr('modelo', modelo).attr('controller', cntr).addClass('auto_comp');

  $(e).keydown(function(e) {bus(e);});
}

function set_auto_comp_filter(cmp, wh) {
  var s = cmp.autocomplete('option', 'source');
  var wi = s.indexOf('&wh=');
  if (wi == -1)
    cmp.autocomplete('option', 'source', s + '&wh=' + wh);
  else
    cmp.autocomplete('option', 'source', s.slice(0, wi+4) + wh);
}

function date_pick(e, opt) {
  //$(e).datepicker($.extend(true, {onClose: function(){$(this).focus();}}, opt));
    $(e).datepicker($.extend(true, {onClose: function(){$(this).focusNextInputField();}}, opt));
}

/**
function date_pick_b(e) {
  $(e).datepicker({showOn: "button", onClose: function(){$(this).focusNextInputField();}});
}
 **/

function numero(elem, manti, decim, signo) {
  $(elem).addClass('numero');
  $(elem).entryn(manti, decim, signo);
}

// Funciones para el tratamiento de los auto_comp en el grid
//
// para controlar el id del elemento seleccionado y enviarlo
// correctamente al servidor a la función vali_cell
// La variable _auto_comp_select_ contiene el valor seleccionado en el desplegable
// La variable _auto_comp_sent_ contiene el valor enviado al servidor
// Son necesarias las dos por si después de seleccionar un item se cancela la edición (ESC)
// El problema es que se dispara antes el before_edit que el after_save

var _auto_comp_select_, _auto_comp_sent_;

function auto_comp_select_grid(ui, c) {
  _auto_comp_select_ = ui.item.id;
}

function auto_comp_grid(e, s) {
  $(e).autocomplete({
    source: '/application/auto?type=grid&mod=' + s + '&eid=' + eid + '&jid=' + jid,
    minLength: 1,
    autoFocus: true,
    select: function(e, ui){auto_comp_select_grid(ui, $(this));},
    response: function(e, ui){auto_comp_error(e, ui);}
  });
}

function jqg_before_processing(data, status, xhr) {
  if (typeof data.error != "undefined") alert(js_t(data.error));
}

function jqg_before_edit_cell(ri, cn) {
  _auto_comp_select_='';
}

function jqg_before_submit_cell(ri, cn) {
  if (cn.match('_id$')) {
    _auto_comp_sent_= _auto_comp_select_;
    return({sel: _auto_comp_select_});
  }
}

function jqg_after_submit_cell(t,ri,cn) {
  if (t.responseText == '')
    return([true, '']);
  else
    return([false, t.responseText]);
}

function jqg_after_save_cell(ri,cn) {
  if (cn.match('_id$') && _auto_comp_sent_ == '') {
    $(this).jqGrid('setCell', ri, cn, '', '', '', true);
  }
}

// Funciones para el tratamiento de máscaras y codes en la entrada de celdas

function jqg_custom_element (value, options) {
  el = document.createElement("input");
  $(el).attr('maxlength', options.maxlength);
  if (options.mask) $(el).mask(options.mask, {placeholder: ' '});
  if (options.may) $(el).css('text-transform', 'uppercase');
  if (options.code) {
    $(el).attr('prefijo', options.code.prefijo);
    $(el).attr('relleno', options.code.relleno);
  }
  el.value = value;
  return el;
}

function jqg_custom_value(e) {
  if ($(e).attr('prefijo') || $(e).attr('relleno'))
    return(calc_code(e.val(), $(e).attr('maxlength'), $(e).attr('prefijo'), $(e).attr('relleno')));
  else
    return(e.val());
}

// FUNCIONES PARA EL TRATAMIENTO DE MÁSCARAS

// Añadir nuevas definiciones para las máscaras
$.mask.definitions['&'] = '[.0-9]';

/*
function mask(h) {
  $(h.elem).mask(h.mask, {placeholder: ' '});
  if (h.may) $(h.elem).css('text-transform', 'uppercase');
}
*/

// Elegido un carácter UTF8 para formatear el aspecto de los booleanos (checks) en el grid
function format_check(v){
  return v == 'true' || v == true ? '\u2714' : '';
}

function unformat_check(v){
  return v == '\u2714' ? 'true' : '';
}

// Deshabilitar el menú contextual en los iframes (Solo habilitado en primer nivel)
/*
if (self != top)
  $(document).bind("contextmenu", function(e) {
    return false;
  });
*/

function autoCompBuscar() {
  bus_input_selected = $("#_auto_comp_button_").parent().find("input");
  callFonServer("bus_call", {id: bus_input_selected.attr("id")});
  /*
  var inp = $("#_auto_comp_button_").parent().find("input");
  var w = window.open('/bus?mod=' + inp.attr("modelo") + '&eid=' + eid + '&jid=' + jid, "_blank", "width=700, height=500");
  w._autoCompField = inp
  */
}

function autoCompIrAFicha() {
  /*
  var inp = $("#_auto_comp_button_").parent().find("input");
  var si = inp.autocomplete("instance").selectedItem;
  if (si == undefined) return;
  window.open('/' + inp.attr("controller") + '/' + si.id + '/edit', '_blank', '');
  */
  var inp = $("#_auto_comp_button_").parent().find("input");
  var dbid = inp.attr("dbid");
  if (dbid == undefined) return;
  window.open('/' + inp.attr("controller") + '/' + dbid + '/edit', '_blank', '');
}

function autoCompNuevaFicha() {
  window.open('/' +  $("#_auto_comp_button_").parent().find("input").attr("controller") + '/new', '_blank', '');
}

function ponBusy() {
  $("body").append('<div class="mdl-spinner mdl-js-spinner is-active" style="z-index:2000; position: absolute; left: 50%; top: 50%;"></div>');
  componentHandler.upgradeDom();
  //$(".mdl-spinner").addClass("is-active");
}

function quitaBusy() {
  //$(".mdl-spinner").removeClass("is-active");
  $(".mdl-spinner").remove();
}

function _addDataGridLocal(jcmp, data) {
  var cols = jcmp.jqGrid('getGridParam', 'colModel');
  var ms = jcmp.jqGrid('getGridParam', 'multiselect');

  var h = {}, i, j, c, d;
  for(i = 0; d = data[i]; i++) {
    if (ms)
      for(j = 1; c = cols[j]; j++) h[c.name] = d[j];
    else
      for(j = 0; c = cols[j]; j++) h[c.name] = d[j+1];

    jcmp.jqGrid('addRowData', d[0], h);
  }
}

function addDataGridLocal(cmp, data) {
  _addDataGridLocal($("#g_" + cmp) , data);
}

function delDataGridLocal(cmp, id) {
  $("#g_" + cmp).jqGrid('delRowData', id);
}

function creaGridLocal(opts, data) {
  var cmp = opts.cmp;
  var ele = $("#" + cmp);
  var grid = opts.grid;
  if (grid == undefined) grid = {};
  ele.html("").append('<table id="g_' + cmp + '"></table>');
  var g = $("#g_" + cmp);
  g.jqGrid($.extend({
    datatype: "local",
    colModel: opts.cols,
    gridview: true,
    height: 150,
    ignoreCase: true,
    //multiselect: true,
    //caption: "Manipulating Array Data",
    deselectAfterSort: false,
    onSelectRow: function(r, s){callFonServer("grid_local_select", {cmp: cmp, row: r, sel: s, multi: grid.multiselect})},
    onSelectAll: function(r, s){callFonServer("grid_local_select", {cmp: cmp, row: (s ? r : null), sel: s, multi: grid.multiselect})},
  }, grid));

  if (opts.search) g.jqGrid('filterToolbar',{searchOperators : true});

  _addDataGridLocal(g, data);
}

$(window).load(function() {
  $("body").on("focus", ".nim-input", function (e) {
    $("#_auto_comp_button_").remove();
  });
  $("body").on("focus", ".auto_comp", function (e) {
    $(this).parent().append(
      '<button id="_auto_comp_button_" class="mdl-button mdl-js-button mdl-button--icon" style="position: absolute;top: -4px;right: -4px" tabindex=-1>'+
      '<i class="material-icons" style="background-color: #eeeeee">more_vert</i>'+
      '</button>' +
      '<ul class="mdl-menu mdl-menu--bottom-right mdl-js-menu mdl-js-ripple-effect" for="_auto_comp_button_" style="z-index: 5000">'+
      '<li class="mdl-menu__item" onclick="autoCompBuscar()">Buscar</li>'+
      '<li class="mdl-menu__item" onClick="autoCompIrAFicha()">Ir a</li>'+
      '<li class="mdl-menu__item" onClick="autoCompNuevaFicha()">Nueva alta</li>'+
      '</ul>'
    );
    componentHandler.upgradeDom();
  });
});
