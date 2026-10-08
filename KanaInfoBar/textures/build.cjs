// Rebuild with Node and sharp available through NODE_PATH. Output: classic BGRA DDS.
const fs=require('fs'), path=require('path'), sharp=require('sharp');
(async()=>{
 for(const name of ['ping','fps','treasure','dps','inventory','messages','mail','notifications','durability']) {
  // Normalize the visible silhouette, not the SVG canvas. Native ESO textures
  // have different transparent margins and cannot share a nominal icon size.
  const silhouette=await sharp(path.join(__dirname,name+'.svg')).trim().resize(56,56,{fit:'inside'}).png().toBuffer();
  const {data,info}=await sharp({create:{width:64,height:64,channels:4,background:'#00000000'}})
   .composite([{input:silhouette,gravity:'centre'}]).raw().toBuffer({resolveWithObject:true});
  for(let i=0;i<data.length;i+=4) { const r=data[i]; data[i]=data[i+2]; data[i+2]=r; }
  const h=Buffer.alloc(128); h.write('DDS ');
  const put=(offset,value)=>h.writeUInt32LE(value,offset);
  put(4,124); put(8,0x100f); put(12,info.height); put(16,info.width); put(20,info.width*4);
  put(76,32); put(80,0x41); put(88,32); put(92,0x00ff0000); put(96,0x0000ff00);
  put(100,0x000000ff); put(104,0xff000000); put(108,0x1000);
  fs.writeFileSync(path.join(__dirname,name+'.dds'),Buffer.concat([h,data]));
  console.log(name+'.dds: '+info.width+'x'+info.height+' BGRA');
 }
})();
