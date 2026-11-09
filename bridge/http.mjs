import http from 'node:http';
import {timingSafeEqual} from 'node:crypto';
import {username,normalizeGift,SessionQueue} from './core.mjs';
import {avatarPixels} from './avatar.mjs';
export function createBridge({key,giftMap,connect,pixels=avatarPixels}){
 if(typeof key!=='string'||key.length<32)throw new Error('MAGNET_KEY must contain at least 32 characters');
 const sessions=new Map();const attempts=new Map();
 const stop=s=>{s.closed=true;clearTimeout(s.timer);clearTimeout(s.connectTimer);try{s.connection?.disconnect();}catch{}};
 function start(s){
  if(s.closed)return;
  s.status=s.retries?'RETRYING':'CONNECTING';const c=connect(s.username);s.connection=c;
  const retry=()=>{if(s.closed||s.ending||s.connection!==c)return;s.connection=null;clearTimeout(s.connectTimer);try{c.disconnect();}catch{};if(++s.retries>5){s.ending='ERROR';s.status=s.processing?'DRAINING':'ERROR';return;}s.status='RETRYING';s.timer=setTimeout(()=>start(s),Math.min(30000,1000*2**s.retries)+Math.random()*500);};
  c.on('error',()=>{s.lastError='CONNECTOR_ERROR';});c.on('disconnected',retry);
  c.on('streamEnd',()=>{s.ending='OFFLINE';s.status=s.processing?'DRAINING':'OFFLINE';clearTimeout(s.timer);clearTimeout(s.connectTimer);try{c.disconnect();}catch{}});
  c.on('gift',d=>{
   if(s.closed||s.ending||s.connection!==c)return;
   if((d.giftDetails?.giftType??d.giftType??d.gift?.type)===1&&!d.repeatEnd)return;
   const giftName=d.giftDetails?.giftName??d.giftName;
   const coinCost=d.giftDetails?.diamondCount??d.diamondCount;
   if(d.giftId&&s.observedGifts.size<500)s.observedGifts.set(String(d.giftId),{id:String(d.giftId),name:giftName,coins:coinCost,mapped:giftMap[String(d.giftId)]??null});
   const e=normalizeGift(d,giftMap);if(!e){s.unmapped++;return;}
   if(s.received.has(e.id))return;s.received.add(e.id);if(s.received.size>10000)s.received.delete(s.received.values().next().value);
   if(s.processing>=32){s.imageSkipped++;delete e.avatarUrl;s.queue.push(e);return;}
   s.processing++;
   // Serialize only completion delivery, not downloading: stable event IDs make retries safe.
   Promise.resolve(pixels(e.avatarUrl)).then(p=>{if(p)e.sender.pixels=p;}).catch(()=>{}).finally(()=>{s.processing--;delete e.avatarUrl;if(!s.closed)s.queue.push(e);if(s.ending&&s.processing===0)s.status=s.ending;});
  });
  s.connectTimer=setTimeout(retry,25000);
  Promise.resolve().then(()=>c.connect()).then(()=>{if(s.closed||s.ending||s.connection!==c){try{c.disconnect();}catch{};return;}clearTimeout(s.connectTimer);s.status='LIVE';s.retries=0;}).catch(e=>{
   if(s.closed||s.connection!==c)return;
   const signing=/Signature|SignAPI|Euler/i.test(e?.name??'');
   const offline=/UserOffline|isn't online|not live/i.test((e?.name??'')+' '+(e?.message??''));
   if(signing||offline){s.ending=signing?'SIGNING_REQUIRED':'OFFLINE';s.status=s.processing?'DRAINING':s.ending;clearTimeout(s.connectTimer);try{c.disconnect();}catch{}}else retry();
  });
 }
 const server=http.createServer(async(req,res)=>{
  const reply=(status,data)=>{res.writeHead(status,{'content-type':'application/json','cache-control':'no-store'});res.end(JSON.stringify(data));};
  try{
   const url=new URL(req.url,'http://localhost');
   if(url.pathname==='/health'&&req.method==='GET')return reply(200,{ok:true});
   const supplied=Buffer.from(String(req.headers['x-magnet-key']??''));const expected=Buffer.from(key);
   if(supplied.length!==expected.length||!timingSafeEqual(supplied,expected))return reply(401,{error:'Unauthorized'});
   const token=req.headers['x-magnet-session'];if(typeof token!=='string'||!/^[a-zA-Z0-9-]{32,100}$/.test(token))return reply(400,{error:'INVALID_SESSION'});
   if(url.pathname==='/connect'&&req.method==='POST'){
    let body='';for await(const chunk of req){body+=chunk;if(body.length>4096)return reply(413,{error:'BODY_TOO_LARGE'});}
    const name=username(JSON.parse(body).username);
    const now=Date.now();if(now-(attempts.get(token)??0)<3000)return reply(429,{error:'RATE_LIMIT'});
    if(sessions.size>=8&&!sessions.has(token))return reply(429,{error:'CAPACITY'});
    attempts.set(token,now);if(sessions.has(token))stop(sessions.get(token));
    const s={username:name,queue:new SessionQueue(),received:new Set(),observedGifts:new Map(),processing:0,unmapped:0,imageSkipped:0,lastPoll:now,retries:0,closed:false};sessions.set(token,s);start(s);
    return reply(202,{status:s.status,username:name});
   }
   if(url.pathname==='/disconnect'&&req.method==='POST'){const s=sessions.get(token);if(s)stop(s);sessions.delete(token);return reply(200,{status:'DISCONNECTED'});}
   if(url.pathname==='/session/events'&&req.method==='GET'){
    const after=Number(url.searchParams.get('after')??0);if(!Number.isSafeInteger(after)||after<0)return reply(400,{error:'INVALID_CURSOR'});
    const s=sessions.get(token);if(!s)return reply(200,{status:'DISCONNECTED',events:[],cursor:0});s.lastPoll=Date.now();
    if(after>s.queue.seq)return reply(409,{error:'CURSOR_RESET'});
    const batch=s.queue.read(after);
    return reply(200,{status:s.status,username:s.username,...batch,hasMore:batch.cursor<s.queue.seq,unmapped:s.unmapped,imageSkipped:s.imageSkipped});
   }
   if(url.pathname==='/session/gifts'&&req.method==='GET'){
    const s=sessions.get(token);return reply(200,{gifts:s?[...s.observedGifts.values()]:[],source:'observed_live_events'});
   }
   reply(404,{error:'NOT_FOUND'});
  }catch{reply(400,{error:'INVALID_REQUEST'});}
 });
 const sweep=setInterval(()=>{for(const [token,s] of sessions)if(Date.now()-s.lastPoll>120000){stop(s);sessions.delete(token);}for(const [token,time] of attempts)if(Date.now()-time>120000)attempts.delete(token);},30000);sweep.unref();
 return {server,close(){clearInterval(sweep);for(const s of sessions.values())stop(s);server.close();}};
}
