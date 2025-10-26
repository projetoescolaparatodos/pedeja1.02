// 🔧 Proxy CORS temporário para desenvolvimento
// Execute: node cors-proxy.js
// Depois use: http://localhost:8080/api/... no app

const http = require('http');
const https = require('https');
const url = require('url');

const PORT = 8080;
const TARGET_API = 'https://api-pedeja.vercel.app';

const server = http.createServer((req, res) => {
  // Headers CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');
  res.setHeader('Access-Control-Allow-Credentials', 'true');

  // Preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Proxy da requisição
  const targetUrl = TARGET_API + req.url;
  console.log(`[${req.method}] ${targetUrl}`);

  const options = {
    method: req.method,
    headers: req.headers,
  };

  delete options.headers['host'];

  const proxyReq = https.request(targetUrl, options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    console.error('❌ Erro no proxy:', err.message);
    res.writeHead(500);
    res.end(JSON.stringify({ error: 'Erro no proxy', details: err.message }));
  });

  req.pipe(proxyReq);
});

server.listen(PORT, () => {
  console.log(`\n🚀 Proxy CORS rodando em http://localhost:${PORT}`);
  console.log(`📡 Redirecionando para: ${TARGET_API}`);
  console.log(`\n💡 No Flutter, use: http://localhost:${PORT}/api/...`);
  console.log(`\nExemplo: http://localhost:${PORT}/api/auth/firebase-token\n`);
});
