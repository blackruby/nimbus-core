function statusToClass(st) {
  switch(st) {
    case 'p': return "c-permitido";
    case 'b': return "c-sinborrado";
    case 'c': return "c-consulta";
    case 'x': return "c-prohibido";
    default: return "c-herencia";
  }
}

function statusToText(st) {
  var tx = statusToClass(st).slice(2);
  return tx[0].toUpperCase() + tx.slice(1);
}

function genDatos(emp, prf, usu, admin) {
  _admin = admin;
  var htm;

  htm = '';
  for (var e in emp) {
    htm += "<tr class='c-empresa' iddb=" + emp[e].id + ">";
    htm += "<td><i class='" + statusToClass(emp[e].st) + " material-icons status'></i></td>";
    //htm += "<td" + (emp[e].dsbl ? " class='dsbl'" : '') + ">" + emp[e].nom + "</td>";
    htm += "<td>" + emp[e].nom + "</td>";
    htm += "<td><select class='c-permiso'" + (emp[e].dsbl ? 'disabled' : '') + ">";
    for (var op in emp[e].pm) htm += "<option value='" + emp[e].pm[op] + "'" + (emp[e].pm[op] == emp[e].st ? ' selected' : '') + ">" + statusToText(emp[e].pm[op]) + "</option>";
    htm += "</select></td>";
    htm += "<td><select class='c-perfil'" + (emp[e].dsbl ? 'disabled' : '') + ">";
    if (emp[e].pfn) {
      htm += emp[e].pfn;
      htm += "<option value='" + emp[e].pf + "' selected>" + emp[e].pfn + "</option>";
    } else {
      for (var p in prf) htm += "<option value='" + prf[p].id + "'" + (emp[e].pf == prf[p].id ? ' selected' : '') + ">" + prf[p].nom + "</option>";
      htm += "<option value='0'" + (admin || emp[e].st == 'x' ? '' : ' disabled') + (emp[e].pf == '0' ? ' selected' : '') + ">" + 'Sin perfil' + "</option>";
    }
    htm += "</td></select>";
    htm += "</tr>";
  }
  $("#t-empresas").append(htm);

  htm = '';
  for (var p in prf) {
    htm += '<label class="mdl-checkbox mdl-js-checkbox mdl-js-ripple-effect"' + (prf[p].st ? ' is-checked' : '') + 'for="prf' + prf[p].id + '">';
    htm += '<input id="prf' + prf[p].id + '" type="checkbox" class="mdl-checkbox__input check-perfil"' + (prf[p].st ? ' checked' : '') + (prf[p].dsbl ? ' disabled' : '') + '/>';
    htm += '<span class="mdl-checkbox__label">' + prf[p].nom + '</span>';
    htm += '</label>';
  }
  $("#d-perfiles").append(htm);

  htm = '';
  for (var u in usu) {
    htm += '<label class="mdl-checkbox mdl-js-checkbox mdl-js-ripple-effect"' + (usu[u].st ? ' is-checked' : '') + 'for="usu' + usu[u].id + '">';
    htm += '<input id="usu' + usu[u].id + '" type="checkbox" class="mdl-checkbox__input check-usuario"' + (usu[u].st ? ' checked' : '') + (usu[u].dsbl ? ' disabled' : '') + '/>';
    htm += '<span class="mdl-checkbox__label">' + usu[u].nom + '</span>';
    htm += '</label>';
  }
  $("#d-usuarios").append(htm);
}

function jsGrabar() {
  var emp = {};
  $(".c-empresa").each(function(){
    var prm = $(this).find('.c-permiso').val();
    var prf = $(this).find('.c-perfil').val();
    if (prm != 'x' || prf != 0) emp[$(this).attr('iddb')] = [prm, prf];
  });

  var prf = [];
  $(".check-perfil").each(function(){
    if ($(this).prop("checked")) prf.push($(this).attr('id').slice(3));
  });

  var usu = [];
  $(".check-usuario").each(function(){
    if ($(this).prop("checked")) usu.push($(this).attr('id').slice(3));
  });

  return {emp: emp, prf: prf, usu: usu};
}

function tabClickUsu(tab) {
  div = $("#d-" + tab.prop('id').slice(2));
  if (div.length != 0) div.css("height", $(window).height() - div.offset().top).css("margin-left", ($(window).width()-div.width())/2+"px");
}

function showHidePass() {
  var p = $("#password, #password_rep");
  if (p.attr("type") == "password") {
    p.attr("type", "text");
    $("#d_vis i").attr("title", "Ocultar contraseñas");
  } else {
    p.attr("type", "password");
    $("#d_vis i").attr("title", "Mostrar contraseñas");
  }
}

$(window).load(function () {
  $("#t-empresas").on("change", ".c-permiso", function (e) {
    var pm = $(this).val();
    $(this).parent().parent().find('.status').attr('class', statusToClass(pm) + " material-icons status");
    if (!_admin) {
      var epf = $(this).parent().parent().find('.c-perfil');
      zz = epf;
      if (pm == 'x') {
        epf.children().last().attr('disabled', false);
      } else {
        if (epf.val() == 0) epf.val(epf.children().first().attr('value'));
        epf.children().last().attr('disabled', true);
      }
    }
  });

  //$(window).resize(tabClickUsu);

  $("#d_vis").html('<i class="material-icons" title="Mostrar contraseñas" onclick="showHidePass()">visibility</i>');
});
