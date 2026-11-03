// Serveur d'aperçu : sert la version web compilée (build/web) et relaie les appels
// vers les sites de mangas via /proxy (le navigateur les bloque sinon : CORS, Referer).
// Dans l'application tablette, ce relais est inutile : les appels partent directement.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../build/web');
const port = Number(process.env.PORT || 5173);
const browserUa =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36';
const appUa = 'DensetsuReading/0.1';

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.frag': 'application/octet-stream',
  '.bin': 'application/octet-stream',
};

async function proxy(url, req, res) {
  const target = url.searchParams.get('url');
  if (!target || !/^https?:\/\//.test(target)) {
    res.writeHead(400).end('url manquante');
    return;
  }
  const host = new URL(target).hostname;
  const headers = {
    'user-agent': host.endsWith('mangadex.org') ? appUa : browserUa,
    accept: req.headers.accept || '*/*',
    'accept-language': 'fr-FR,fr;q=0.9,en;q=0.8',
  };
  const referer = url.searchParams.get('referer');
  if (referer) headers.referer = referer;
  try {
    const upstream = await fetch(target, { headers, redirect: 'follow' });
    const body = Buffer.from(await upstream.arrayBuffer());
    res.writeHead(upstream.status, {
      'content-type': upstream.headers.get('content-type') || 'application/octet-stream',
      'access-control-allow-origin': '*',
      'cache-control': upstream.ok ? 'public, max-age=900' : 'no-store',
    });
    res.end(body);
  } catch (error) {
    res.writeHead(502, { 'access-control-allow-origin': '*' }).end(String(error));
  }
}

function serveStatic(url, res) {
  let file = path.join(root, decodeURIComponent(url.pathname));
  if (!file.startsWith(root)) {
    res.writeHead(403).end();
    return;
  }
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(root, 'index.html');
  if (!fs.existsSync(file)) {
    res.writeHead(503, { 'content-type': 'text/plain; charset=utf-8' }).end('Compilation en cours…');
    return;
  }
  const ext = path.extname(file);
  const fresh = ext === '.html' || file.endsWith('flutter_bootstrap.js') || file.endsWith('main.dart.js');
  res.writeHead(200, {
    'content-type': types[ext] || 'application/octet-stream',
    'cache-control': fresh ? 'no-cache' : 'public, max-age=3600',
  });
  fs.createReadStream(file).pipe(res);
}

http
  .createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost');
    if (url.pathname === '/proxy') return proxy(url, req, res);
    return serveStatic(url, res);
  })
  .listen(port, () => console.log(`Densetsu Reading : http://localhost:${port}`));
