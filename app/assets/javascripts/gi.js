$(window).load(function () {
  var clFormato = $(".formato");

  clFormato.on("click", function () {
    window.open('/gi/' + modo + '/' + $(this).parentsUntil('#solapas').last().attr('id') + '/' + $(this).text(), '_self');
  });

  if (modo == "edit") {
    clFormato.on("contextmenu", function (e) {
      e.preventDefault();
      var tr = $(this).parent();
      var form = $(this).parentsUntil('#solapas').last().attr('id') + '/' + $(this).text();
      $("#borrar").dialog({
        title: 'Borrar',
        modal: true,
        resizable: false,
        width: "auto",
        buttons: {
          "No": function () {
            $(this).dialog("close");
          },
          "Sí": function () {
            $.ajax({
              url: '/gi/fon_server',
              type: "POST",
              data: {fon: 'borra_formato', form: form}
            });
            $(this).dialog("close");
            tr.remove();
          }
        }
      }).html('<p><i class="material-icons nim-color-2" style="float:left; margin:12px 12px 20px 0;">report_problem</i>Se va a proceder a eliminar el formato "<b>' + form + '</b>".<br>¿Está seguro?</p>');
    });

    $("#ayuda").dialog({
      title: 'Ayuda',
      modal: true,
      autoOpen: false,
      resizable: false,
      width: "auto"
    });
  }

  $("#solapas").tabs().css("display", "block");
});
