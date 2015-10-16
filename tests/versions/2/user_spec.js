'use strict';

let api = require("../../lib/api");

api.createList('Test list', function(list) {
  api.createPoint(48.48266193, 2.409832523, function(point) {
    api.addPointToList(list.identifier, point.identifier, function() {
      api.createPointMeta(point.identifier, list.identifier, function(pointMeta) {
        api.createListMeta(list.identifier, function(listMeta) {
          api.getPointsFromList(list.identifier, {
            geohash: '5',
            limit: 50,
          }, [
            {
              identifier: point.identifier,
              latitude: 48.48266193,
              longitude: 2.409832523,
              name: 'point test',
              provider: 'test',
              provider_id: 'testproviderid42',
              metas: [
                {
                  identifier: pointMeta.identifier,
                  uid: 'infos',
                  action: 'merge',
                  content: '{"price": 500000, "testKey": "testValue", "testKey2": "testValue2"}',
                  list: list.identifier
                }
              ]
            }
          ], function(points) {
            api.removePoint(point.identifier, function() {});
          });
        });
      });
    });
  });
});
