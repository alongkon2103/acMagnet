import sharp from 'sharp';
export async function pixelsFromBuffer(input){
 const {data}=await sharp(input,{limitInputPixels:16000000}).rotate().resize(32,32,{fit:'cover'}).flatten({background:'#ffffff'}).removeAlpha().toColourspace('srgb').raw().toBuffer({resolveWithObject:true});
 return Array.from({length:1024},(_,i)=>data[i*3]*65536+data[i*3+1]*256+data[i*3+2]);
}
export function allowedAvatarUrl(value){try{const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password&&(!u.port||u.port==='443')&&['tiktokcdn.com','tiktokcdn-us.com','tiktokcdn-eu.com','byteoversea.com','ibytedtos.com','muscdn.com'].some(h=>u.hostname===h||u.hostname.endsWith('.'+h));}catch{return false;}}
const cache=new Map();
export async function avatarPixels(url){
 if(!allowedAvatarUrl(url))return null;
 const old=cache.get(url);if(old&&old.until>Date.now())return old.promise;
 const promise=(async()=>{
  const response=await fetch(url,{redirect:'error',signal:AbortSignal.timeout(5000)});
  if(!response.ok||!/^image\/(jpeg|png|webp)/i.test(response.headers.get('content-type')??''))throw new Error('AVATAR_FORMAT');
  const chunks=[];let length=0;for await(const chunk of response.body){length+=chunk.length;if(length>2000000)throw new Error('AVATAR_TOO_LARGE');chunks.push(chunk);}
  return pixelsFromBuffer(Buffer.concat(chunks));
 })().catch(()=>null);
 cache.set(url,{promise,until:Date.now()+300000});if(cache.size>256)cache.delete(cache.keys().next().value);return promise;
}
