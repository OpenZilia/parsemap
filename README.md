Introduction
===

Plug and play map backend.

```
This code is the first code I made last year in Go, the way I manage
rest services implies a lot of nearly duplicated code, a better
and more functionnal way is under construction.

But the outside Rest API should not change.
```

Parsemap is a micro service meant to be directly plugged behind a map
on a mobile app or website, it can be used with any of GoogleMaps, MapView from Apple or
Mapbox.

It is meant to easily fix the main problem on a map, which is querying and
displaying, especially when density makes the "load all, display all"
strategy inadequate.
When density gets too high, which happens when you unzoom, you end up
with a mess of annotations which is bad for UX and aesthetics.

The solution is to create `clusters` which are special annotations
that symoblise a group of annotations.
Unfortunately, these clusters are not that easy to create, and it can be
especially intensive on your database, leading to response time issues,
which is one of the most important constraints when using a map, it has
to be fast, no matter how many points you put on it.

That is where parsemap provides the `/list/:identifier/annotation/`.
This call is made to be convenient, its parameters are as follows:

```
- mapWidth/mapHeight: the size in pixel (or point) of you map
- annotationWidth/annotationHeight: the size in pixel of your annotation
- latitudeMin/latitudeMax + longitudeMin/longitudeMax: the area covered
  by you map
```

and it responds with a json object with the fields:

```
- clusters: an array of clusters, each clusters are made of:
  - latitude/longitude: each cluster is a squared zone, but the
    latitude longitude given is an average of the points in this zone.
  - n_addresses: the number of addresses in this cluster
  - geohash: the identifier of the cluster, used to later fetch all
    points in this cluster.
- points: an array of points, which are all the points that you can have
  directly, the density around them is low enough to be displayed
  directly.
  - latitude/longitude
  - metas: the metas that you stored for this point. See the `Meta`
    section for further infos.
  - TODO complete list
```


