angular.module 'streetwars-stats', []

.controller 'StatsCtrl', ($scope, $http) ->
  $scope.predicate = 'lethality'
  $scope.teams = []
  $http.get('/teams.json')
    .then (response) ->
      $scope.teams = response.data

.directive 'teamList', ->
  restrict: 'E'
  templateUrl: '/team.html'
  scope: '='
