const C="phomab-v1";
self.addEventListener("install",()=>self.skipWaiting());
self.addEventListener("activate",e=>e.waitUntil(self.clients.claim()));
self.addEventListener("fetch",e=>{const r=e.request;if(r.method!=="GET")return;const u=new URL(r.url);
const lib=u.hostname==="www.gstatic.com"||u.hostname==="fonts.gstatic.com"||u.hostname==="fonts.googleapis.com";
if(lib){e.respondWith(caches.open(C).then(c=>c.match(r).then(m=>m||fetch(r).then(x=>{if(x.ok)c.put(r,x.clone());return x}))));return}
if(u.origin===location.origin&&r.mode==="navigate"){e.respondWith(fetch(r).then(x=>{const y=x.clone();caches.open(C).then(c=>c.put(r,y));return x}).catch(()=>caches.match(r)))}});
self.addEventListener("notificationclick",e=>{e.notification.close();e.waitUntil(self.clients.matchAll({type:"window"}).then(l=>l.length?l[0].focus():self.clients.openWindow("./")))});
