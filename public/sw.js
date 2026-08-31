// GREEN GOLD service worker — كاش للأوفلاين الجزئي
const CACHE = "green-gold-v1";
const PRECACHE = ["/", "/icon.svg", "/icon-192.png", "/manifest.webmanifest"];

self.addEventListener("install", (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(PRECACHE)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  // الصور: كاش أولًا (تجربة سريعة عند ضعف الإنترنت)
  if (e.request.method === "GET" && (url.pathname.startsWith("/images-ppt") || /\.(png|jpg|jpeg|webp|svg)$/i.test(url.pathname))) {
    e.respondWith(
      caches.match(e.request).then(
        (hit) =>
          hit ||
          fetch(e.request).then((res) => {
            const copy = res.clone();
            caches.open(CACHE).then((c) => c.put(e.request, copy));
            return res;
          }).catch(() => caches.match("/icon.svg"))
      )
    );
    return;
  }
  // API: شبكة أولًا دائمًا (لا نكذب على العميل بشأن الدفع)
  if (url.pathname.startsWith("/api/")) return;
  // الباقي: شبكة مع رجوع للكاش
  if (e.request.method === "GET") {
    e.respondWith(
      fetch(e.request)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(e.request, copy));
          return res;
        })
        .catch(() => caches.match(e.request).then((h) => h || caches.match("/")))
    );
  }
});
