// Casa Yannuga · service worker
// Lets the phone install the app. Pages and files come from the network first,
// so a new version shows up as soon as it is published; the cache only covers
// opening the app with no signal. Supabase and other sites are never touched.
var CACHE = "yannuga-v2";

self.addEventListener("install", function (e) { self.skipWaiting(); });
self.addEventListener("activate", function (e) {
  e.waitUntil(caches.keys().then(function (ks) {
    return Promise.all(ks.filter(function (k) { return k !== CACHE; })
      .map(function (k) { return caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});

self.addEventListener("fetch", function (e) {
  var r = e.request;
  if (r.method !== "GET" || new URL(r.url).origin !== self.location.origin) return;
  e.respondWith(fetch(r).then(function (res) {
    if (res.ok) { var c = res.clone(); caches.open(CACHE).then(function (k) { k.put(r, c); }); }
    return res;
  }).catch(function () {
    return caches.match(r).then(function (m) { return m || caches.match("./"); });
  }));
});
