// Minimal WISMO gateway — dependency-free (Node built-in http only).
// Fans incoming requests to the running WISMO microservices and adds CORS.
// Routes:
//   /health            -> aggregate health of all downstream services
//   /orders/*          -> order-service      (3001)
//   /merchants/*       -> order-service      (3001)
//   /geo/*             -> geo-service        (3002)
//   /route/*           -> route-service      (3004)
//   /notify/*          -> notification-service(3003)
//   /pixel/*           -> pixel-service      (3007)
//   /are/*             -> are-service        (3005)
//   /bridge/*          -> scents-bridge      (8081)
//   /delphi/*          -> delphi-service     (5025)
import http from 'node:http';
import { request as httpRequest } from 'node:http';

const HOST = '0.0.0.0';
const PORT = Number(process.env.PORT || 3000);

const UPSTREAM = {
  '/orders':    { host: '127.0.0.1', port: 3001, rewrite: (p) => p.replace(/^\/orders/, '/v1/orders') },
  '/merchants': { host: '127.0.0.1', port: 3001, rewrite: (p) => p.replace(/^\/merchants/, '/v1/merchants') },
  '/geo':       { host: '127.0.0.1', port: 3002 },
  '/route':     { host: '127.0.0.1', port: 3004 },
  '/notify':    { host: '127.0.0.1', port: 3003 },
  '/pixel':     { host: '127.0.0.1', port: 3007 },
  '/are':       { host: '127.0.0.1', port: 3005 },
  '/bridge':    { host: '127.0.0.1', port: 8081 },
  '/delphi':    { host: '127.0.0.1', port: 5025 },
};

function resolveUpstream(path) {
  // longest prefix match
  let best = null;
  for (const p of Object.keys(UPSTREAM)) {
    if (path === p || path.startsWith(p + '/')) {
      if (!best || p.length > best.length) best = p;
    }
  }
  if (!best) return null;
  const u = { ...UPSTREAM[best], prefix: best };
  u.downstreamPath = u.rewrite ? u.rewrite(path) : path;
  return u;
}

function proxy(req, res, target) {
  const opts = {
    host: target.host, port: target.port, method: req.method,
    path: target.downstreamPath || '/', headers: { ...req.headers, host: `${target.host}:${target.port}` },
  };
  const proxyReq = httpRequest(opts, (proxyRes) => {
    res.writeHead(proxyRes.statusCode || 502, {
      ...proxyRes.headers,
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,PATCH,PUT,DELETE,OPTIONS',
      'Access-Control-Allow-Headers': 'content-type,authorization',
    });
    proxyRes.pipe(res);
  });
  proxyReq.on('error', () => {
    res.writeHead(502, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
    res.end(JSON.stringify({ error: 'upstream_unreachable', service: strip }));
  });
  req.pipe(proxyReq);
}

const server = http.createServer((req, res) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,PATCH,PUT,DELETE,OPTIONS',
      'Access-Control-Allow-Headers': 'content-type,authorization',
    });
    res.end();
    return;
  }

  if (req.url === '/health' || req.url.startsWith('/health?')) {
    const checks = Object.entries(UPSTREAM).map(([k, v]) => ({ route: k, host: v.host, port: v.port }));
    const results = [];
    let pending = checks.length;
    checks.forEach((c) => {
      const r = http.request({ host: c.host, port: c.port, path: '/health', method: 'GET', timeout: 1500 }, (pr) => {
        results.push({ route: c.route, port: c.port, status: pr.statusCode });
        pr.resume();
        if (--pending === 0) finish();
      });
      r.on('error', () => { results.push({ route: c.route, port: c.port, status: 0 }); if (--pending === 0) finish(); });
      r.on('timeout', () => { r.destroy(); results.push({ route: c.route, port: c.port, status: 0 }); if (--pending === 0) finish(); });
      r.end();
    });
    function finish() {
      const ok = results.filter((x) => x.status === 200).length;
      res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ status: 'ok', gateway: 'wismo-gateway', up: ok, total: results.length, services: results }));
    }
    return;
  }

  const target = resolveUpstream(req.url);
  if (!target) {
    res.writeHead(404, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
    res.end(JSON.stringify({ error: 'no_route', path: req.url }));
    return;
  }
  proxy(req, res, target);
});

server.listen(PORT, HOST, () => {
  console.log(`WISMO gateway listening on ${HOST}:${PORT}`);
});
