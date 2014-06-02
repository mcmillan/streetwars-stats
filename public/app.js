// fuck jquery
Handlebars.registerHelper('addOne', function(number) {
  return new Handlebars.SafeString(parseInt(number, 10) + 1);
});

$.getJSON('/teams', function(teams) {
  var source = $('#teams-template').html();
  var template = Handlebars.compile(source);
  $('.teams').html(template({teams: teams}));
});
