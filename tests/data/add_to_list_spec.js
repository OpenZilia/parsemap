'use strict';

var api = require('../lib/api');

let listIdentifier = 'ImmoList';

var i = 0;
for (i = 0; i < 10000; ++i) {
  api.createPoint(Math.random() * 180 - 90, Math.random() * 360 - 180, function(point) {
    api.addPointToList(listIdentifier, point.identifier, function() {
    });
  });
}
