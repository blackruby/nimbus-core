// Colores globales
color_1 = "#673AB7";
color_1_2 = "#D1C4E9";
color_1_3 = "#ede7f6";
color_1_d = "#512DA8";
color_2 = "#FF4081";
color_2_2 = "#F8BBD0";

function checkDate(val) {
  if (val == '') return('');

  var dia = parseInt(val.substr(0, 2));
  if (isNaN(dia)) return(null);
  var mes = parseInt(val.substr(3, 2));
  if (isNaN(mes)) return(null);
  var ano = parseInt(val.substr(6, 4));
  if (isNaN(ano)) return(null);

  if (ano > 99 && ano < 1000) return(null);
  if (ano < 100) ano += 2000;
  if (ano < 1900 || ano > 2100) return(null); // Esto es discutible. Es sólo por acotar un rango razonable de años válidos

  if (mes < 1 || mes > 12) return(null);

  if (dia < 1 || dia > 31) return(null);

  if (dia == 31 && [4,6,9,11].indexOf(mes) >= 0) return(null);

  if (mes == 2 && dia > 28 + (ano % 4 == 0 ? 1 : 0)) return(null); // Estoy considerando años bisiestos a los mútiplos de cuatro. Estoy ignorando el caso múltiplo de 100

  return((dia < 10 ? '0' : '') + dia + '-' + (mes < 10 ? 0 : '') + mes + '-' + ano);
}

jQuery.fn.entrydate = function() {
  var ov, lastv, month, year;

  $(this).attr("blurEnEspera", 0);

  function calculaKey(keyCode) {
    if (keyCode >= 48 && keyCode <= 90) return(String.fromCharCode(keyCode));
    if (keyCode >= 96 && keyCode <= 105) return(String.fromCharCode(keyCode - 48)); // Números del teclado numérico
    if (keyCode == 107 || keyCode == 187) return("+");
    if (keyCode == 109 || keyCode == 189) return("-");

    switch(keyCode) {
      case 8: return('Backspace');
      case 9: return('Tab');
      case 13: return('Enter');
      case 32: return(' ');
      case 37: return('ArrowLeft');
      case 38: return('ArrowUp');
      case 39: return('ArrowRight');
      case 40: return('ArrowDown');
      case 46: return('Delete');
    }
  }

  $(this).on("focus", function(e) {
    var hoy = new Date;
    month = hoy.getMonth() + 1;
    //year = hoy.getYear() + 1900;
    year = hoy.getFullYear();

    ov = lastv = $(this).val();
    $(this).data('ov', ov).select();

  }).on("input", function(e) {
    var v = checkDate($(this).val());
    $(this).val(v ? v : lastv);

  }).on("keydown", function(e) {
    if (nimRO) {
      if (e.keyCode == 9) return; else return false;
    }
    //var key = e.key;  // Esto sería válido para versiones modernas de javascript
    var key = calculaKey(e.keyCode);  // Apaño para versiones de javascript que no rellenan 'key'
    var cur = $(this).caret().begin;
    var curf = $(this).caret().end;
    var val = $(this).val();

    // Si está  el campo entero seleccionado y se pulsa alguna de las teclas de borrado... Vaciar el campo.
    if (cur == 0 && curf == val.length && (key == 'Delete' || key == 'Backspace')) {
      e.preventDefault();
      $(this).val('');
      return;
    }

    switch(key) {
      case 'Enter':
        // Selección de fecha desde el día activo en el calendario
        if ($("#ui-datepicker-div").css("display") != "none") {
          e.stopImmediatePropagation();
          var cel = $('.ui-datepicker-days-cell-over');
          if (cel) {
            var d = parseInt(cel.text());
            var m = cel.data("month") + 1;
            var y = cel.data("year");
            if (!isNaN(d) && !isNaN(m) && !isNaN(y)) $(this).val((d < 10 ? '0' : '') + d + '-' + (m < 10 ? '0' : '') + m + '-' + y).trigger("blur").focusNextInputField();
          }
        }
        return;
      case 'Delete':
        e.preventDefault();
        return;
      case 'Backspace':
      case 'ArrowLeft':
        if ((e.ctrlKey || e.shiftKey) && key == 'ArrowLeft') return;  // Esto sería una selección de texto... Dejar la acción por defecto.
        e.preventDefault();
        $(this).caret(cur - (cur == 3 || cur == 6 ? 2 : 1));
        return;
      case 'ArrowRight':
      case ' ':
        if ((e.ctrlKey || e.shiftKey) && key == 'ArrowRight') return;  // Esto sería una selección de texto... Dejar la acción por defecto.
        e.preventDefault();
        $(this).caret(cur + (cur == 1 || cur == 4 ? 2 : 1));
        return;
      case 'ArrowUp':
      case 'ArrowDown':
      case '+':
      case '-':
        if (!e.ctrlKey && !e.shiftKey && !e.altKey) {
          e.preventDefault();
          $(this).datepicker(key == "ArrowUp" || key == "-" ? "hide": "show");
        }
        return;
    }

    // Dejar en paz las teclas especiales y ctrl-c y ctrl-v
    if (e.keyCode < 48 || (key == 'v' || key == 'V' || key == 'c' || key == 'C') && e.ctrlKey) return;

    var valido = true;

    // Controlar que la tecla pulsada es numérica y que no se ha sobrepasado la longitud máxima
    if (key < '0' || key > '9' || key == undefined || cur > 9) {
      e.preventDefault();
      return;
    }

    var curadd = 1;

    switch (cur) {
      case 0:
        if (key > '3') valido = false;
        break;
      case 1:
        if (val[0] == '3' && key > '1') valido = false; else curadd++;
        break;
      case 3:
        if (key > '1') valido = false;
        break;
      case 4:
        if (val[3] == '1' && key > '2') valido = false; else curadd++;
        break;
      case 6:
        val = val.substr(0, 6);
        $(this).val(val);
    }

    e.preventDefault();

    if (valido) {
      val = val.substr(0, cur) + key + val.substr(cur + 1);
      if (val.length == 2) {
        var m = month;

        if (month == 2 && val > 28 + (year % 4 == 0 ? 1 : 0))
          m++;
        else if (val == 31 && [4,6,9,11].indexOf(month) >= 0)
          m++;

        val = val + '-' + (m < 10 ? '0' : '') + m + '-' + year;
      }

      $(this).val(val);
      lastv = val;

      $(this).caret(cur + curadd);
    }

  }).on("blur", function(e) {
    var el = $(this);
    var v = el.val();

    el.attr("blurEnEspera", parseInt(el.attr("blurEnEspera")) + 1);

    setTimeout(function() {
      el.attr("blurEnEspera", parseInt(el.attr("blurEnEspera")) - 1);
      if (el.attr("blurEnEspera") == 0 && !el.is(":focus")) el.datepicker("hide");
    }, 200);

    v = checkDate(v);

    if (v != null) {
      if (v != ov) el.val(v).trigger("change");
    } else {
      el.addClass('nim-color-2');

      $('<div>Fecha Errónea. Se repondrá el valor anterior.</div>').dialog({
        resizable: false, modal: true, width: "auto", title: "Error",
        close: function () {
          $(this).remove();
          el.val(ov).removeClass('nim-color-2').focus().caret(0);
        },
        buttons: {"Aceptar": function () {$(this).dialog("close");}}
      });
    }
  });

  return $(this);
};

jQuery.fn.entrytime = function(segundos, nil) {
  var lt = (segundos ? 8 : 5);
  var vt = "00:00:00";
  var ov;

  $(this).data("seg", segundos).on("input", function(e) {
    var v = $(this).val();
    if (v == "" && nil) return;
    var cur = $(this).caret().begin;
    var vn = "";
    var l = 0;
    var ncur = cur;

    for (var i = 0, c, valido; c = v[i]; i++) {
      if (vn.length == lt) break;
      if (c == ':') {
        if (l+1 >= cur) {
          switch (l) {
            case 0:
            case 3:
            case 6:
              vn += vt[0]; l++;
              break;
            case 1:
            case 4:
            case 7:
              vn += vt[0]; l++;
              break;
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
    ov = $(this).select().val();
  }).on("blur", function(e) {
    if ($(this).val() != ov) $(this).trigger("change");
  });

  return $(this);
};

// entryn y funciones asociadas

function entrynArregla(val, decim, signo) {
  var pc = val.length;
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

function entrynFormatea(t, val, cur) {
  if (val == "") {
    t.val("");
    return;
  }

  var pc = val.indexOf(',');
  if (pc < 0) pc = val.length;

  if (cur < 0) cur = pc;

  for (var pri = 0; pri < pc; pri++) {
    if (val[pri] >= '1' && val[pri] <= '9') break;
    if (val[pri] == '0') cur--;
  }

  var num = "";
  var pp = 3;
  for (var i = pc-1; i >= pri; i--) {
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

function entryn_focus(e) {
  var th = $(this);
  var val = th.select().val();
  th.data('entryn_old_value', val);
};

function entryn_blur(e) {
  var th = $(this);
  if (!e.data.nil && th.val() == "") th.val("0" + (e.data.decim == 0 ? "" : "," + "0".repeat(e.data.decim)));
  if (th.data('entryn_old_value') != th.val()) th.trigger("change");
};

function entryn_keydown(e) {
  var th = $(this);
  var lastKey = e.keyCode;
  th.data('lastKey', lastKey);
  if (lastKey == 46) lastKey = 7;
  if (lastKey == 8 || lastKey == 7) {
    th.trigger("keypress");
    e.preventDefault();
  }
};

function entryn_keypress(e) {
  var th = $(this);
  var lastKey = th.data('lastKey');

  var c = e.which;
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

  var manti = e.data.manti;
  var decim = e.data.decim;
  var signo = e.data.signo;

  var valac = th.val();
  var begin = th.caret().begin;
  var end   = th.caret().end;

  if (begin < end) {
    var pc = valac.indexOf(',');

    if (pc >= begin && pc < end)
      valac = valac.substr(0, begin) + ',' + valac.substr(end);
    else
      valac = valac.substr(0, begin) + valac.substr(end);
    if (c == 8 || c == 7) {
      if (pc >= 0 && valac == ",") valac = "";
      if (valac == "") {
        th.val("");
        return;
      }
      c = 0;
    }
  }

  var val = entrynArregla(valac, decim, signo);
  var pc = val.indexOf(',');
  if (pc < 0) pc = val.length;

  if (val != valac)
    var cur = pc;
  else
    var cur = begin;

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
        var pp = 0;
        for (var i = 0; i < pc; i++) {
          //if (val[i] == '0' && i >= cur) pp++;
          //if (val[i] >= '1' && val[i] <= '9') pp++;
          if (val[i] >= '0' && val[i] <= '9') pp++;
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

  entrynFormatea(th, val, cur);
  e.preventDefault();
};

function entryn_paste(e) {
  var th = $(this);

  setTimeout(function() {
    var val = entrynArregla(th.val(), e.data.decim, e.data.signo);
    entrynFormatea(th, val, -1);
  }, 100);
};

jQuery.fn.entryn = function (manti, decim, signo, nil) {
  var th = $(this);

  th.off("focus", entryn_focus).on("focus", entryn_focus);
  th.off("blur", entryn_blur).on("blur", undefined, {decim: decim, nil: nil}, entryn_blur);
  th.off("keydown", entryn_keydown).on("keydown", entryn_keydown);
  th.off("keypress", entryn_keypress).on("keypress", undefined, {manti: manti, decim: decim, signo: signo}, entryn_keypress);
  th.off("paste", entryn_paste).on("paste", undefined, {manti: manti, decim: decim, signo: signo}, entryn_paste);

  return th;
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

// Función para mostrar un PopUp con el texto pasado como argumento
function nimPopup(texto, pos) {
  $(".nim-popup").remove();
  $("body").append('<div class="nim-popup">' + texto + '</div>');
  var np = $(".nim-popup");
  np.contextmenu(function(e) {e.preventDefault();});
  np.position(pos ? pos : {my: "bottom-5", of: window.event});
  np.fadeIn(1400, function() {np.fadeOut(1400);});
}

// Funciones para el mant

// Función que sustituye al ajax de jQuery
// Su objetivo es sincronizar todas la llamadas ajax en Nimbus
// Y que todas sean secuenciales (que no empiece una hasta que
// la otra haya acabado).
// Para ello se usa una promesa (Promise) que va encadenando
// la ejecución de las distintas llamadas a _nimAjax
nimPromise = null;

function _nimAjax(obj) {
  var nimPromiseOld = nimPromise;
  var bfsn = obj.beforeSend;
  var cmpl = obj.complete;
  nimPromise = new Promise(async function(res) {
    await nimPromiseOld;
    $.ajax($.extend(true, obj, {
      beforeSend: function(xhr, str) {
        if (typeof bfsn == "function" && !bfsn(xhr, str)) {
          res();
          return false;
        }
        return true;
      },
      complete: function(xhr, str) {
        if (typeof cmpl == "function") cmpl(xhr, str);
        res();
      }
    }));
  });
}

// Función para invocar a una función del servidor (tipo proc_FonC)
function callFonServer(fon_s, data, fon_ret, sync) {
  if (checkNimServerStop()) return;

  var params = {fon: fon_s};
  if (typeof(_vista) != "undefined") params.vista = _vista;

  //$.ajax({
  _nimAjax({
    url: '/' + _controlador + '/fon_server',
    type: "POST",
    async: !sync,
    data: $.extend(true, params, data),
    success: fon_ret
  })
}

// Función más completa para invocar un método del server
// Una forma de mostrar feedback al usuario de que se está procesando sería:
// ponBusy(); nimAjax('metodo', {}, {timeout: 5000, success: function(){// Mi código}, complete: quitaBusy});
function nimAjax(fon_s, data, ajax) {
  if (checkNimServerStop()) return;

  var params = {fon: fon_s};
  if (typeof(_vista) != "undefined") params.vista = _vista;

  //$.ajax($.extend(
  _nimAjax($.extend(
    {
      url: '/' + _controlador + '/fon_server',
      type: "POST",
      data: $.extend(params, data)
    }, ajax
  ));
}

function send_validar(c, v, data) {
  if (nimGrabacionEnCurso || checkNimServerStop()) return;

  var nimValidarEnCurso = true;
  setTimeout(function() {if (nimValidarEnCurso) c.addClass("nim-bg-blink");}, 1000);

  _nimAjax({
    url: '/' + _controlador + '/validar',
    type: "POST",
    timeout: 20000,
    data: $.extend(true, {vista: _vista, valor: v, campo: c.attr("id")}, data),
    complete: function() {
      nimValidarEnCurso = false;
      c.removeClass("nim-bg-blink");
    },
    error: function(xhr, err) {
      if (err == "timeout")
        var txt = "El servidor tarda mucho en responder.\nEl cambio de valor no tendrá efecto.";
      else
        var txt = "Se ha producido un error.";

      alert(txt + "\nEs posible que los datos no estén sincronizados.\nSe recomienda recargar la ficha.");
    }
  });
}

function validar(c) {
  send_validar(c, c.val());
}

function vali_auto_comp(ui, c) {
  if (ui.item == null) {
    //c.val('');
    //send_validar(c, '');
    //c.attr("dbid", null);
    if (c.val() == '') {
      send_validar(c, '');
      c.attr("dbid", null);
    } else
      send_validar(c, c.val(), {src: c.autocomplete('option', 'source')});
  } else {
    send_validar(c, ui.item.id);
    c.attr("dbid", ui.item.id);
  }
}

// Chequea o deschequea una checkbox de mdl
function mdlCheck(cmps, valor) {
  var cmp = $("#" + cmps);
  valor ? cmp.parent().addClass("is-checked") : cmp.parent().removeClass("is-checked");
  cmp.prop("checked", valor);
}

// Habilita o deshabilita una checkbox de mdl
function mdlCheckStatus(cmps, valor) {
  var cmp = $("#" + cmps);
  valor == 'd' ? cmp.parent().addClass("is-disabled") : cmp.parent().removeClass("is-disabled");
  cmp.prop("disabled", (valor == 'd'));
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
    var s = v.split('.');
    var l = s.length;
    if (l > 2) {
      return('');
    } else {
      if (l == 1) {
        var s0 = pref;
        var s1 = v;
        //return(v);
      } else {
        var s0 = s[0];
        var s1 = s[1];
      }
      var lr = s0.length + s1.length;
      var t = s0;
      for (var i = lr; i < tam; i++) t += rell;
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

nimGrabacionEnCurso = false;
function mant_grabar(nueva) {
  if (nimGrabacionEnCurso || checkNimServerStop()) return;

  var context = $(".cl-grabar").length > 0 ? document : parent.document;
  var bg = $("button.cl-grabar", context);
  if (bg.length == 0 || bg.attr('disabled') == 'disabled') return;

  nimGrabacionEnCurso = true;

  // Para forzar la salida de edición de cualquier celda en cualquier grid editable que haya
  $(".ui-jqgrid-btable").jqGrid('editCell', 0, 0, false);

  var res;

  if (typeof jsGrabar == "function") {
    res = jsGrabar();
    if (res == null) {
      nimGrabacionEnCurso = false;
      return;
    }
  }
  if (typeof res != 'object') res = {};

  if (nueva) res = $.extend(true, {_new: true}, res);

  // Incluir los campos "rich"
  var rich = {};
  for(var e of $(".nq-contenedor")) {
    rich[e.id] = nimQuillVal(e.id);
  }
  if (Object.keys(rich).length > 0) res = $.extend(true, {rich: rich}, res);

  $("body", context).append('<div class="nim-body-modal"></div>');
  _nimAjax({
    url: '/' + _controlador + '/grabar',
    type: "POST",
    data: $.extend(true, {vista: _vista}, res),
    beforeSend: function() {
      var stop = false;
      for (var d of $(".nim-dialogo")) {
        if ($(d).dialog("isOpen")) {
          stop = true;
          break;
        }
      };
      if (stop) {
        $(".nim-body-modal", context).remove();
        nimGrabacionEnCurso = false;
        setTimeout(alert, 0, "\nGRABACIÓN CANCELADA.\n\nAtienda primero los diálogos en curso.");
        return false;
      }
      return true;
    },
    complete: function() {
      $(".nim-body-modal", context).remove();
      nimGrabacionEnCurso = false;
    }
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
  if (nimGrabacionEnCurso || checkNimServerStop()) return;

  $("#dialog-borrar").dialog("open");
}

function mant_borrar_ok() {
  if (nimGrabacionEnCurso || checkNimServerStop()) return;

  _nimAjax({
    url: '/' + _controlador + '/borrar',
    type: "POST",
    data: {vista: _vista}
  });
  /*
  if (parent != self && $.isFunction(parent.grid_reload)) parent.grid_reload();
  head = $(".cl-borrar").length == 0 ? '0' : '1';
  window.location.replace('/' + _controlador + '/0/edit?head=' + head);
  */
  if (parent != self && $.isFunction(parent.gridShow) && parent.varView.grid.gcols[0] == 0) parent.gridShow();
}

function bus(a) {
  if (a.keyCode == 113) // F2
    alert('BUS');
}

// Función para controlar el estado de los botones de control (Grabar, Borrar...)

function statusBotones(b) {
  var context;

  $.each(b, function(k, v) {
    context = $(".cl-" + k).length > 0 ? document : parent.document;
    if (v == null)
      $(".cl-" + k, context).remove();
      //$(".cl-" + k, context).css("display", "none");
    else
      $(".cl-" + k, context).attr("disabled", !v);
      //$(".cl-" + k, context).css("display", "inline-block").attr("disabled", !v);
  });
}

// Función para traducir textos en javascript
function js_t(label) {
  switch (label) {
    case "no_vista":
      return("Esta página ya no es válida.\n\nVuelva a recargarla.");
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
  //if (typeof(ui.content) != "undefined" && ui.content[0] != undefined && ui.content[0].error == 1) alert(js_t("no_session"));
  if (typeof(ui.content) != "undefined" && ui.content[0] != undefined && ui.content[0].error != undefined) alert(js_t(ui.content[0].error));
}

function auto_comp(e, s, modelo, cntr) {
  var el = $(e);
  var dlg = el.attr('dialogo');
  if (dlg) dlg = $('#' + dlg);

  el.autocomplete({
    source: s,
    minLength: 1,
    autoFocus: true,
    zIndex: 1500,
    change: function(e, ui){vali_auto_comp(ui, $(this));},
    response: function(e, ui){auto_comp_error(e, ui);},
    open: function () {
      if (dlg) el.autocomplete('widget').zIndex(dlg.zIndex()+1);
    }
  });

  el.attr('modelo', modelo).attr('controller', cntr).attr('autocomplete', 'off').addClass('auto_comp');

  if (dlg) el.autocomplete('widget').insertAfter(dlg.parent());

  el.keydown(function(e) {bus(e);});
}

function date_pick(e, opt) {
  $(e).entrydate().datepicker($.extend(true, {showOn: 'none', onSelect: function(){
    if ($(this).data('ov') != $(this).val()) $(this).trigger("change");
    $(this).focusNextInputField();
  }}, opt));
}

function dateToNumber(d) {
  return parseInt(d.slice(6) + d.slice(3,5) + d.slice(0,2));
}

function sortDate(a, b, d) {
  var a = dateToNumber(a)*d;
  var b = dateToNumber(b)*d;
  if (a > b) return 1;
  if (a < b) return -1;
  return 0;
}

function numero(elem, manti, decim, signo, nil) {
  $(elem).addClass('numero');
  $(elem).entryn(manti, decim, signo, nil);
}

function unformatNumero(num) {
  return num.replace(/\./g, '').replace(/,/, '.');
}

function sortNumero(a, b, d) {
  var a = unformatNumero(a)*d;
  var b = unformatNumero(b)*d;
  if (a > b) return 1;
  if (a < b) return -1;
  return 0;
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
$.mask.placeholder = ' ';

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

function setAutoCompEmpeje(cmp, id, empeje) {
  var el = $("#" + cmp);
  url = new URL("http:/" + el.autocomplete("option", "source"));
  url.searchParams.set((empeje == "j" ? "jid" : "eid"), id);
  el.autocomplete("option", "source", url.href.slice(6));
}

function autoCompBuscar() {
  bus_input_selected = $("#_auto_comp_button_").parent().find("input");
  bus_input_selected.focus();
  var cmp = bus_input_selected.attr('cmp');
  if (cmp) {
    var rowid = $("#g_" + cmp).jqGrid('getGridParam', 'selrow');
    var col = bus_input_selected.attr("col");
    callFonServer("bus_call", {cmp: cmp, col: col, id: cmp + '_' + rowid + '_' + col});
  } else
    callFonServer("bus_call", {id: bus_input_selected.attr("id"), cmpid: bus_input_selected.attr("cmpid")});
}

function autoCompIrAFicha() {
  if (checkNimServerStop()) return;

  var inp = $("#_auto_comp_button_").parent().find("input");
  var dbid = inp.attr("dbid");
  if (dbid == undefined || dbid == '') return;
  var go = inp.attr("go");
  if (go == undefined) {
    window.open('/' + inp.attr("controller") + '?hidegrid=1&id_edit=' + dbid + (typeof(eid) != "undefined" && eid != "" ? "&eid=" + eid : "") + (typeof(jid) != "undefined" && jid != "" ? "&jid=" + jid : ""), '_blank', '');
  } else
    callFonServer(go);
}

function autoCompNuevaFicha() {
  if (checkNimServerStop()) return;

  var inp = $("#_auto_comp_button_").parent().find("input");
  var nw = inp.attr("new");
  if (nw == undefined) {
    window.open('/' + inp.attr("controller") + '?hidegrid=1&id_edit=-1' + (typeof(eid) != "undefined" && eid != "" ? "&eid=" + eid : "") + (typeof(jid) != "undefined" && jid != "" ? "&jid=" + jid : ""), '_blank', '');
  } else
    callFonServer(nw);
}

// Los posibles contextos son 0 para el documento actual y !=0 para el padre (preferentemente 1, por si se añaden más valores)
function ponBusy(context = 0) {
  $("body", context == 0 ? document : parent.document).append("<div class='nim-body-modal nim-busy'></div><div class='mdl-spinner mdl-js-spinner nim-busy is-active' style='z-index:100001; position: absolute; left: 50%; top: 50%;'></div>");
  context == 0 ? componentHandler.upgradeDom() : parent.componentHandler.upgradeDom();
}

function quitaBusy(context = 0) {
  $(".nim-busy", context == 0 ? document : parent.document).remove();
}

function creaMdlButton(id, siz, mb, fsiz, icon, title) {
  if (title == undefined) title = '';
  return(
    '<button id="' + id + '" ' +
    'class="mdl-button mdl-js-button mdl-button--fab mdl-button--mini-fab mdl-js-ripple-effect mdl-button--colored" ' +
    'style="margin-bottom: ' + mb + 'px;height: ' + siz + 'px;width: ' + siz + 'px;min-width: ' + siz + 'px;" ' +
    'title="' + title + '" ' +
    '>' +
    '<i class="material-icons" style="font-size: ' + fsiz + 'px">' + icon + '</i>' +
    '</button>'
  )
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

function setDataGridLocal(cmp, data) {
  var c;
  var edit = false;
  var g = $("#g_" + cmp);

  // Comprobamos si hay alguna celda en edición (lo sabemos porque existe un elemento input)
  // En ese caso hay que sacarla de edición por si se le asigna un nuevo valor.
  // Cambiar el valor de una celda en edición no le sienta nada bien a jqGrid.
  var inp = g.find("input, select");

  if (inp.length > 0) {
    // Calculamos la fila y columna de la celda editada y la sacamos de edición
    var fil = parseInt(inp.attr("id"));
    var col = inp.parent().index();
    g.jqGrid('editCell', fil, col, false);
    edit = true;
  }

  // Bucle de asignación de valores a las celdas
  for (var i = 0; c=data[i]; i++)
    g.jqGrid("setCell", c[0], c[1], c[2], false, false, true);

  if (edit) {
    // Volvemos a editar la celda que estaba en edición
    g.jqGrid('editCell', fil, col, true);
  }
}

function setSelectionGridLocal(cmp, data) {
  var g = $("#g_" + cmp);
  g.jqGrid("resetSelection");
  $.each(nim_subgrid_data[cmp], function(id) {
    $("#g_" + cmp + "_" + id + "_t").jqGrid("resetSelection")
    for (var d of nim_subgrid_data[cmp][id]) d._sel = false;
  });
  if (data) {
    if (!$.isArray(data)) data = [data];
    //for (var i in data) g.jqGrid("setSelection", data[i], false);
    for (var d of data) {
      if ($.isArray(d)) {
        var sg = $("#g_" + cmp + "_" + d[0] + "_t");
        sg.jqGrid("setSelection", d[1], false);
        for (var r of nim_subgrid_data[cmp][d[0]]) if (r.id == d[1]) r._sel = true;
      } else
        g.jqGrid("setSelection", d, false);
    }
  }
}

// Variable global para almacenar los datos de los subgrids
nim_subgrid_data = {};

function creaGridLocal(opts, data) {
  var cmp = opts.cmp;
  //$("#" + cmp).html("").append('<table id="g_' + cmp + '"></table>');
  $("#g_" + cmp).jqGrid('GridDestroy');
  $("#" + cmp).append('<table id="g_' + cmp + '"></table>');
  var g = $("#g_" + cmp);


  function onSelectCellGridLocal(r, c, v, ir, ic) {
    // Consideramos el <ENTER> como si fuera un evento "click"
    var ev = event == undefined ? "prog" : (event.keyCode == 13 || event.keyCode == 10 ? "click" : event.type);
    // Rechazar el caso de este evento (se produce dos veces al editar una celda pasando con tabulador de otra)
    if (ev == "readystatechange") return;

    var sc = g.jqGrid("getGridParam", "colModel")[ic].sel;
    if (
      opts.sel == 'row' && g.attr("last_selected_row") != r ||
      opts.sel == 'cel' && (sc == undefined || ev == sc) ||
      opts.sel == 'celx' && (sc == true || ev == sc)
      ) {
      nimAjax("grid_local_ed_select", {cmp: cmp, row: r, col: c, event: ev});
    }

    g.attr("last_selected_row", r);
  }



  var grid = opts.grid;
  if (grid == undefined) grid = {};

  var caption = grid.caption;
  if (caption) delete grid.caption; else caption = '';

  var grid_a;
  switch(opts.modo) {
    case 'ed':
      grid_a = {
        cellEdit: !nimRO,
        afterSaveCell: function(row, col, val, rowid, colid) {
          if (col.match('_id$')) {
            if (g.attr("last_autocomp_id") == "") {
              g.jqGrid("setCell", row, col, "", "", "", true);
            }
            val = g.attr("last_autocomp_id");
            g.jqGrid("getLocalRow", row)['_'+col] = val;
          }
          var nimValidarEnCurso = true;
          var celda = $(this).find(`tr:eq(${rowid})`).find(`td:eq(${colid})`);
          setTimeout(function() {if (nimValidarEnCurso) celda.addClass("nim-bg-blink");}, 1000);
          //callFonServer("validar_local_cell", {cmp: cmp, row: row, col: col, val: val}, null);
          nimAjax(
            "validar_local_cell",
            {cmp: cmp, row: row, col: col, val: val},
            {complete: function() {
              nimValidarEnCurso = false;
              celda.removeClass("nim-bg-blink");
            }});
        },
        onSelectCell: onSelectCellGridLocal,
        beforeEditCell: function(r, c, v, ir, ic) {
          g.attr("last_autocomp_id", "");
          onSelectCellGridLocal(r, c, v, ir, ic);
        }
      };
      break;
    default :
      grid_a = {
        deselectAfterSort: false,
        onSelectRow: function(r, s){callFonServer("grid_local_select", {cmp: cmp, row: r, sel: s})},
        onSelectAll: function(r, s){callFonServer("grid_local_select", {cmp: cmp, row: (s ? r : null), sel: s})}
      };
      // Subgrid
      if (opts.subgrid) {
        nim_subgrid_data[cmp] = opts.subgrid.data;
        grid_a.subGrid = true;
        grid_a.subGridRowExpanded = function (div, rowId) {
          if (opts.subgrid.data[rowId] == undefined) return;

          var subgridTableId = div + "_t";
          $("#" + div).html("<table id='" + subgridTableId + "'></table>");
          var gs = $("#" + subgridTableId);
          gs.jqGrid($.extend(true, {
            datatype: 'local',
            deselectAfterSort: false,
            cellEdit: false,
            data: nim_subgrid_data[cmp][rowId],
            colModel: opts.subgrid.cols,
            onSelectRow: function(r, s) {
              callFonServer("grid_local_select", {cmp: cmp, row: r, sel: s, subg: rowId});
              for (var d of nim_subgrid_data[cmp][rowId]) if (d.id == r) d._sel = s;
            },
            onSelectAll: function(r, s) {
              callFonServer("grid_local_select", {cmp: cmp, row: (s ? r : null), sel: s, subg: rowId});
              for (var d of nim_subgrid_data[cmp][rowId]) d._sel = s;
            }
          }, opts.subgrid.grid));
          for (var d of nim_subgrid_data[cmp][rowId]) if (d._sel) gs.jqGrid("setSelection", d.id, false);
        }
      }
  }

  var vg = g.jqGrid($.extend(true, {
    datatype: "local",
    colModel: opts.cols,
    additionalProperties: opts.add_prop,
    data: data,
    gridview: true,
    height: 150,
    ignoreCase: true,
    altRows: true,
    onRightClickRow: function(rowid, iRow, iCol, e) {
      if (opts.modo != "ed") return;

      var col = g.jqGrid("getGridParam", "colModel")[iCol].name;
      var rc = g.find("input");
      if (rc.length > 0 && rc.attr("id") == iRow + '_' + col) return;

      e.preventDefault();
      g.jqGrid('editCell', 0, 0, false);
      g.jqGrid("resetSelection");
      g.find("tr").removeClass('ui-state-highlight');

      if (col.slice(-3) == '_id') {
        var id = g.jqGrid("getLocalRow", rowid)['_' + col];
        if (id && id != '') window.open('/' + g.jqGrid("getGridParam", "colModel")[iCol].controller + '/' + id + '/edit', '_blank', '');
      }
    }
  }, grid_a, grid));

  var gview = $("#gview_g_" + cmp);

  switch(opts.modo) {
    case 'ed':
      g.jqGrid('bindKeys');
      var ht = '<div class="nim-titulo">' + caption + '&nbsp;&nbsp;&nbsp;&nbsp;';
      if (opts.ins && !nimRO) {
        ht += creaMdlButton('b_ib_' + cmp, 30, 2, 22, 'vertical_align_bottom', 'Insertar fila al final');
        if (opts.ins == 'pos') {
          ht += '&nbsp;&nbsp;';
          ht += creaMdlButton('b_it_' + cmp, 30, 2, 22, 'vertical_align_center', 'Insertar fila');
        }
      }
      if (opts.del && !nimRO) {
        ht += '&nbsp;&nbsp;';
        ht += creaMdlButton('b_d_' + cmp, 30, 2, 22, 'delete', 'Borrar fila');
      }
      if (opts.bsearch) {
        ht += '&nbsp;&nbsp;';
        ht += creaMdlButton('b_s_' + cmp, 30, 2, 22, 'filter_list', 'Mostrar/Ocultar filtros');
      }
      if (opts.bcollapse) {
        ht += '&nbsp;&nbsp;';
        ht += creaMdlButton('b_c_' + cmp, 30, 2, 22, 'swap_vert', 'Mostrar/Ocultar rejilla de datos');
      }
      ht +=  '</div>';
      $('#gbox_g_' + cmp).prepend(ht);

      $("#b_it_" + cmp).click(function() {
        //if (g.find('input').length > 0) return;
        var r = g.jqGrid('getGridParam', 'selrow');
        g.jqGrid('editCell', 0, 0, false);
        if (r) {
          var iRow = g.find('#' + r)[0].rowIndex - 1;
          callFonServer("grid_local_ins", {cmp: cmp, pos: iRow});
        }
      });

      $("#b_ib_" + cmp).click(function() {
        //if (g.find('input').length > 0) return;
        g.jqGrid('editCell', 0, 0, false);
        callFonServer("grid_local_ins", {cmp: cmp, pos: -1});
      });

      $("#b_d_" + cmp).click(function() {
        if (g.find('input').length > 0) return;
        var r = g.jqGrid('getGridParam', 'selrow');
        if (r) callFonServer("grid_local_del", {cmp: cmp, row: r});
      });

      $("#b_s_" + cmp).click(function() {
        vg[0].toggleToolbar();
      });

      $("#b_c_" + cmp).click(function() {
        gview.css("display") == "none" ? gview.css("display", "block") : gview.css("display", "none");
      });

      break;
    default :
      if (caption != '') $('#gbox_g_' + cmp).prepend('<div class="nim-titulo">' + caption + '&nbsp;&nbsp;&nbsp;&nbsp;' + '</div>');

      // Si hay subgrid
      $("#jqgh_g_" + cmp + "_subgrid")
        .html('<a style="cursor: pointer;"><span class="ui-icon ui-icon-plus" title="Expandir todo"></span></a>')
        .click(function () {
          var ico = $(this).find(">a>span"), tb = $(this).closest(".ui-jqgrid-view").find(">.ui-jqgrid-bdiv>div>.ui-jqgrid-btable>tbody");
          if (ico.hasClass("ui-icon-plus")) {
            ico.removeClass("ui-icon-plus").addClass("ui-icon-minus").attr("title", "Colapsar todo");
            tb.find(">tr.jqgrow>td.sgcollapsed").click();
          } else {
            ico.removeClass("ui-icon-minus").addClass("ui-icon-plus").attr("title", "Expandir todo");
            tb.find(">tr.jqgrow>td.sgexpanded").click();
          }
        });
  }
  if (opts.export) {
    $("#" + cmp + " .nim-titulo").append('&nbsp;&nbsp;' + creaMdlButton('b_ex_' + cmp, 30, 2, 22, 'assignment_returned', 'Exportar a Excel'));

    if (opts.subgrid) {
      var htm = `<div id="m_exp_${cmp}" class="nim-context-menu">`+
        '<ul class="nim-context-menu-ul">'+
        `<li class="nim-context-menu-li" onClick="exportGridLocal('${cmp}','false')"><i class="material-icons nim-context-menu-icon">keyboard_arrow_down</i>Exportar Cabeceras</li>` +
        `<li class="nim-context-menu-li" onClick="exportGridLocal('${cmp}','true')"><i class="material-icons nim-context-menu-icon">keyboard_double_arrow_down</i>Exportar Todo</li>` +
        '</ul></div>';
      $('body').append(htm);

      $("#b_ex_" + cmp).click(function(e) {
        e.stopPropagation();
        var menu = $("#m_exp_" + cmp);
        menu.css("display", menu.css("display") == "none" ? "block" : "none").position({my: "right top", at: "right bottom", of: '#b_ex_' + cmp})
      });
    } else {
      $("#b_ex_" + cmp).click(function(e) {exportGridLocal(cmp, false)});
    }
  }

  if (opts.search || opts.bsearch) {
    g.jqGrid('filterToolbar',{searchOperators : true});
    if (!opts.search) vg[0].toggleToolbar();
  }

  g.setGridWidth(grid.width ? grid.width : g.width());
}

function exportGridLocal(cmp, subg) {
  // Pasamos al servidor los ids, pero obtenidos con "lastSelectedData", que los devuelve respetando el orden que haya establecido el usuario
  // respetando el sort o multisort que se haya efectuado.
  var ids = [];
  var data = $("#g_" + cmp).jqGrid("getGridParam", "lastSelectedData");
  for (var i in data) ids.push(data[i].id);
  ponBusy();
  callFonServer("grid_local_export", {cmp: cmp, subg: subg, ids: ids}, quitaBusy);
}

function autoCompGridLocal(el, modelo, ctrl, cmp, col) {
  $(el).parent().css('position', 'relative');
  var g = $("#g_" + cmp);
  var rowid = g.jqGrid('getGridParam', 'selrow');
  $(el).autocomplete({
    source: '/application/auto?type=form&mod=' + modelo + '&vista=' + _vista + '&cmp=' + cmp + '_' + rowid + '_' + col + '&eid=' + eid + '&jid=' + jid,
    minLength: 1,
    autoFocus: true,
    //select: function(e, ui) {$(this).attr('dbid', ui.item.id); $(this).parents('table').attr('last_autocomp_id', ui.item.id)},
    select: function(e, ui) {$(this).attr('dbid', ui.item.id); g.attr('last_autocomp_id', ui.item.id)},
    response: function(e, ui) {auto_comp_error(e, ui);}
  }).addClass("auto_comp").attr('controller', ctrl).attr('cmp', cmp).attr('col',  col).attr('dbid', g.jqGrid('getLocalRow', rowid)['_'+col]);
}

/*
function addRolButton(el, label, icon, fon) {
  el.parent().append(
    '<button id="_nim_rol_button_" class="mdl-button mdl-js-button mdl-button--icon nim-remove-on-input" title="' + label + '" style="position: absolute;top: -4px;right: -4px" tabindex=-1>' +
    '<i class="material-icons nim-color-2">' + icon + '</i>' +
    '</button>'
  );
  $('#_nim_rol_button_').on('click', fon);
}
*/

function p2p(tit, label, pb, cancel, width, mant, fin) {
  p2pStatus = 1;  // Variable global indicando el estado del proceso (1=activo, 0=finalizado, 2=Error)

  var htm = '<div>';
  htm += '<div id="p2p-d" style="margin-bottom: 15px">' + label + '</div>';
  if (pb != undefined) {
    htm += '<div id="p2p-p" class="mdl-progress mdl-js-progress';
    if (pb == 'inf') {htm += ' mdl-progress__indeterminate';}
    htm += '"></div>';
  }
  htm += '</div>';

  var vi;

  $(htm, (mant ? parent.document : document)).dialog({
    resizable: false,
    draggable: false,
    position: {my: "top", at: "top+100", of: window},
    modal: true,
    title: tit,
    closeOnEscape: false,
    width: width || 'auto',
    maxHeight: window.innerHeight - 200,
    open: function () {
      var dlg = $(this);
      var dlgd = dlg.parent();
      dlgd.find('.ui-dialog-titlebar-close').css('display', 'none');
      if (!cancel) dlgd.find('.ui-dialog-buttonpane').css('display', 'none');
      vi = setInterval(function() {
        callFonServer('p2p_req', {p2ps: p2pStatus}, function() {
          if (p2pStatus != 1) {
            clearInterval(vi);
            if (p2pStatus == 2) {
              fin.label = 'Finalizar';
              dlgd.find('.ui-dialog-buttonpane').prepend('<i class="material-icons" style="color: #FF4081; vertical-align: bottom">report_problem</i>Error');
            }
            if (fin.label) {
              var context = mant ? parent.document : document;
              $("#p2p-p", context).removeClass('mdl-progress__indeterminate');
              dlgd.find('.ui-dialog-buttonpane').css('display', 'block');
              dlgd.find('.ui-dialog-buttonpane button span').text(fin.label);
            } else {
              if (fin.met) callFonServer(fin.met);
              dlg.dialog("close");
            }
          }
        });
      }, 3000);
    },
    close: function () {
      $(this).remove();
    },
    buttons: {
      "Cancelar": function () {
        if (p2pStatus == 1) {
          p2pStatus = 0;
          fin.met = null;
          // El proceso aún está en curso. Notificar al server
          clearInterval(vi);
          var dlg = $(this).parent();
          var bt = dlg.find('.ui-dialog-buttonpane button');
          var btt= bt.find('span');
          bt.attr('disabled', true);
          btt.css('color', '#aaaaaa');
          callFonServer('p2p_req', {p2ps: 0}, function() {
            bt.attr('disabled', false);
            btt.css('color', 'black').text('Finalizar');
            dlg.find('.ui-dialog-buttonpane').prepend('<i class="material-icons" style="color: #FF4081; vertical-align: bottom">report_problem</i>Cancelado');
          });
        } else {
          if (fin.met && p2pStatus == 0) callFonServer(fin.met);
          $(this).dialog("close");
        }
      }
    }
  });
  mant ? parent.componentHandler.upgradeDom() : componentHandler.upgradeDom();
}

var nimRO = false;
function soloLectura() {
  nimRO = true;
  $(document).on("keydown", function (e) {
    if (e.keyCode != 9) return false;
  });
  $('input[type="checkbox"]').attr("disabled", true);
  $('select').attr("disabled", true);
}

function setMenuR(st) {
  var context = (parent == self ? document : parent.document);
  
  $(".menu-r-user", context).attr("disabled", true);
  if (!st) $(".menu-r-user" + (nimRO ? ":not(.dis-ro)" : ""), context).attr("disabled", false);
}

function checkNimServerStop() {
  if (nimWinMenu.nimServerStop) {
    alert('El servidor está en mantenimiento.\nSi sigue trabajando no se guardarán los datos.\nSe recomienda cerrar todas las ventanas\nhasta que se reanude el servicio.')
    return true;
  } else
    return false;
}

function clickNimButton(accion, busy) {
  if (busy) ponBusy();
    $(".ui-jqgrid-btable").jqGrid('editCell', 0, 0, false);
    if (accion.startsWith("js:")) {
      eval(accion.slice(3));
      quitaBusy();
    } else
      nimAjax(accion, {}, {complete: function() {if (busy) quitaBusy();}});
}

function creaBotonesDialogo(bot, dlg) {
  var htm = '';
  for (let b of bot) {
    htm += '<button class="nim-dialog-button mdl-button mdl-js-button mdl-button--raised mdl-button--colored mdl-js-ripple-effect">';
    if (b.icon) htm += '<i class="material-icons">' + b.icon + '</i>'  + (b.label ? '&nbsp;' : '');
    if (b.label) htm += b.label;
    htm += '</button>';
  }
  //dlg.parent().append('<div class="nim-dialog-div-buttons"><center>' + htm + '</center></div>');
  dlg.parent().append('<div class="nim-dialog-div-buttons">' + htm + '</div>');

  var i = 0;
  dlg.parent().last().find(".nim-dialog-button").each(function() {
    var b = bot[i++]; 
    $(this).click(function() {
      if (b.busy) ponBusy();
      dlg.find(".ui-jqgrid-btable").jqGrid('editCell', 0, 0, false);
      if (b.accion) {
        if (b.accion.startsWith("js:")) {
          eval(b.accion.slice(3));
          quitaBusy();
        } else
          nimAjax(b.accion, {}, {complete: function() {if (b.busy) quitaBusy();}});
      }
      if (b.close == undefined || b.close) dlg.dialog("close");
    });
  });
}

function creaDialogos(dial) {
  for (let d of dial) {
    let dlg = $("#" + d.id);
    var prop = {
      autoOpen: false,
      resizable: false,
      modal: true,
      width: d.width ? d.width : '100%',
      height: d.height ? d.height : 'auto',
      title: d.titulo
    };
    if (d.position) prop.position = d.position;
    dlg.dialog(prop);

    if (d.botones) creaBotonesDialogo(d.botones, dlg);
  }
}

function nimbusUpload(e) {
  var th = this;
  var etf = e.target.files;
  if (etf.length == 0) return;

  tam = 0; for(f of etf) tam += f.size;

  nimbusUploadStatus = null;
  ponBusy(1);
  callFonServer('nimbus_upload_check', {tam: tam}, function () {
    if (nimbusUploadStatus == 0) $(th).parent().submit();
    quitaBusy(1);
    th.value = "";
  });
}

function nimbusd(met, params) {
  ponBusy();
  $.post(params.plugin ? params.plugin : "http://127.0.0.1:2003", params).
    done(function(res) {callFonServer(met, JSON.parse(res));}).
    fail(function() {callFonServer(met, {st: 'Fallo de conexión con el plugin'});}).
    always(function() {quitaBusy();});
}

$(window).load(function() {
  var _auto_comp_menu_;

  // Calcular cuál es la ventana del menú principal (si sigue abierta)
  nimWinMenu = self;
  do {
    if (nimWinMenu.parent == nimWinMenu.self) {
      if (nimWinMenu.nimServerStop == undefined) {
        if (nimWinMenu.opener == null)
          break;
        else
          nimWinMenu = nimWinMenu.opener;
      } else
        break;
    } else
      nimWinMenu = nimWinMenu.parent;
  } while (true);

  $("body").on("focus", ".nim-datetime", function (e) {
    var th = $(this);
    var rt = e.relatedTarget;
    if (!rt || $(rt).closest('.ui-datepicker-calendar').length == 0 && $(rt).parent().parent().attr("id") != th.attr("id")) {
      var inps = th.find('input');
      th.data('of', inps.first().val()).data('oh', inps.last().val())
    }
  }).on("blur", ".nim-datetime", function (e) {
    var th = $(this);
    var rt = e.relatedTarget;
    if (!rt || $(rt).closest('.ui-datepicker-calendar').length == 0 && $(rt).parent().parent().attr("id") != th.attr("id")) {
      var inps = th.find("input");
      var f = inps.first();
      var h = inps.last();
      if (th.data("of") != f.val()) {
        var nf = checkDate(f.val());
        f.val(nf == null ? th.data("of") : nf);
      }
      if (th.data("of") != f.val() || th.data("oh") != h.val()) {
        if (f.val() == "" && h.val() != "") {
          var hoy = new Date;
          var d = hoy.getDate();
          var m = hoy.getMonth() + 1;
          f.val((d < 10 ? "0" : "") + d + '-' + (m < 10 ? "0" : "") + m + "-" + hoy.getFullYear());
        }
        if (h.val() == "" && f.val() != "") h.val("00:00" + (h.data("seg") ? ":00" : ""));
        send_validar(th, (f.val() + " " + h.val()).trim());
      }
    }
  });

  $("body").on("focus", "input, select, textarea", function (e) {
    $(".nim-remove-on-input").remove();
  }).on("click", function() {
    $(".nim-context-menu").css("display", "none");
  }).on("focus", ".auto_comp", function (e) {
    if ($(this).attr("menu") == "N") return;

    $(this).parent().append(
      '<button id="_auto_comp_button_" class="mdl-button mdl-js-button mdl-button--icon nim-remove-on-input" style="position: absolute;top: -4px;right: -4px" tabindex=-1>'+
      '<i class="material-icons">more_vert</i>'+
      '</button>'
    );

    $("#_auto_comp_menu_").remove();
    
    var rw = !(nimRO || $(this).attr("readonly") == "readonly");
    var htm = '<div id="_auto_comp_menu_" class="nim-context-menu">'+
      '<ul class="nim-context-menu-ul">'+
      '<li class="nim-context-menu-li" onClick="autoCompIrAFicha()"><i class="material-icons nim-context-menu-icon">exit_to_app</i>Ir a...</li>';
      if (rw) htm += '<li class="nim-context-menu-li" onclick="autoCompBuscar()"><i class="material-icons nim-context-menu-icon">search</i>Buscar</li>';
      htm += '<li class="nim-context-menu-li" onClick="autoCompNuevaFicha()"><i class="material-icons nim-context-menu-icon">add</i>Nueva alta</li>';
    if ($(this).data("menu")) {
      for (const m of $(this).data("menu")) {
        if (rw || !m.dis_ro) htm += `<li class="nim-context-menu-li" onClick="callFonServer('${m.metodo}', {cmp: '${$(this).attr("id")}'})"><i class="material-icons nim-context-menu-icon">${m.icono}</i>${m.label}</li>`;
      }
    }
    htm += '</ul></div>';

    $('body').append(htm);

    $('#_auto_comp_button_').on('click', function(e){
      e.stopPropagation();
      var menu = $("#_auto_comp_menu_");
      if (menu.css("display") == 'none') {
        menu.css("display", "block").position({my: "right top", at: "right bottom", of: '#_auto_comp_button_'});
      } else
        menu.css("display", "none");

    });

    componentHandler.upgradeDom();
  }).on("contextmenu", ".nim-label-img", function(e) {
    e.preventDefault();
    var cmp = $(this).attr("for");
    var inp = $("#" + cmp);
    var img = $("#" + cmp + "_img");
    if (inp.attr("disabled") || img.attr("src") == undefined || img.attr("src") == '') return;

    $('<div>¿Desea eliminar la imagen?</div>').dialog({
      resizable: false, modal: true, width: "auto", title: "Borrar imagen",
      close: function () {
        $(this).remove();
      },
      buttons: {
        "No": function () {
          $(this).dialog("close");
        },
        "Sí": function () {
          send_validar(inp, "*");
          $(this).dialog("close");
        }
      }
    });
  });

  $(document).on("keydown", function (e) {
    if (e.keyCode == 27) $(".nim-context-menu").css("display", "none");
  });

  $(window).unload(function() {
    if (typeof(_vista) == "undefined") return;

    /*
    var vista = [];
    var nimlock = [];

    function addItem(win, doc) {
      if (typeof(win._vista) != 'undefined') vista.push(win._vista);
      if (typeof(win._nimlock) != 'undefined') nimlock.push(win._nimlock);

      var ficha = doc.getElementById('ficha');
      if (ficha) addItem(ficha.contentWindow, ficha.contentDocument);

      var hijo;
      for(var i = 0; hijo = doc.getElementById('hijo_' + i); i++) {
        addItem(hijo.contentWindow, hijo.contentDocument);
      }
    }

    addItem(window, document);

    $.ajax({
      url: '/application/destroy_vista',
      type: "POST",
      async: false,
      data: {vista: vista, nimlock: nimlock}
    });
    */
    var data = new FormData();
    data.set('vista', _vista);
    if (typeof(_nimlock) != "undefined") data.set('nimlock', _nimlock);
    navigator.sendBeacon("/application/destroy_vista", data);
  });
});