import {DatabaseSync} from 'node:sqlite';
import {createHash,randomUUID,timingSafeEqual} from 'node:crypto';
import {mkdirSync,chmodSync} from 'node:fs';
import {dirname} from 'node:path';
import {allowedAvatarUrl,avatarPixels} from './avatar.mjs';
import {username} from './core.mjs';

export const tikkiesEffects=Object.freeze(['Rose','Roses','Friendship','Donut','Bear','HeartMe','GoatBusker','HelpGacha','Follow','Likes','Remove','Speed','Range','Storm','Shrink','WinAdd','WinRemove']);
const magnetGameId='ce4eb329-7ae9-43d4-bf6a-cfde0fe3cee7';
const commandId=value=>typeof value==='string'&&/^[A-Za-z][A-Za-z0-9_.:-]{0,79}$/.test(value);
const gameId=value=>{if(value===undefined)return magnetGameId;if(typeof value!=='string'||!/^[-A-Za-z0-9_]{1,160}$/.test(value))fail('INVALID_GAME');return value;};
const roomKey=(game,room)=>JSON.stringify([game,room]);
const account=value=>typeof value==='string'&&/^[1-9]\d{0,19}$/.test(value);
const sessionId=value=>typeof value==='string'&&/^[a-zA-Z0-9-]{32,100}$/.test(value);
const priority=e=>e.kind==='Portrait'||['Friendship','Donut','Shrink','WinAdd','WinRemove'].includes(e.effect)?0:e.effect==='Likes'?3:e.effect==='Follow'?2:1;
const sameKey=(actual,expected)=>{const a=Buffer.from(String(actual??'')),b=Buffer.from(expected);return a.length===b.length&&timingSafeEqual(a,b);};
const fail=(code,status=400)=>{throw Object.assign(new Error(code),{code,status});};
const validPixels=p=>Array.isArray(p)&&[256,1024].includes(p.length)&&p.every(v=>Number.isInteger(v)&&v>=0&&v<=0xffffff);

function normalizeEvent(input,bindingId){
 if(!input||typeof input!=='object'||Array.isArray(input))fail('INVALID_EVENT');
 const {id,effect,quantity,sender,triggerType,test}=input;
 if(typeof id!=='string'||!/^[\x21-\x7e]{1,100}$/.test(id)||id.startsWith('portrait:'))fail('INVALID_RECEIPT');
 if(!commandId(effect))fail('INVALID_EFFECT');
 if(!Number.isSafeInteger(quantity)||quantity<1||quantity>10000)fail('INVALID_QUANTITY');
 if(!sender||typeof sender!=='object'||typeof sender.name!=='string'||!sender.name.trim()||Buffer.byteLength(sender.name)>160||/[\x00-\x1f\x7f]/.test(sender.name))fail('INVALID_SENDER');
 const clean={name:sender.name};
 if(sender.uniqueId!==undefined){if(typeof sender.uniqueId!=='string'||!/^[a-zA-Z0-9_.]{1,80}$/.test(sender.uniqueId))fail('INVALID_SENDER');clean.uniqueId=sender.uniqueId;}
 if(sender.userId!==undefined){if(typeof sender.userId!=='string'||!/^\d{1,40}$/.test(sender.userId))fail('INVALID_SENDER');clean.userId=sender.userId;}
 clean.handle=clean.uniqueId??clean.userId??'viewer';
 if(sender.seed!==undefined&&(!Number.isSafeInteger(sender.seed)||Math.abs(sender.seed)>2147483646))fail('INVALID_SENDER');
 clean.seed=sender.seed??(parseInt(createHash('sha256').update(clean.handle).digest('hex').slice(0,8),16)%2147483647);
 let url;
 if(sender.avatarUrl!==undefined){
  if(typeof sender.avatarUrl!=='string'||sender.avatarUrl.length>2048||!allowedAvatarUrl(sender.avatarUrl))fail('INVALID_AVATAR');
  url=sender.avatarUrl;clean.portraitId='p'+createHash('sha256').update(bindingId+'\n'+clean.handle+'\n'+url).digest('hex').slice(0,32);
 }
 if(triggerType!==undefined&&(typeof triggerType!=='string'||!/^[a-zA-Z][a-zA-Z0-9_-]{0,31}$/.test(triggerType)))fail('INVALID_TRIGGER');
 if(test!==undefined&&typeof test!=='boolean')fail('INVALID_TEST');
 const event={id,effect,giftId:effect,quantity,sender:clean,...(triggerType===undefined?{}:{triggerType}),...(test===undefined?{}:{test})};
 // Hash normalized, executable meaning plus the source URL. Property order is deterministic.
 const fingerprint=createHash('sha256').update(JSON.stringify({event,url:url??null})).digest('hex');
 return {event,url,fingerprint};
}

function normalizeGame(input,id){
 if(!input||typeof input!=='object'||Array.isArray(input)||Object.keys(input).some(k=>!['placeIds','universeId','commands','credentialHash'].includes(k)))fail('INVALID_GAME');
 const {placeIds,universeId,commands,credentialHash}=input;
 if(!Array.isArray(placeIds)||placeIds.length<1||placeIds.length>100||placeIds.some(v=>!account(v))||new Set(placeIds).size!==placeIds.length||
  universeId!==null&&!account(universeId)||!Array.isArray(commands)||commands.length>1000||commands.some(v=>!commandId(v))||new Set(commands).size!==commands.length||
  !(credentialHash===null&&id===magnetGameId)&&!(typeof credentialHash==='string'&&/^[a-fA-F0-9]{64}$/.test(credentialHash)))fail('INVALID_GAME');
 return {placeIds,universeId,commands,credentialHash:credentialHash?.toLowerCase()??null};
}

const bindingTable=name=>`CREATE TABLE ${name}(id TEXT PRIMARY KEY,game_id TEXT NOT NULL DEFAULT '${magnetGameId}',subject TEXT NOT NULL,owner TEXT NOT NULL,channel TEXT NOT NULL,expires INTEGER NOT NULL,enabled INTEGER NOT NULL,room_id TEXT,generation INTEGER NOT NULL DEFAULT 0,seq INTEGER NOT NULL DEFAULT 0,expired_tests INTEGER NOT NULL DEFAULT 0,portrait_fallbacks INTEGER NOT NULL DEFAULT 0,created INTEGER NOT NULL,last_activity INTEGER NOT NULL DEFAULT 0,UNIQUE(game_id,subject,owner,channel))`;
const roomTable=name=>`CREATE TABLE ${name}(id TEXT NOT NULL,game_id TEXT NOT NULL DEFAULT '${magnetGameId}',players TEXT NOT NULL,native_busy INTEGER NOT NULL,online INTEGER NOT NULL,last_seen INTEGER NOT NULL,PRIMARY KEY(game_id,id))`;

/** Separate external transport: no native TikTok session or connector is created here. */
export class TikkiesBridge{
 constructor({key,mapKey,databasePath=':memory:',pixels=avatarPixels,now=Date.now,maxPending=50000,maxTotalPending=200000,maxReceipts=250000,maxPortraits=256,maxBindings=512,maxRooms=512,roomTimeoutMs=30000}){
  if(typeof key!=='string'||key.length<32)throw Error('MAGNET_TIKKIES_KEY must contain at least 32 characters');
  this.key=key;this.mapKey=mapKey;this.pixels=pixels;this.now=now;
  Object.assign(this,{maxPending,maxTotalPending,maxReceipts,maxPortraits,maxBindings,maxRooms,roomTimeoutMs});
  this.waiters=new Map();this.offers=new Map();this.working=new Set();this.closed=false;
  if(databasePath!==':memory:')mkdirSync(dirname(databasePath),{recursive:true,mode:0o700});
  this.db=new DatabaseSync(databasePath);if(databasePath!==':memory:')chmodSync(databasePath,0o600);
  this.db.exec(`PRAGMA journal_mode=WAL;PRAGMA synchronous=FULL;PRAGMA foreign_keys=ON;
   ${roomTable('IF NOT EXISTS tk_rooms')};
   ${bindingTable('IF NOT EXISTS tk_bindings')};
   CREATE TABLE IF NOT EXISTS tk_games(id TEXT PRIMARY KEY,place_ids TEXT NOT NULL,universe_id TEXT,commands TEXT NOT NULL,credential_hash TEXT);
   CREATE TABLE IF NOT EXISTS tk_events(binding TEXT NOT NULL REFERENCES tk_bindings(id),seq INTEGER NOT NULL,id TEXT NOT NULL,priority INTEGER NOT NULL,payload TEXT NOT NULL,received INTEGER NOT NULL,test_expires INTEGER,portrait_id TEXT,PRIMARY KEY(binding,seq),UNIQUE(binding,id));
   CREATE INDEX IF NOT EXISTS tk_event_priority ON tk_events(binding,priority,seq);
   CREATE TABLE IF NOT EXISTS tk_receipts(binding TEXT NOT NULL REFERENCES tk_bindings(id),id TEXT NOT NULL,fingerprint TEXT NOT NULL,PRIMARY KEY(binding,id));
   CREATE TABLE IF NOT EXISTS tk_portraits(binding TEXT NOT NULL REFERENCES tk_bindings(id),id TEXT NOT NULL,url TEXT NOT NULL,pixels TEXT,next_attempt INTEGER NOT NULL DEFAULT 0,attempts INTEGER NOT NULL DEFAULT 0,offered_generation INTEGER NOT NULL DEFAULT -1,created INTEGER NOT NULL,last_used INTEGER NOT NULL DEFAULT 0,test_until INTEGER,PRIMARY KEY(binding,id));
   UPDATE tk_rooms SET online=0;
   UPDATE tk_bindings SET room_id=NULL,generation=generation+1 WHERE room_id IS NOT NULL;`);
  if(!this.db.prepare('PRAGMA table_info(tk_bindings)').all().some(column=>column.name==='last_activity')){
   this.db.exec('ALTER TABLE tk_bindings ADD COLUMN last_activity INTEGER NOT NULL DEFAULT 0');
   // Existing databases receive a fresh grace period; pre-upgrade activity is unknown.
   this.db.prepare('UPDATE tk_bindings SET last_activity=?').run(this.now());
  }
  if(!this.db.prepare('PRAGMA table_info(tk_bindings)').all().some(column=>column.name==='portrait_fallbacks'))this.db.exec('ALTER TABLE tk_bindings ADD COLUMN portrait_fallbacks INTEGER NOT NULL DEFAULT 0');
  if(!this.db.prepare('PRAGMA table_info(tk_portraits)').all().some(column=>column.name==='last_used')){
   this.db.exec('ALTER TABLE tk_portraits ADD COLUMN last_used INTEGER NOT NULL DEFAULT 0;UPDATE tk_portraits SET last_used=created;');
  }
  if(!this.db.prepare('PRAGMA table_info(tk_events)').all().some(column=>column.name==='portrait_id')){
   this.db.exec("ALTER TABLE tk_events ADD COLUMN portrait_id TEXT;UPDATE tk_events SET portrait_id=json_extract(payload,'$.sender.portraitId');");
  }
  this.migrateProductScope();
  this.db.exec('CREATE UNIQUE INDEX IF NOT EXISTS tk_room_owner ON tk_bindings(game_id,room_id) WHERE room_id IS NOT NULL;CREATE INDEX IF NOT EXISTS tk_binding_subject ON tk_bindings(subject);CREATE INDEX IF NOT EXISTS tk_event_portrait ON tk_events(binding,portrait_id)');
  this.db.prepare('INSERT OR IGNORE INTO tk_games(id,place_ids,universe_id,commands,credential_hash) VALUES(?,?,?,?,NULL)').run(magnetGameId,JSON.stringify(['113965026399564']),'10775380860',JSON.stringify(tikkiesEffects));
  this.statements=new Map();
  this.timer=setInterval(()=>{if(!this.closed){try{this.reconcile();this.pumpPortraits();}catch{/* A storage fault is retried without acknowledging new work. */}}},250);this.timer.unref();
  queueMicrotask(()=>this.pumpPortraits());
 }
 migrateProductScope(){
  const bindings=!this.db.prepare('PRAGMA table_info(tk_bindings)').all().some(c=>c.name==='game_id');
  const rooms=!this.db.prepare('PRAGMA table_info(tk_rooms)').all().some(c=>c.name==='game_id');
  if(!bindings&&!rooms)return;
  // SQLite cannot remove the old UNIQUE constraint in place. Rebuild only these
  // parent tables, retaining every ID/sequence and all child queue/history rows.
  this.db.exec('PRAGMA foreign_keys=OFF;BEGIN IMMEDIATE');
  try{
   if(bindings){
    this.db.exec(`${bindingTable('tk_bindings_scoped')};
     INSERT INTO tk_bindings_scoped(id,subject,owner,channel,expires,enabled,room_id,generation,seq,expired_tests,portrait_fallbacks,created,last_activity)
      SELECT id,subject,owner,channel,expires,enabled,room_id,generation,seq,expired_tests,portrait_fallbacks,created,last_activity FROM tk_bindings;
     DROP TABLE tk_bindings;ALTER TABLE tk_bindings_scoped RENAME TO tk_bindings;`);
   }
   if(rooms)this.db.exec(`${roomTable('tk_rooms_scoped')};INSERT INTO tk_rooms_scoped(id,players,native_busy,online,last_seen) SELECT id,players,native_busy,online,last_seen FROM tk_rooms;DROP TABLE tk_rooms;ALTER TABLE tk_rooms_scoped RENAME TO tk_rooms;`);
   if(this.db.prepare('PRAGMA foreign_key_check').all().length)throw Error('QUEUE_MIGRATION_INTEGRITY');
   this.db.exec('COMMIT');
  }catch(error){this.db.exec('ROLLBACK');throw error;}
  finally{this.db.exec('PRAGMA foreign_keys=ON');}
 }
 sql(text){if(!this.statements.has(text))this.statements.set(text,this.db.prepare(text));return this.statements.get(text);}
 transaction(fn){
  if(this.inTransaction)return fn();
  this.db.exec('BEGIN IMMEDIATE');this.inTransaction=true;
  try{const result=fn();this.db.exec('COMMIT');return result;}
  catch(error){this.db.exec('ROLLBACK');throw error;}
  finally{this.inTransaction=false;}
 }
 lease(value){const expiry=typeof value==='string'?Date.parse(value):value;if(!Number.isSafeInteger(expiry)||expiry<=this.now()||expiry>this.now()+45000)fail('INVALID_LEASE');return expiry;}
 scoped(input){
  if(typeof input.subject!=='string'||!/^[a-zA-Z0-9:_-]{16,160}$/.test(input.subject)||typeof input.bindingId!=='string')fail('INVALID_SCOPE');
  const binding=this.sql('SELECT * FROM tk_bindings WHERE id=? AND subject=? AND game_id=?').get(input.bindingId,input.subject,gameId(input.gameId));
  if(!binding)fail('BINDING_NOT_FOUND',404);return binding;
 }
 active(binding){return binding.enabled===1&&binding.expires>this.now();}
 wake(room){for(const fn of [...(this.waiters.get(room)??[])])fn();}
 wakeAll(){for(const room of this.waiters.keys())this.wake(room);}
 wait(room,ms){return new Promise(resolve=>{
  let timer;const done=()=>{clearTimeout(timer);this.waiters.get(room)?.delete(done);if(!this.waiters.get(room)?.size)this.waiters.delete(room);resolve();};
  if(!this.waiters.has(room))this.waiters.set(room,new Set());this.waiters.get(room).add(done);timer=setTimeout(done,ms);
 });}
 enqueue(bindingId,event,testExpires=null){
  const binding=this.sql('UPDATE tk_bindings SET seq=seq+1 WHERE id=? RETURNING seq').get(bindingId);
  this.sql('INSERT INTO tk_events(binding,seq,id,priority,payload,received,test_expires,portrait_id) VALUES(?,?,?,?,?,?,?,?)').run(bindingId,binding.seq,event.id,priority(event),JSON.stringify({...event,seq:binding.seq,receivedAt:this.now()}),this.now(),testExpires,event.sender?.portraitId??null);
 }
 enqueuePortrait(bindingId,id,pixels,generation){
  const receipt='portrait:'+id;
  if(!this.sql('SELECT 1 FROM tk_events WHERE binding=? AND id=?').get(bindingId,receipt)){
   // Rehydration after a room change may have to wait for effect intake to drain.
   if(this.diagnostics(bindingId).queued>=this.maxPending||Number(this.sql('SELECT COUNT(*) AS n FROM tk_events').get().n)>=this.maxTotalPending)return false;
   const job=this.sql('SELECT test_until FROM tk_portraits WHERE binding=? AND id=?').get(bindingId,id);
   if(!job||job.test_until!==null&&job.test_until<=this.now())return false;
   this.enqueue(bindingId,{id:receipt,kind:'Portrait',sender:{portraitId:id,pixels:JSON.parse(pixels)}},job.test_until);
  }
  this.sql('UPDATE tk_portraits SET offered_generation=? WHERE binding=? AND id=?').run(generation,bindingId,id);return true;
 }
 portraitReservationStats(bindingId){
  const scope=bindingId?' AND p.binding=?':'';
  const query='SELECT COUNT(*) AS n,MIN(p.created) AS oldest FROM tk_portraits p JOIN tk_bindings b ON b.id=p.binding WHERE (p.pixels IS NULL OR (b.room_id IS NOT NULL AND p.offered_generation<>b.generation)) AND NOT EXISTS(SELECT 1 FROM tk_events e WHERE e.binding=p.binding AND e.id=\'portrait:\'||p.id)'+scope;
  return bindingId?this.sql(query).get(bindingId):this.sql(query).get();
 }
 cleanupTests(){
  const expired=this.sql('SELECT binding,COUNT(*) AS n FROM tk_events WHERE test_expires<=? AND id NOT LIKE \'portrait:%\' GROUP BY binding').all(this.now());
  for(const row of expired)this.sql('UPDATE tk_bindings SET expired_tests=expired_tests+? WHERE id=?').run(row.n,row.binding);
  const removed=this.sql('DELETE FROM tk_events WHERE test_expires<=?').run(this.now()).changes;
  const removedPortraits=this.sql('DELETE FROM tk_portraits WHERE test_until<=?').run(this.now()).changes;
  if(removed||removedPortraits)this.wakeAll();
 }
 reconcile(){
  if(this.closed)return;
  let changed=false;
  this.transaction(()=>{
   this.cleanupTests();
   const now=this.now(),rooms=this.sql('SELECT * FROM tk_rooms WHERE online=1 AND last_seen>=? ORDER BY last_seen DESC,id').all(now-this.roomTimeoutMs);
   const available=new Map(rooms.map(r=>[roomKey(r.game_id,r.id),{...r,players:JSON.parse(r.players)}]));
   const bindings=this.sql('SELECT * FROM tk_bindings ORDER BY created,id').all();
   const occupied=new Set();
   for(const b of bindings){
    const room=available.get(roomKey(b.game_id,b.room_id));
    if(b.room_id&&(!this.active(b)||!room||room.native_busy||!room.players.includes(b.owner))){
     this.sql('UPDATE tk_bindings SET room_id=NULL,generation=generation+1 WHERE id=?').run(b.id);b.room_id=null;b.generation++;changed=true;
    }
    if(b.room_id)occupied.add(roomKey(b.game_id,b.room_id));
   }
   for(const b of bindings){
    if(b.room_id||!this.active(b))continue;
    const room=rooms.find(r=>r.game_id===b.game_id&&!r.native_busy&&!occupied.has(roomKey(r.game_id,r.id))&&available.get(roomKey(r.game_id,r.id)).players.includes(b.owner));
    if(!room)continue;
    b.generation++;this.sql('UPDATE tk_bindings SET room_id=?,generation=? WHERE id=?').run(room.id,b.generation,b.id);occupied.add(roomKey(room.game_id,room.id));changed=true;
   }
   // Completed images are durable jobs too: queue once per room generation, with bounded retries.
   for(const p of this.sql('SELECT p.binding,p.id,p.pixels,b.generation FROM tk_portraits p JOIN tk_bindings b ON b.id=p.binding WHERE b.room_id IS NOT NULL AND p.pixels IS NOT NULL AND p.offered_generation<>b.generation LIMIT 128').all())this.enqueuePortrait(p.binding,p.id,p.pixels,p.generation);
  });
  if(changed)this.wakeAll();
 }
 diagnostics(bindingId){
  const row=this.sql('SELECT COUNT(*) AS pending,MIN(received) AS oldest FROM tk_events WHERE binding=?').get(bindingId),portraits=this.portraitReservationStats(bindingId);
  const oldest=[row.oldest,portraits.oldest].filter(v=>v!==null);
  const binding=this.sql('SELECT expired_tests,portrait_fallbacks FROM tk_bindings WHERE id=?').get(bindingId);
  return {pending:Number(row.pending)+Number(portraits.n),queued:Number(row.pending),portraitPending:Number(portraits.n),oldestAgeMs:oldest.length?Math.max(0,this.now()-Math.min(...oldest)):0,expiredTests:Number(binding?.expired_tests??0),portraitFallbacks:Number(binding?.portrait_fallbacks??0)};
 }
 state(binding){
  if(!this.active(binding))return 'paused';if(binding.room_id)return 'connected';
  const rooms=this.sql('SELECT players FROM tk_rooms WHERE game_id=? AND online=1 AND last_seen>=?').all(binding.game_id,this.now()-this.roomTimeoutMs);
  return rooms.some(r=>JSON.parse(r.players).includes(binding.owner))?'busy':'waiting';
 }
 response(binding){return {ok:true,bindingId:binding.id,state:this.state(binding),...(binding.room_id?{roomId:binding.room_id}:{}),...this.diagnostics(binding.id),expiresAt:binding.expires,ownerRobloxId:binding.owner};}
 recycleBindings(){
  this.reconcile();
  const needed=Number(this.sql('SELECT COUNT(*) AS n FROM tk_bindings').get().n)-this.maxBindings+1;
  const candidates=this.sql('SELECT b.id FROM tk_bindings b WHERE b.last_activity<? AND (b.enabled=0 OR b.expires<=?) AND b.room_id IS NULL AND NOT EXISTS(SELECT 1 FROM tk_events e WHERE e.binding=b.id) AND NOT EXISTS(SELECT 1 FROM tk_portraits p WHERE p.binding=b.id AND p.pixels IS NULL) ORDER BY b.last_activity,b.created,b.id LIMIT ?').all(this.now()-24*60*60*1000,this.now(),Math.max(0,needed));
  for(const {id}of candidates){
   this.sql('DELETE FROM tk_receipts WHERE binding=?').run(id);
   this.sql('DELETE FROM tk_portraits WHERE binding=?').run(id);
   this.sql('DELETE FROM tk_bindings WHERE id=?').run(id);this.offers.delete(id);
  }
 }
 bind(input){
  if(typeof input.subject!=='string'||!/^[a-zA-Z0-9:_-]{16,160}$/.test(input.subject)||!account(input.ownerRobloxId))fail('INVALID_SCOPE');
  let channel;try{channel=username(input.channel);}catch{fail('INVALID_CHANNEL');}
  const expires=this.lease(input.validUntil);
  const id=gameId(input.gameId);
  if(input.gameId===undefined&&input.game!==undefined)fail('INVALID_GAME');
  const game=input.game===undefined?(id===magnetGameId?null:fail('INVALID_GAME')):normalizeGame(input.game,id);
  return this.transaction(()=>{
   if(game){
    const old=this.sql('SELECT * FROM tk_games WHERE id=?').get(id);
    if(old&&(old.place_ids!==JSON.stringify(game.placeIds)||old.universe_id!==game.universeId))this.sql('UPDATE tk_rooms SET online=0 WHERE game_id=?').run(id);
    this.sql('INSERT INTO tk_games(id,place_ids,universe_id,commands,credential_hash) VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET place_ids=excluded.place_ids,universe_id=excluded.universe_id,commands=excluded.commands,credential_hash=excluded.credential_hash').run(id,JSON.stringify(game.placeIds),game.universeId,JSON.stringify(game.commands),game.credentialHash);
   }
   let binding=this.sql('SELECT * FROM tk_bindings WHERE game_id=? AND subject=? AND owner=? AND channel=?').get(id,input.subject,input.ownerRobloxId,channel);
   if(!binding&&Number(this.sql('SELECT COUNT(*) AS n FROM tk_bindings').get().n)>=this.maxBindings){
    this.recycleBindings();
    if(Number(this.sql('SELECT COUNT(*) AS n FROM tk_bindings').get().n)>=this.maxBindings)fail('BINDING_CAPACITY',429);
   }
   // Account/channel switches pause the previous selection without deleting its queue.
   this.sql('UPDATE tk_bindings SET enabled=0,room_id=NULL,generation=generation+1,last_activity=? WHERE game_id=? AND subject=? AND id<>? AND enabled=1').run(this.now(),id,input.subject,binding?.id??'');
   if(binding)this.sql('UPDATE tk_bindings SET expires=?,enabled=1,last_activity=? WHERE id=?').run(expires,this.now(),binding.id);
   else{
    const bindingId=randomUUID();this.sql('INSERT INTO tk_bindings(id,game_id,subject,owner,channel,expires,enabled,created,last_activity) VALUES(?,?,?,?,?,?,1,?,?)').run(bindingId,id,input.subject,input.ownerRobloxId,channel,expires,this.now(),this.now());binding={id:bindingId};
   }
   this.reconcile();return this.response(this.sql('SELECT * FROM tk_bindings WHERE id=?').get(binding.id));
  });
 }
 heartbeat(input,binding){if(input.validUntil!==undefined&&binding.enabled===1){this.sql('UPDATE tk_bindings SET expires=? WHERE id=?').run(this.lease(input.validUntil),binding.id);}}
 service(action,input){
  if(action==='bind')return this.bind(input);
  return this.transaction(()=>{
   let binding=this.scoped(input);
   this.sql('UPDATE tk_bindings SET last_activity=? WHERE id=?').run(this.now(),binding.id);
   if(action==='release'){
    this.sql('UPDATE tk_bindings SET enabled=0,room_id=NULL,generation=generation+1 WHERE id=?').run(binding.id);this.wakeAll();
   }else if(action==='status'||action==='events')this.heartbeat(input,binding);
   else fail('NOT_FOUND',404);
   this.reconcile();binding=this.sql('SELECT * FROM tk_bindings WHERE id=?').get(binding.id);
   if(action!=='events')return this.response(binding);
   if(!this.active(binding))fail('LEASE_EXPIRED',403);
   if(!Array.isArray(input.events)||input.events.length<1||input.events.length>100)fail('INVALID_BATCH');
   const commands=new Set(JSON.parse(this.sql('SELECT commands FROM tk_games WHERE id=?').get(binding.game_id).commands));
   const normalized=input.events.map(e=>normalizeEvent(e,binding.id));
   const replayOnlyIds=input.replayOnlyIds===undefined?[]:input.replayOnlyIds;
   if(!Array.isArray(replayOnlyIds)||replayOnlyIds.length>100||new Set(replayOnlyIds).size!==replayOnlyIds.length||replayOnlyIds.some(id=>typeof id!=='string'||!normalized.some(item=>item.event.id===id)))fail('INVALID_BATCH');
   const replayOnly=new Set(replayOnlyIds);
   const batch=new Map(),duplicates=[];
   for(const item of normalized){
    const id=item.event.id,previous=batch.get(id),old=this.sql('SELECT fingerprint FROM tk_receipts WHERE binding=? AND id=?').get(binding.id,id);
    if((old&&old.fingerprint!==item.fingerprint)||(previous&&previous.fingerprint!==item.fingerprint))fail('RECEIPT_CONFLICT',409);
    // An exact stored retry cannot enqueue work again, even if its command was
    // removed after admission. Every new receipt requires current membership.
    if(!old&&(replayOnly.has(id)||!commands.has(item.event.effect)))fail('INVALID_EFFECT');
    if(old||previous)duplicates.push(id);else batch.set(id,item);
   }
   const pending=this.diagnostics(binding.id).pending,total=Number(this.sql('SELECT COUNT(*) AS n FROM tk_events').get().n),receipts=Number(this.sql('SELECT COUNT(*) AS n FROM tk_receipts WHERE binding=?').get(binding.id).n);
   const jobs=new Map();
   for(const item of batch.values())if(item.url&&!this.sql('SELECT 1 FROM tk_portraits WHERE binding=? AND id=?').get(binding.id,item.event.sender.portraitId)){
    const id=item.event.sender.portraitId,until=item.event.test===true?this.now()+60000:null,old=jobs.get(id);
    jobs.set(id,{url:item.url,until:old?.until===null?null:until});
   }
   let portraits=Number(this.sql('SELECT COUNT(*) AS n FROM tk_portraits WHERE binding=?').get(binding.id).n);
   const protectedProfiles=new Set([...batch.values()].map(item=>item.event.sender.portraitId).filter(Boolean));
   if(portraits+jobs.size>this.maxPortraits){
    const reusable=this.sql('SELECT p.id FROM tk_portraits p WHERE p.binding=? AND p.pixels IS NOT NULL AND NOT EXISTS(SELECT 1 FROM tk_events e WHERE e.binding=p.binding AND e.portrait_id=p.id) ORDER BY p.last_used,p.created,p.id').all(binding.id);
    for(const {id}of reusable){
     if(portraits+jobs.size<=this.maxPortraits)break;
     if(protectedProfiles.has(id))continue;
     this.sql('DELETE FROM tk_portraits WHERE binding=? AND id=?').run(binding.id,id);portraits--;
    }
   }
   // Faces are cosmetic. Preserve all pending profile references, and admit excess
   // gameplay with its existing generic face when every bounded profile slot is in use.
   let available=Math.max(0,this.maxPortraits-portraits);const fallbackProfiles=new Set();
   for(const id of jobs.keys())if(available>0)available--;else{jobs.delete(id);fallbackProfiles.add(id);}
   let fallbacks=0;
   for(const item of batch.values())if(fallbackProfiles.has(item.event.sender.portraitId)){
    delete item.event.sender.portraitId;fallbacks++;
   }
   // Reserve space for each pending portrait as well as the immediate gameplay receipt.
   const allPendingPortraits=Number(this.portraitReservationStats().n);
   if(batch.size&&(pending+batch.size+jobs.size>this.maxPending||total+allPendingPortraits+batch.size+jobs.size>this.maxTotalPending||receipts+batch.size>this.maxReceipts))fail('BACKPRESSURE',429);
   if(fallbacks)this.sql('UPDATE tk_bindings SET portrait_fallbacks=portrait_fallbacks+? WHERE id=?').run(fallbacks,binding.id);
   for(const [id,job]of jobs)this.sql('INSERT INTO tk_portraits(binding,id,url,created,last_used,test_until) VALUES(?,?,?,?,?,?)').run(binding.id,id,job.url,this.now(),this.now(),job.until);
   for(const item of batch.values()){
    const expiry=item.event.test===true?this.now()+60000:null,portraitId=item.event.sender.portraitId;
    if(portraitId){
     this.sql('UPDATE tk_portraits SET last_used=? WHERE binding=? AND id=?').run(this.now(),binding.id,portraitId);
     if(expiry===null){
      this.sql('UPDATE tk_portraits SET test_until=NULL WHERE binding=? AND id=?').run(binding.id,portraitId);
      this.sql('UPDATE tk_events SET test_expires=NULL WHERE binding=? AND id=?').run(binding.id,'portrait:'+portraitId);
     }else{
      this.sql('UPDATE tk_portraits SET test_until=MAX(test_until,?) WHERE binding=? AND id=? AND test_until IS NOT NULL').run(expiry,binding.id,portraitId);
      this.sql('UPDATE tk_events SET test_expires=MAX(test_expires,?) WHERE binding=? AND id=? AND test_expires IS NOT NULL').run(expiry,binding.id,'portrait:'+portraitId);
     }
    }
    this.sql('INSERT INTO tk_receipts(binding,id,fingerprint) VALUES(?,?,?)').run(binding.id,item.event.id,item.fingerprint);this.enqueue(binding.id,item.event,expiry);
   }
   this.wake(roomKey(binding.game_id,binding.room_id));queueMicrotask(()=>this.pumpPortraits());
   return {...this.response(binding),accepted:normalized.map(item=>item.event.id),duplicates,enqueued:batch.size};
  });
 }
 register(token,input,id=magnetGameId){
  const game=this.sql('SELECT * FROM tk_games WHERE id=?').get(id);
  if(!game||!JSON.parse(game.place_ids).includes(String(input.placeId))||game.universe_id!==null&&String(input.universeId)!==game.universe_id||typeof input.nativeBusy!=='boolean'||!Array.isArray(input.players)||input.players.length>100||input.players.some(id=>!account(id))||new Set(input.players).size!==input.players.length)fail('INVALID_ROOM');
  return this.transaction(()=>{
   this.reconcile();
   if(!this.sql('SELECT 1 FROM tk_rooms WHERE id=? AND game_id=?').get(token,id)&&Number(this.sql('SELECT COUNT(*) AS n FROM tk_rooms').get().n)>=this.maxRooms){
    this.sql('DELETE FROM tk_rooms WHERE (online=0 OR last_seen<?) AND NOT EXISTS(SELECT 1 FROM tk_bindings WHERE room_id=tk_rooms.id AND game_id=tk_rooms.game_id)').run(this.now()-this.roomTimeoutMs);
    if(Number(this.sql('SELECT COUNT(*) AS n FROM tk_rooms').get().n)>=this.maxRooms)fail('ROOM_CAPACITY',429);
   }
   this.sql('INSERT INTO tk_rooms(id,game_id,players,native_busy,online,last_seen) VALUES(?,?,?,?,1,?) ON CONFLICT(game_id,id) DO UPDATE SET players=excluded.players,native_busy=excluded.native_busy,online=1,last_seen=excluded.last_seen').run(token,id,JSON.stringify(input.players),input.nativeBusy?1:0,this.now());
   this.reconcile();return this.roomResponse(token,0,id);
  });
 }
 roomResponse(token,limit=100,id=magnetGameId){
  const b=this.sql('SELECT * FROM tk_bindings WHERE room_id=? AND game_id=?').get(token,id);
  if(!b)return {ok:true,state:'waiting',status:'WAITING',binding:null,events:[],pending:0,portraitPending:0,expiredTests:0,oldestAgeMs:0,hasMore:false,dropped:0};
  let offer=this.offers.get(b.id);if(!offer||offer.generation!==b.generation){offer={generation:b.generation,cursors:[0,0,0,0]};this.offers.set(b.id,offer);}
  const rows=[];
  for(let p=0;p<4&&rows.length<limit;p++){
   const previous=offer.cursors[p],count=limit-rows.length;
   const page=this.sql('SELECT seq,payload FROM tk_events WHERE binding=? AND priority=? AND seq>? ORDER BY seq LIMIT ?').all(b.id,p,previous,count);
   if(page.length<count&&previous>0)page.push(...this.sql('SELECT seq,payload FROM tk_events WHERE binding=? AND priority=? AND seq<=? ORDER BY seq LIMIT ?').all(b.id,p,previous,count-page.length));
   if(page.length)offer.cursors[p]=page.at(-1).seq;rows.push(...page);
  }
  const stats=this.diagnostics(b.id);
  return {ok:true,state:'connected',status:'CONNECTED',binding:{id:b.id,ownerRobloxId:b.owner,channel:b.channel,expiresAt:b.expires,generation:b.generation},events:rows.map(r=>JSON.parse(r.payload)),...stats,hasMore:stats.pending>rows.length,dropped:0};
 }
 async poll(token,url,headers,id=magnetGameId){
  const limit=Number(url.searchParams.get('limit')??100),waitMs=Number(url.searchParams.get('waitMs')??0);
  if(!Number.isSafeInteger(limit)||limit<1||limit>100||!Number.isFinite(waitMs)||waitMs<0||waitMs>1000)fail('INVALID_POLL');
  let acks;try{acks=JSON.parse(String(headers['x-magnet-ack']??'[]'));}catch{fail('INVALID_ACK');}
  if(!Array.isArray(acks)||acks.length>100||acks.some(n=>!Number.isSafeInteger(n)||n<1))fail('INVALID_ACK');
  let result=this.transaction(()=>{
   const room=this.sql('SELECT * FROM tk_rooms WHERE id=? AND game_id=?').get(token,id);if(!room||room.online!==1)fail('ROOM_NOT_REGISTERED',409);
   this.sql('UPDATE tk_rooms SET last_seen=? WHERE id=? AND game_id=?').run(this.now(),token,id);this.reconcile();
   this.sql('UPDATE tk_bindings SET last_activity=? WHERE room_id=? AND game_id=?').run(this.now(),token,id);
   if(acks.length){
    const b=this.sql('SELECT * FROM tk_bindings WHERE room_id=? AND game_id=?').get(token,id);
    const ackBinding=headers['x-tikkies-binding']??headers['x-magnet-binding'],generation=Number(headers['x-tikkies-generation']??headers['x-magnet-generation']);
    if(!b||ackBinding!==b.id||!Number.isSafeInteger(generation)||generation!==b.generation)fail('STALE_BINDING',409);
    if(acks.some(n=>n>b.seq))fail('INVALID_ACK');
    for(const seq of acks)this.sql('DELETE FROM tk_events WHERE binding=? AND seq=?').run(b.id,seq);
   }
   return this.roomResponse(token,limit,id);
  });
  if(!result.events.length&&waitMs>0){await this.wait(roomKey(id,token),waitMs);if(this.closed)return {ok:true,state:'paused',binding:null,events:[],pending:0};this.reconcile();result=this.roomResponse(token,limit,id);}
  return result;
 }
 pumpPortraits(){
  if(this.closed)return;
  try{
   const jobs=this.sql('SELECT binding,id,url,attempts FROM tk_portraits WHERE pixels IS NULL AND next_attempt<=? ORDER BY next_attempt,binding,id LIMIT 32').all(this.now());
   for(const job of jobs){
    if(this.working.size>=4)break;const key=job.binding+'/'+job.id;if(this.working.has(key))continue;this.working.add(key);
    Promise.resolve().then(()=>this.pixels(job.url)).then(pixels=>{
     if(this.closed)return;if(!validPixels(pixels))throw Error('PORTRAIT_UNAVAILABLE');
     this.transaction(()=>{
      const pending=this.sql('SELECT test_until FROM tk_portraits WHERE binding=? AND id=?').get(job.binding,job.id);
      if(!pending||pending.test_until!==null&&pending.test_until<=this.now())return;
      const b=this.sql('SELECT * FROM tk_bindings WHERE id=?').get(job.binding);if(!b)return;
      const encoded=JSON.stringify(pixels);this.sql('UPDATE tk_portraits SET pixels=? WHERE binding=? AND id=?').run(encoded,job.binding,job.id);
      this.sql('UPDATE tk_bindings SET last_activity=? WHERE id=?').run(this.now(),job.binding);
      this.enqueuePortrait(job.binding,job.id,encoded,b.generation);this.wake(roomKey(b.game_id,b.room_id));
     });
    }).catch(()=>{
     if(!this.closed){try{this.sql('UPDATE tk_portraits SET attempts=attempts+1,next_attempt=? WHERE binding=? AND id=?').run(this.now()+Math.min(300000,1000*2**Math.min(8,job.attempts)),job.binding,job.id);}catch{/* Leave the persisted job for recovery. */}}
    }).finally(()=>{this.working.delete(key);});
   }
  }catch{/* A temporary SQLite error leaves all portrait jobs durable. */}
 }
 async handle(req,url,reply){
  try{
   const service=url.pathname.startsWith('/tikkies/service/');
   let id;
   if(service){
    if(!sameKey(req.headers['x-tikkies-key'],this.key))fail('UNAUTHORIZED',401);
    if(req.method!=='POST')fail('NOT_FOUND',404);
   }else{
    id=gameId(req.headers['x-tikkies-game']);
    const game=this.sql('SELECT credential_hash FROM tk_games WHERE id=?').get(id),token=req.headers['x-magnet-key'];
    if(!(id===magnetGameId&&sameKey(token,this.mapKey))&&!(game?.credential_hash&&typeof token==='string'&&sameKey(createHash('sha256').update(token).digest('hex'),game.credential_hash)))fail('UNAUTHORIZED',401);
    if(!sessionId(req.headers['x-magnet-session']))fail('INVALID_SESSION');
   }
   let input={};
   if(req.method==='POST'){
    const chunks=[];let bytes=0;for await(const chunk of req){bytes+=chunk.length;if(bytes>262144)fail('BODY_TOO_LARGE',413);chunks.push(chunk);}
    try{input=JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{fail('INVALID_JSON');}
    if(!input||typeof input!=='object'||Array.isArray(input))fail('INVALID_REQUEST');
   }
   let result;
   if(service)result=this.service(url.pathname.slice('/tikkies/service/'.length),input);
   else if(url.pathname==='/tikkies/room'&&req.method==='POST')result=this.register(req.headers['x-magnet-session'],input,id);
   else if(url.pathname==='/tikkies/room/leave'&&req.method==='POST'){
    this.sql('UPDATE tk_rooms SET online=0 WHERE id=? AND game_id=?').run(req.headers['x-magnet-session'],id);this.reconcile();result={ok:true,state:'paused'};
   }else if(url.pathname==='/tikkies/events'&&req.method==='POST'){
    // Roblox rejects '[' in custom header values. ACK arrays belong in JSON.
    if(Object.keys(input).some(k=>!['acks','binding','generation','waitMs','limit'].includes(k))||
     input.binding!==undefined&&!sessionId(input.binding)||
     input.generation!==undefined&&(!Number.isSafeInteger(input.generation)||input.generation<1)||
     input.waitMs!==undefined&&typeof input.waitMs!=='number'||input.limit!==undefined&&typeof input.limit!=='number')fail('INVALID_POLL');
    const pollUrl=new URL(url);pollUrl.search='';
    pollUrl.searchParams.set('waitMs',String(input.waitMs??0));pollUrl.searchParams.set('limit',String(input.limit??100));
    result=await this.poll(req.headers['x-magnet-session'],pollUrl,{
     'x-magnet-ack':JSON.stringify(input.acks===undefined?[]:input.acks),
     'x-magnet-binding':input.binding,'x-magnet-generation':input.generation,
    },id);
   }else if(url.pathname==='/tikkies/events'&&req.method==='GET')result=await this.poll(req.headers['x-magnet-session'],url,req.headers,id);
   else fail('NOT_FOUND',404);
   reply(200,result);
  }catch(error){reply(error.status??503,{ok:false,error:error.code??'QUEUE_STORAGE_ERROR'});}
 }
 close(){if(this.closed)return;this.closed=true;clearInterval(this.timer);this.wakeAll();this.db.close();}
}
