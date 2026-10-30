import fs from 'node:fs';import zlib from 'node:zlib';
function crc(b){let c=0xffffffff;for(const x of b){c^=x;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^0xffffffff)>>>0;}
function chunk(type,data){const t=Buffer.from(type);const size=Buffer.alloc(4);size.writeUInt32BE(data.length);const sum=Buffer.alloc(4);sum.writeUInt32BE(crc(Buffer.concat([t,data])));return Buffer.concat([size,t,data,sum]);}
const header=Buffer.alloc(13);header.writeUInt32BE(64);header.writeUInt32BE(64,4);header[8]=8;header[9]=2;
const pixels=Buffer.alloc((64*3+1)*64);for(let y=0;y<64;y++)for(let x=0;x<64;x++){const i=y*(64*3+1)+1+x*3;pixels[i]=35;pixels[i+1]=90;pixels[i+2]=180;}
fs.mkdirSync('assets',{recursive:true});fs.writeFileSync('assets/e2e-product.png',Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',zlib.deflateSync(pixels)),chunk('IEND',Buffer.alloc(0))]));
