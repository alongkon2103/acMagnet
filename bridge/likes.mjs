import {normalizeSender} from './core.mjs';
export class LikeCounter {
 constructor(){this.remainders=new Map();this.seen=new Set();}
 accept(d){
  const count=d.count;
  const raw=d.common?.msgId??d.msgId;
  if(!Number.isSafeInteger(count)||count<1||count>500000||!raw||typeof raw==='number'&&!Number.isSafeInteger(raw))return null;
  const id='like:'+String(raw);
  const profile=normalizeSender(d.user??d);
  if(!profile||id.length>140||this.seen.has(id))return null;
  this.seen.add(id);if(this.seen.size>100000)this.seen.delete(this.seen.values().next().value);
  const handle=profile.sender.handle.toLowerCase();
  const total=(this.remainders.get(handle)??0)+count;
  this.remainders.delete(handle);this.remainders.set(handle,total%50);
  if(this.remainders.size>10000)this.remainders.delete(this.remainders.keys().next().value);
  const quantity=Math.floor(total/50);
  return quantity?{id,giftId:'Likes',quantity,...profile}:null;
 }
}
