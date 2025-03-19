'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "b96092e2d3e0bac67df1aa8bceea8ee1",
"version.json": "11e1a177d57c5da2bc6e3a6acc3010f4",
"index.html": "982859e7b42c5a9264df3694f633f887",
"/": "982859e7b42c5a9264df3694f633f887",
"main.dart.js": "78fb0931993f0c67d37b82ed288734ac",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"manifest.json": "3fc29f9294b755bca0378065b89e216e",
"assets/AssetManifest.json": "d650fb31d1d877218cf1c3200536fedb",
"assets/NOTICES": "a7dfba35fbff7cb6d665236c4fe6cf64",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "cf742a5a3e9b245f471b619681facd01",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "08c7bd529e69cb2210b4ef00b608392f",
"assets/fonts/MaterialIcons-Regular.otf": "c9a2e5183c3ee66b275f3ec6a2d36ce4",
"assets/assets/images/T4LLogo.png": "b98988b829d9359533f701dd4bafbf86",
"assets/assets/logos/houston_texans.png": "774f66c3e1d37465037c48e678204a87",
"assets/assets/logos/carolina_panthers.png": "8427c63dc9a70eb45766517dd88ec79a",
"assets/assets/logos/new_york_giants.png": "d476c2eb38aacd4f11a38dc35ab9302d",
"assets/assets/logos/cleveland_browns.png": "0727aea99e6bdc12378b27d587c2417d",
"assets/assets/logos/cincinnati_bengals.png": "9d8f46cdb19ef72131af8004999e10c8",
"assets/assets/logos/new_orleans_saints.png": "0e18ee7b3ec8e512404d4bf9f6a5834a",
"assets/assets/logos/tennessee_titans.png": "6b2bb9e595ee6e635a3dc8944beaaaa4",
"assets/assets/logos/tampa_bay_buccaneers.png": "a9cff7e46d799412fb4893f72bcc68fb",
"assets/assets/logos/buffalo_bills.png": "729797e1cde0f288e17dc589b0b549ed",
"assets/assets/logos/nfc.png": "a31b52f052e39b01931379efe109294e",
"assets/assets/logos/pittsbourg_steelers.png": "006878b5a324f697e4fe921eff37b4c8",
"assets/assets/logos/jacksonville_jaguars.png": "a99447992bcdb881430a32bf5f51d49d",
"assets/assets/logos/los_angeles_rams.png": "9a870772b1f592d9aeab5daf480f477f",
"assets/assets/logos/los_angeles_chargers.png": "b90a2a24a0a0cd21b00a5b96276eb2b2",
"assets/assets/logos/dallas_cowboys.png": "e3d338cf4a9279cf179e4dc28ed781f9",
"assets/assets/logos/indianapolis_colts.png": "83aaa03ed09190461f49f32f5ed10876",
"assets/assets/logos/denver_broncos.png": "d7e0b983f83c34ee4c03e3a1b2796624",
"assets/assets/logos/philadelphia_eagles.png": "d5cf55276f2fd1495ed59945e6d08f37",
"assets/assets/logos/chicago_bears.png": "a630628ad6a4e4f8b72b9678934437cd",
"assets/assets/logos/minnesota_vikings.png": "68e182f4a05f9e3e888a1ea3e146993b",
"assets/assets/logos/kansas_city_chiefs.png": "8b6d8ac87d0f1245a8b739b5d2b0f435",
"assets/assets/logos/new_york_jets.png": "e4b45e8414d76d1af0b074c29d274930",
"assets/assets/logos/nfl.png": "87d37e8cee7d4a8ad3c1e78608652760",
"assets/assets/logos/san_francisco_49ers.png": "8b9c568e3304668763d5d27837585d8a",
"assets/assets/logos/arizona_cardinals.png": "f2f2f3560594a8ecb517d28ae0a4471a",
"assets/assets/logos/Green_bay_packers.png": "05c8e911391d1df7f61e42f541276835",
"assets/assets/logos/seattle_seahawks.png": "9fc5d08f80b0bd3540f3c2fcbbebf6f8",
"assets/assets/logos/detroit_lions.png": "58c5bf5721e523482d830173c57be66a",
"assets/assets/logos/new_england_patriots.png": "3510ed1249784e05b6d8b79bdb627652",
"assets/assets/logos/atlanta_falcons.png": "2bf892d302e990f990d602a97ebe6edf",
"assets/assets/logos/afc.png": "b62358e224fac2a787a5f54127adb533",
"assets/assets/logos/las_vegas_raiders.png": "9e475d64b76a65df50498023e4d18950",
"assets/assets/logos/washington_commanders.png": "27a5a40b711d0581e878e325f1183353",
"assets/assets/logos/miami_dolphins.png": "85ac5a972ca18e3f1a1f3c85cd656358",
"assets/assets/logos/baltimore_ravens.png": "9e578253010281bb540b27d3a766d208",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
