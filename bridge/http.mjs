import http from 'node:http';
import {timingSafeEqual,createHash} from 'node:crypto';
import {username,GiftCounter,normalizeFollow,SessionQueue} from './core.mjs';
import {avatarPixels} from './avatar.mjs';
import {LikeCounter} from './likes.mjs';
import {DeliveryStore} from './delivery.mjs';
import {TikkiesBridge} from './tikkies.mjs';
export function createBridge({key,giftMap,connect,pixels=avatarPixels,databasePath,deliveryStore,tikkiesKey,tikkiesDatabasePath,tikkiesOptions}){
 if(typeof key!=='string'||key.length<32)throw new Error('MAGNET_KEY must contain at least 32 characters');
 const sessions=new Map();const attempts=new Map();let storage=deliveryStore??(databasePath?new DeliveryStore(databasePath):null);
 const tikkies=tikkiesKey?new TikkiesBridge({...tikkiesOptions,key:tikkiesKey,mapKey:key,pixels,databasePath:tikkiesDatabasePath??(databasePath&&databasePath!==':memory:'?databasePath+'.tikkies':':memory:')}):null;
 const idleMs=120000,retentionMs=24*60*60*1000;
 const stop=(s,remove=false)=>{s.closed=true;s.queue.wake?.();clearTimeout(s.timer);clearTimeout(s.connectTimer);clearTimeout(s.writeTimer);try{s.connection?.disconnect();}catch{};if(remove&&s.reliable)storage.remove(s.token);};
 const finish=s=>{if(s.ending){s.status=s.processing||s.failedWrites.size?'DRAINING':s.ending;s.queue.wake?.();}};
 function session(token,input,queue,lastPoll=Date.now()){
  return {token,username:input.username,asyncPortraits:input.protocol===2,gacha:input.gacha===true,follow:input.follow===true,rawLikes:input.rawLikes===true,reliable:input.reliable===true,queue,
   likes:new LikeCounter({raw:input.rawLikes===true}),gifts:new GiftCounter(queue.groups?.()),profiles:new Map(),received:new Set(),failedWrites:new Map(),observedGifts:new Map(),processing:0,unmapped:0,imageSkipped:0,lastPoll,retries:0,closed:false};
 }
 function start(s){
  if(s.closed)return;
  s.status=s.retries?'RETRYING':'CONNECTING';const c=connect(s.username);s.connection=c;
  const retry=()=>{if(s.closed||s.ending||s.connection!==c)return;s.connection=null;clearTimeout(s.connectTimer);try{c.disconnect();}catch{};if(++s.retries>5){s.ending='ERROR';finish(s);return;}s.status='RETRYING';s.timer=setTimeout(()=>start(s),Math.min(30000,1000*2**s.retries)+Math.random()*500);};
  c.on('error',()=>{s.lastError='CONNECTOR_ERROR';});c.on('disconnected',retry);
  c.on('streamEnd',()=>{s.ending='OFFLINE';finish(s);clearTimeout(s.timer);clearTimeout(s.connectTimer);try{c.disconnect();}catch{}});
  const remember=id=>{s.received.add(id);if(s.received.size>10000)s.received.delete(s.received.values().next().value);};
  const deliverNow=original=>{
   if(s.received.has(original.id)||s.reliable&&s.queue.has(original.id))return;
   const e={...original,sender:{...original.sender}};
   // Older published game bridges cannot consume a separate Portrait receipt.
   if(!s.asyncPortraits){
    remember(e.id);
    if(s.processing>=32){s.imageSkipped++;delete e.avatarUrl;s.queue.push(e);return;}
    s.processing++;
    Promise.resolve().then(()=>pixels(e.avatarUrl)).then(p=>{if(p)e.sender.pixels=p;}).catch(()=>{}).finally(()=>{
     s.processing--;delete e.avatarUrl;if(!s.closed)s.queue.push(e);finish(s);
    });
    return;
   }
   const url=e.avatarUrl;delete e.avatarUrl;
   const portraitId=typeof url==='string'?'p'+createHash('sha256').update(e.sender.handle+'\n'+url).digest('hex').slice(0,32):null;
   if(portraitId)e.sender.portraitId=portraitId;
   const cached=portraitId&&s.profiles.get(portraitId);
   if(cached?.pixels&&!s.reliable)e.sender.pixels=cached.pixels;
   if(!s.queue.push(e))return;remember(e.id); // Never mark received before a successful queue write.
   if(!portraitId||cached)return;
   if(s.processing>=32||s.profiles.size>=256){s.imageSkipped++;return;}
   const profile={};s.profiles.set(portraitId,profile);s.processing++;
   Promise.resolve().then(()=>pixels(url)).then(p=>{
    if(!p||s.closed)return;
    profile.pixels=p;
    deliver({id:'portrait:'+portraitId,kind:'Portrait',sender:{portraitId,pixels:p}});
   }).catch(()=>{}).finally(()=>{if(!profile.pixels)s.profiles.delete(portraitId);s.processing--;finish(s);});
  };
  const scheduleWrites=()=>{if(s.writeTimer||s.closed)return;s.writeTimer=setTimeout(()=>{s.writeTimer=null;let n=0;for(const e of s.failedWrites.values()){deliver(e);if(++n>=100)break;}if(s.failedWrites.size)scheduleWrites();},500);};
  const deliver=e=>{
   try{deliverNow(e);s.failedWrites.delete(e.id);finish(s);}
   catch{s.lastError='QUEUE_STORAGE_ERROR';s.failedWrites.set(e.id,e);scheduleWrites();}
  };
  c.on('gift',d=>{
   if(s.closed||s.ending||s.connection!==c)return;
   const giftName=d.giftDetails?.giftName??d.giftName;
   const coinCost=d.giftDetails?.diamondCount??d.diamondCount;
   const action=giftMap[String(d.giftId)];
   const supported=s.gacha||!['HeartMe','GoatBusker'].includes(action);
   if(d.giftId&&s.observedGifts.size<500)s.observedGifts.set(String(d.giftId),{id:String(d.giftId),name:giftName,coins:coinCost,mapped:supported?action??null:null});
   if(!supported){s.unmapped++;return;}
   const e=s.gifts.accept(d,giftMap);if(!e){if(!giftMap[String(d.giftId)])s.unmapped++;return;}
   deliver(e);
  });
  c.on('like',d=>{
   if(s.closed||s.ending||s.connection!==c)return;
   const e=s.likes.accept(d);if(e)deliver(e);
  });
  c.on('follow',d=>{
   if(s.closed||s.ending||s.connection!==c||!s.follow)return;
   const e=normalizeFollow(d);if(e)deliver(e);
  });
  s.connectTimer=setTimeout(retry,25000);
  Promise.resolve().then(()=>c.connect()).then(()=>{if(s.closed||s.ending||s.connection!==c){try{c.disconnect();}catch{};return;}clearTimeout(s.connectTimer);s.status='LIVE';s.retries=0;}).catch(e=>{
   if(s.closed||s.connection!==c)return;
   const signing=/Signature|SignAPI|Euler/i.test(e?.name??'');
   const offline=/UserOffline|isn't online|not live/i.test((e?.name??'')+' '+(e?.message??''));
   if(signing||offline){s.ending=signing?'SIGNING_REQUIRED':'OFFLINE';finish(s);clearTimeout(s.connectTimer);try{c.disconnect();}catch{}}else retry();
  });
 }
 const server=http.createServer(async(req,res)=>{
  const reply=(status,data)=>{res.writeHead(status,{'content-type':'application/json','cache-control':'no-store'});res.end(JSON.stringify(data));};
  try{
   const url=new URL(req.url,'http://localhost');
   if(url.pathname==='/health'&&req.method==='GET')return reply(200,{ok:true});
   if(url.pathname.startsWith('/tikkies/')){if(!tikkies)return reply(404,{error:'NOT_FOUND'});return await tikkies.handle(req,url,reply);}
   const supplied=Buffer.from(String(req.headers['x-magnet-key']??''));const expected=Buffer.from(key);
   if(supplied.length!==expected.length||!timingSafeEqual(supplied,expected))return reply(401,{error:'Unauthorized'});
   const token=req.headers['x-magnet-session'];if(typeof token!=='string'||!/^[a-zA-Z0-9-]{32,100}$/.test(token))return reply(400,{error:'INVALID_SESSION'});
   if(url.pathname==='/connect'&&req.method==='POST'){
    let body='';for await(const chunk of req){body+=chunk;if(body.length>4096)return reply(413,{error:'BODY_TOO_LARGE'});}
    const input=JSON.parse(body);const name=username(input.username);
    const now=Date.now();if(now-(attempts.get(token)??0)<3000)return reply(429,{error:'RATE_LIMIT'});
    if(sessions.size>=8&&!sessions.has(token))return reply(429,{error:'CAPACITY'});
    attempts.set(token,now);if(sessions.has(token))stop(sessions.get(token),true);
    const options={username:name,protocol:input.protocol,gacha:input.gacha===true,follow:input.follow===true,rawLikes:input.rawLikes===true,reliable:input.reliable===true&&input.protocol===2};
    let queue=new SessionQueue();
    if(options.reliable){storage??=new DeliveryStore();storage.remove(token);queue=storage.create(token,options);}
    const s=session(token,options,queue);sessions.set(token,s);start(s);
    return reply(202,{status:s.status,username:name,capabilities:{asyncPortraits:s.asyncPortraits,gacha:s.gacha,follow:s.follow,rawLikes:s.rawLikes,reliable:s.reliable}});
   }
   if(url.pathname==='/disconnect'&&req.method==='POST'){const s=sessions.get(token);if(s)stop(s,true);else storage?.remove(token);sessions.delete(token);return reply(200,{status:'DISCONNECTED'});}
   if(url.pathname==='/session/events'&&['GET','POST'].includes(req.method)){
    let jsonAcks;
    if(req.method==='POST'){
     let body='';for await(const chunk of req){body+=chunk;if(body.length>4096)return reply(413,{error:'BODY_TOO_LARGE'});}
     const input=JSON.parse(body);
     if(!input||typeof input!=='object'||Array.isArray(input)||Object.keys(input).some(k=>k!=='acks'))return reply(400,{error:'INVALID_REQUEST'});
     jsonAcks=input.acks===undefined?[]:input.acks;
    }
    const after=Number(url.searchParams.get('after')??0);if(!Number.isSafeInteger(after)||after<0)return reply(400,{error:'INVALID_CURSOR'});
    let s=sessions.get(token);
    if(!s){
     const old=storage?.recoverOne(token);
     if(old&&Date.now()-old.lastPoll<=retentionMs){
      if(sessions.size>=8)return reply(429,{error:'CAPACITY'});
      s=session(token,old,storage.queue(token));sessions.set(token,s);start(s);
     }else if(old)storage.remove(token);
    }
    if(!s)return reply(200,{status:'DISCONNECTED',events:[],cursor:0});s.lastPoll=Date.now();try{s.queue.touch?.();}catch{s.lastError='QUEUE_STORAGE_ERROR';}
    if(after>s.queue.seq)return reply(409,{error:'CURSOR_RESET'});
    let limit=20;
    if(s.reliable){
     limit=Math.min(100,Math.max(1,Number(url.searchParams.get('limit')??100)));if(!Number.isSafeInteger(limit))return reply(400,{error:'INVALID_LIMIT'});
     const acks=req.method==='POST'?jsonAcks:JSON.parse(String(req.headers['x-magnet-ack']??'[]'));
     if(!Array.isArray(acks)||acks.length>100||acks.some(n=>!Number.isSafeInteger(n)||n<1||n>s.queue.seq))return reply(400,{error:'INVALID_ACK'});
     s.queue.ack(acks);
    }
    let batch=s.queue.read(after,limit);
    if(s.reliable&&!batch.events.length&&!s.ending){const ms=Math.min(1000,Math.max(0,Number(url.searchParams.get('waitMs')??0)));if(Number.isFinite(ms)&&ms>0){await s.queue.wait(ms);if(s.closed)return reply(200,{status:'DISCONNECTED',events:[],cursor:0});batch=s.queue.read(0,limit);}}
    return reply(200,{status:s.status,username:s.username,...batch,hasMore:s.reliable?batch.pending>batch.events.length:batch.cursor<s.queue.seq,unmapped:s.unmapped,imageSkipped:s.imageSkipped,retryingWrites:s.failedWrites.size});
   }
   if(url.pathname==='/session/gifts'&&req.method==='GET'){
    const s=sessions.get(token);return reply(200,{gifts:s?[...s.observedGifts.values()]:[],source:'observed_live_events'});
   }
   reply(404,{error:'NOT_FOUND'});
  }catch{reply(400,{error:'INVALID_REQUEST'});}
 });
 for(const old of storage?.recover()??[]){const age=Date.now()-old.lastPoll;if(age>retentionMs){storage.remove(old.token);continue;}if(age>idleMs)continue;const s=session(old.token,old,storage.queue(old.token),old.lastPoll);sessions.set(old.token,s);start(s);}
 const sweep=setInterval(()=>{
  for(const [token,s] of sessions)if(Date.now()-s.lastPoll>idleMs){stop(s);sessions.delete(token);}
  for(const [token,time] of attempts)if(Date.now()-time>idleMs)attempts.delete(token);
  try{for(const old of storage?.recover()??[])if(Date.now()-old.lastPoll>retentionMs)storage.remove(old.token);storage?.prune();}catch{/* A temporary storage fault must not terminate the bridge. */}
 },30000);sweep.unref();
 let closing;
 return {server,close(){if(closing)return closing;clearInterval(sweep);tikkies?.close();for(const s of sessions.values())stop(s);closing=new Promise(resolve=>server.close(()=>{storage?.close();resolve();}));return closing;}};
}
