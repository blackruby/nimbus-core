_controlador = 'updates';

function renderUpdate(dat) {
  $("#detalle").html(dat);
}

function getUpdate(el) {
  $(".activo").removeClass('activo');
  $(el).addClass('activo');
  callFonServer("get_update", {hfec: $(el).text()}, renderUpdate);
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
  $(".updates label").first().trigger("click");
});