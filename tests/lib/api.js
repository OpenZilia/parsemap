'use strict';

let frisby = require('frisby');
let querystring = require('querystring');

let TEST_KEY = '4g23G#$GEG#@G5Hl3;[]3f2';

let version = 'v2';
let URL = 'http://localhost:8000/' + version;

module.exports.createList = function(name, after) {
  frisby.create('create list')
  .post(URL + '/list/', {
    name: name,
    icon: '',
    tags: [
      'tag test1',
      'tag test2',
    ],
  }, {json: true})
  .addHeader('X-ParsemapAppKey', TEST_KEY)
  .expectHeaderContains('Content-Type', 'json')
  .expectStatus(201)
  .expectJSONTypes({
    identifier: String,
  })
  .afterJSON(after)
  .toss();
}

module.exports.createPoint = function(latitude, longitude, after) {
  frisby.create('add point')
  .post(URL + '/point/', {
    name: 'point test',
    latitude: latitude,
    longitude: longitude,
    provider: 'test',
    provider_id: 'testproviderid42',
  }, {json: true})
  .addHeader('X-ParsemapAppKey', TEST_KEY)
  .expectHeaderContains('Content-Type', 'json')
  .expectStatus(201)
  .expectJSONTypes({
    identifier: String,
  })
  .afterJSON(after)
  .toss();
}

module.exports.removePoint = function(point, after) {
  frisby.create('remove point')
  .delete(URL + '/point/' + point + '/')
  .addHeader('X-ParsemapAppKey', TEST_KEY)
  .expectStatus(202)
  .after(after)
  .toss();
}

module.exports.addPointToList = function(list, point, after) {
  frisby.create('add point to list')
  .post(URL + '/list/' + list + '/point/' + point + '/')
  .addHeader('X-ParsemapAppKey', TEST_KEY)
  .expectStatus(201)
  .after(after)
  .toss();
}

module.exports.createPointMeta = function(point, list, after) {
  let images = ['http://i.imgur.com/slGGjh9.png', 'http://i.imgur.com/WcWg3xo.jpg', 'http://i.imgur.com/zpwvN7W.jpg', 'http://i.imgur.com/s9zmKAG.jpg'];
  frisby.create('add point meta')
  .post(URL + '/pointmeta/', {
    list: list,
    point: point,
    uid: 'infos',
    action: 'merge',
    content: JSON.stringify({
      testKey: 'testValue',
      testKey2: 'testValue2',
      price: 500000,
      images: [{
          original: {
            url: images[parseInt(Math.random() * images.length)],
            name: 'tfss-3ba84f14-be1e-4f3b-bd03-f49af941a6c6-original',
            __type: 'File',
          }
        },],
      address: parseInt(Math.random() * 100) + ' rue des petits champs, 75001',
    })
  }, {json: true})
  .addHeader('X-ParsemapAppKey', TEST_KEY)
  .expectHeaderContains('Content-Type', 'json')
  .expectStatus(201)
  .expectJSONTypes({
    identifier: String,
  })
  .afterJSON(after)
  .toss();
}

module.exports.createListMeta = function(list, after) {
  frisby.create('add list meta')
  .post(URL + '/listmeta/', {
    list: list,
    uid: 'testuid list',
    action: 'display',
    content: JSON.stringify({
      testKey: 'testValue list',
      testKey2: 'testValue2 list',
    })
  }, {json: true})
  .addHeader('X-ParsemapAppKey', TEST_KEY)
  .expectHeaderContains('Content-Type', 'json')
  .expectStatus(201)
  .expectJSONTypes({
    identifier: String,
  })
  .afterJSON(after)
  .toss();
}

module.exports.getPointsFromList = function(list, attrs, expect, after) {
  frisby.create('get points from list')
  .get(URL + '/list/' + list + '/points/?' + querystring.stringify(attrs))
  .expectHeaderContains('Content-Type', 'json')
  .expectStatus(200)
  .expectJSON(expect)
  .afterJSON(after)
  .toss();
}
