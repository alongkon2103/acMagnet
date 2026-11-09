import sharp from 'sharp';
import {fileURLToPath} from 'node:url';

// Shared analytic opacity mask, not a screenshot or a separate texture for each block.
const size=64;
const rgba=Buffer.alloc(size*size*4);
for(let y=0;y<size;y++)for(let x=0;x<size;x++){
  const u=(x+.5-size/2)/(size/2),v=(y+.5-size/2)/(size/2);
  const r=u*u+v*v,o=(y*size+x)*4;
  rgba[o]=38;rgba[o+1]=51;rgba[o+2]=40;
  rgba[o+3]=Math.round(110*Math.exp(-2.8*r)*Math.max(0,1-r/1.8));
}
await sharp(rgba,{raw:{width:size,height:size,channels:4}}).png().toFile(fileURLToPath(new URL('contact-shadow.png',import.meta.url)));
