// Tiny static server for testing the web export
const http=require('http'),fs=require('fs'),path=require('path');
const root=process.argv[2],port=+process.argv[3]||8060;
const types={'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
http.createServer((q,r)=>{let p=path.join(root,decodeURIComponent(q.url.split('?')[0]));if(p.endsWith(path.sep))p+='index.html';
fs.readFile(p,(e,d)=>{if(e){r.writeHead(404);return r.end('404')}r.writeHead(200,{'Content-Type':types[path.extname(p)]||'application/octet-stream'});r.end(d)})}).listen(port,()=>console.log('serving '+root+' on '+port));
