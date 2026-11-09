export function username(value) {
 const s=String(value??'').trim().replace(/^@/,'').toLowerCase();
 if(!/^[a-z0-9_][a-z0-9_.]{0,23}$/.test(s)) throw new Error('INVALID_USERNAME');
 return s;
}
export function normalizeGift(d,map) {
 if((d.giftDetails?.giftType??d.giftType??d.gift?.type)===1 && !d.repeatEnd) return null;
 const giftId=map[String(d.giftId)];
 const quantity=Number(d.repeatCount??1);
 const raw=d.common?.msgId??d.msgId;
 if(!['Rose','Roses','Perfume','Bear'].includes(giftId)||!Number.isSafeInteger(quantity)||quantity<1||quantity>10000||!raw||typeof raw==='number'&&!Number.isSafeInteger(raw)) return null;
 const id='gift:'+String(raw);
 if(id.length>140)return null;
 const profile=normalizeSender(d.user??d);
 if(!profile)return null;
 return {id,giftId,quantity,...profile};
}
export function normalizeSender(u) {
 const handle=u.displayId||u.uniqueId;
 if(typeof handle!=='string'||!handle.length||handle.length>80)return null;
 let seed=0;for(const c of handle)seed=(Math.imul(seed,31)+c.charCodeAt(0))>>>0;
 return {sender:{handle,name:'@'+handle,seed:seed%2147483647},avatarUrl:u.avatarLarge?.urlList?.[0]??u.avatarMedium?.urlList?.[0]??u.avatarThumb?.urlList?.[0]??u.profilePicture?.urls?.[0]??u.profilePictureUrl};
}
export class SessionQueue {
 constructor(limit=2000){this.limit=limit;this.events=[];this.seq=0;this.seen=new Map();this.dropped=0;}
 push(e){if(this.seen.has(e.id))return false;this.seen.set(e.id,Date.now());this.events.push({...e,seq:++this.seq});if(this.events.length>this.limit){this.events.shift();this.dropped++;}for(const [id,t] of this.seen)if(Date.now()-t>3600000)this.seen.delete(id);return true;}
 read(after,limit=20){const gap=after<(this.events[0]?.seq??1)-1;const events=this.events.filter(e=>e.seq>after).slice(0,limit);return {events,cursor:events.at(-1)?.seq??after,gap,dropped:this.dropped};}
}
