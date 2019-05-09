colores = [['#FFEDB4', 'white'], ['red', 'gray']];

function gridCargado() {
  var ci = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  var fila = 0;
  $("tbody tr.jqgrow").each(function() {
    var tr = $(this);
    var tra = tr.prev().find("td");
    var i = 0;
    tr.find("td").each(function() {
      if (i == 0) {
        if ($(this).html() < 0) $(this).next().css("background-color", "red");
      } else if (i > 2) {
        v = $(this).html();
        va = fila == 0 ? null : tra.eq(i).html();
        if (v != va) {
          ci[i] = (ci[i] + 1)%2;
        }
        //$(this).css("background-color", colores[i%2][ci[i]]);
        $(this).css("background-color", colores[0][ci[i]]);
      }
      i++;
    });
    fila++;
  });
}

$(window).load(function () {
  $("#g_panel").css("pointer-events", "none");
});