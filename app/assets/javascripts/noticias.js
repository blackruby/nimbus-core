_controlador = "mensajes";

function addNoticia(nt) {
  $("#dnoticias").prepend(`
  <div class="noticia ${nt.new ? 'nueva' : ''}">
    <div class="cabecera">
      <div class="foto" style="background-image: url(${nt.img.slice(4)})">${nt.img == "" ? nt.from[0] : ""}</div>
      <div class="remite">${nt.from}</div>
      <div class="fecha" title="${nt.fel}"> · ${nt.fec}</div>
    </div>
    <div class="texto">${nt.tex}</div>
    <div class="botones">
      <i class="material-icons responder" title="Responder" uid="${nt.uid}">reply</i>
      <i class="material-icons archivar" title="Archivar" nid="${nt.id}">archive</i>
    </div>
  </div>
  `);
}

function cargarNoticias(dat) {
  for (var n in dat) addNoticia(dat[n]);
}

function adecuarUsuarios(uid) {
  // Desmarcar todos los usuarios
  $(".is-checked").removeClass("is-checked");
  // Marcar uid
  if (uid != undefined) $("#lb" + uid).addClass("is-checked");
}

function nuevoMsg(uid) {
  var dnm = $("#d-nuevo-msg");
  if (dnm.css("display") == "block") {
    dnm.css("display", "none");
    return;
  }

  $("#d-nuevo-msg").css("display", "block");
  $("#t-nuevo-msg").val("").focus();

  if ($("#d-lista-usu").children().length == 0) { // Cargar usuarios sólo la primera vez
    callFonServer("cargar_usuarios", {}, function(dat) {
      for (var i in dat) {
        $("#d-lista-usu").append(`
          <div class="usuario">
            <div class="foto" style="background-image: url(${dat[i].img.slice(4)})">${dat[i].img == "" ? dat[i].nom[0] : ""}</div>
            <div class="usuario-nom">
              <label id="lb${dat[i].id}" class="mdl-checkbox mdl-js-checkbox mdl-js-ripple-effect" uid=${dat[i].id} for="cb${i}">
                <input type="checkbox" id="cb${i}" class="mdl-checkbox__input" />
                <span class="mdl-checkbox__label">${dat[i].nom}</span>
              </label>
            </div>
          </div>
        `);
      }
      componentHandler.upgradeDom();
      adecuarUsuarios(uid);
    });
  } else {
    adecuarUsuarios(uid);
  }
}

function enviarMsg() {
  var uids = [];
  $(".is-checked").each(function() {uids.push($(this).attr("uid"));});
  if (uids.length == 0 || $("#t-nuevo-msg").val() == "") {
    alert("Escriba un mensaje y elija al menos un destinatario");
    return;
  }

  callFonServer("enviar_mensaje", {msg: $("#t-nuevo-msg").val(), uids: uids});
  $("#d-nuevo-msg").css("display", "none");
}

$(window).load(function () {
  $("#d-nuevo-msg").keydown(function(e) {
    if (e.which == 27) $("#d-nuevo-msg").css("display", "none");
  });

  $("body").on("click", ".responder", function() {
    if ($("#d-nuevo-msg").css("display") == "block") return;

    nuevoMsg($(this).attr("uid"));
  });

  $("body").on("click", ".archivar", function() {
    $(this).parentsUntil(".noticia").parent().remove();
    callFonServer("marcar_leidos", {ids: [$(this).attr("nid")]});
  });

  callFonServer("cargar_noticias", {}, cargarNoticias);
  setInterval(function() {callFonServer("cargar_noticias", {nuevas: true}, cargarNoticias);}, 60000);
});