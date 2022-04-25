function iniBloqueo(reloj, usuario) {
  setInterval(function() {
    $('#reloj').text(('0'+parseInt(reloj/60)).slice(-2) + ':' + ('0'+reloj%60).slice(-2));
    if (reloj-- == 0) window.location.replace('/');
  }, 1000);

  $("#dialog-email").dialog({
    title: "Solicitar contraseña",
    autoOpen: false,
    resizable: false,
    modal: true,
    width: "auto",
    buttons: {
      "Cancelar": function() {$(this).dialog("close");},
      "Enviar": function() {
        $.ajax({
          url: '/pass_olvido',
          type: "POST",
          data: {usu: usuario}
        });
        $(this).dialog("close");
      }
    }
  });

  $("#a-olvido").click(function (e) {
    e.preventDefault();
    $("#dialog-email").dialog("open");
  });
}