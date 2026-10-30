import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
const root = path.resolve(process.env.BIDVIBE_WEB_BUILD_DIR || '../../build/web');
if (!fs.existsSync(path.join(root, 'index.html'))) throw new Error('Flutter Web build missing: set BIDVIBE_WEB_BUILD_DIR.');
const types = {'.html':'text/html; charset=utf-8','.js':'application/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml','.css':'text/css','.ttf':'font/ttf','.woff2':'font/woff2','.map':'application/json'};
const server=http.createServer((req,res)=>{
 const relative=decodeURIComponent(new URL(req.url,'http://localhost').pathname).replace(/^\/+/, '');
 let file=path.resolve(root,relative || 'index.html');
 if(file!==root&&!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
 if(!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404).end('Not found');return;}
 res.setHeader('Cache-Control','no-store');res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');
 fs.createReadStream(file).pipe(res);
});
server.listen(Number(process.env.BIDVIBE_WEB_PORT||8886),'127.0.0.1',()=>console.log('BidVibe Flutter Web test server ready'));
for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>server.close(()=>process.exit()));

