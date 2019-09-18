_controlador = 'updates';

function renderUpdate(dat) {
  $("#detalle").html(dat);
}

function getUpdate(el) {
  callFonServer("get_update", {file: $(el).text()}, renderUpdate);
}

$(window).load(function() {
  $("body").on("click", ".expande", function() {
    var el = $(this).parent().next();
    if (el.css("display") == "none") {
      el.css("display", "block");
      $(this).text("expand_less");
    } else {
      el.css("display", "none");
      $(this).text("expand_more");
    }
  });
});