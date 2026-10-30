const CACHE_NAME = "phomab-shell-v3";
const SHELL = ["./", "./index.html", "./offline.html", "./manifest.json", "./phomab-icon-192.svg", "./phomab-icon-512.svg"];
self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(SHELL)).catch(() => {}).then(() => self.skipWaiting()));
});
self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k.startsWith("phomab-") && k !== CACHE_NAME).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin === self.location.origin && request.mode === "navigate") {
    event.respondWith(fetch(request).then(response => {
      if (response && response.ok) caches.open(CACHE_NAME).then(cache => cache.put(request, response.clone()));
      return response;
    }).catch(async () => (await caches.match(request)) || (await caches.match("./index.html")) || (await caches.match("./offline.html"))));
    return;
  }
  const cacheableAsset = request.destination === "script" || request.destination === "style" || request.destination === "font";
  if (cacheableAsset) {
    event.respondWith(caches.open(CACHE_NAME).then(async cache => {
      const cached = await cache.match(request);
      if (cached) return cached;
      try {
        const response = await fetch(request);
        if (response && (response.ok || response.type === "opaque")) cache.put(request, response.clone());
        return response;
      } catch (error) {
        return cached || Response.error();
      }
    }));
  }
});
self.addEventListener("notificationclick", event => {
  event.notification.close();
  event.waitUntil(self.clients.matchAll({type:"window"}).then(clients => clients.length ? clients[0].focus() : self.clients.openWindow("./")));
});