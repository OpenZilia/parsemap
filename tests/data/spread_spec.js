'use strict';

var api = require('../lib/api');

// 48.863787, 2.344784
var i = 0;
api.createList('Test list', function(list) {
  for (i = 0; i < 1000; ++i) {
    api.createPoint(48.863787 + Math.random() * 0.16 - 0.08, 2.344784 + Math.random() * 0.16 - 0.08, function(point) {
      api.createPointMeta(point.identifier, list.identifier, function(pointMeta) {
        api.addPointToList(list.identifier, point.identifier, function() {
        });
      });
    });
  }
});
