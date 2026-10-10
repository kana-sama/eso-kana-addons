// Rebuild with Node and sharp available through NODE_PATH. Classic BGRA DDS for ESO.
const fs=require('fs'),path=require('path'),sharp=require('sharp');
(async()=>{
 for(const [name,source,stroke,opacity] of [
  ['hardmode','hardmode',2,1],['achievements-up','achievements',2,1],
  ['achievements-over','achievements',2.4,1],['achievements-down','achievements',2,0.65]]) {
 const svg=fs.readFileSync(path.join(__dirname,source+'.svg'),'utf8').replace('currentColor','#ffffff')
  .replace('stroke-width="2"',`stroke-width="${stroke}" opacity="${opacity}"`);
 const {data,info}=await sharp(Buffer.from(svg)).resize(64,64).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 for(let i=0;i<data.length;i+=4) { const r=data[i];data[i]=data[i+2];data[i+2]=r; }
 const h=Buffer.alloc(128);h.write('DDS ');
 const put=(offset,value)=>h.writeUInt32LE(value,offset);
 put(4,124);put(8,0x100f);put(12,info.height);put(16,info.width);put(20,info.width*4);
 put(76,32);put(80,0x41);put(88,32);put(92,0x00ff0000);put(96,0x0000ff00);
 put(100,0x000000ff);put(104,0xff000000);put(108,0x1000);
 fs.writeFileSync(path.join(__dirname,name+'.dds'),Buffer.concat([h,data]));
 console.log(name+'.dds: 64x64 BGRA');
 }
})().catch(error=>{console.error(error);process.exitCode=1;});
