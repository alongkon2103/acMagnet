import {DatabaseSync} from 'node:sqlite';
import {mkdirSync,chmodSync} from 'node:fs';
import {dirname} from 'node:path';

const priority=e=>e.kind==='Portrait'||['Friendship','Donut'].includes(e.giftId)?0:e.giftId==='Likes'?3:e.giftId==='Follow'?2:1;
export class DeliveryStore {
 constructor(path=':memory:'){
  if(path!==':memory:')mkdirSync(dirname(path),{recursive:true,mode:0o700});
  this.db=new DatabaseSync(path);if(path!==':memory:')chmodSync(path,0o600);this.closed=false;this.listeners=new Map();
  this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA foreign_keys=ON;
   CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY,meta TEXT NOT NULL,last_poll INTEGER NOT NULL,seq INTEGER NOT NULL DEFAULT 0);
   CREATE TABLE IF NOT EXISTS events(token TEXT NOT NULL REFERENCES sessions(token) ON DELETE CASCADE,seq INTEGER NOT NULL,id TEXT NOT NULL,priority INTEGER NOT NULL,payload TEXT NOT NULL,received INTEGER NOT NULL,PRIMARY KEY(token,seq));
   CREATE INDEX IF NOT EXISTS event_priority ON events(token,priority,seq);
   CREATE INDEX IF NOT EXISTS event_receipt ON events(token,id);
   CREATE TABLE IF NOT EXISTS receipts(token TEXT NOT NULL REFERENCES sessions(token) ON DELETE CASCADE,id TEXT NOT NULL,at INTEGER NOT NULL,PRIMARY KEY(token,id));
   CREATE INDEX IF NOT EXISTS receipt_age ON receipts(at);
   CREATE TABLE IF NOT EXISTS streaks(token TEXT NOT NULL REFERENCES sessions(token) ON DELETE CASCADE,id TEXT NOT NULL,count INTEGER NOT NULL,at INTEGER NOT NULL,PRIMARY KEY(token,id));`);
  this.sql={};
  const statements={
   create:'INSERT INTO sessions(token,meta,last_poll) VALUES(?,?,?)',
   list:'SELECT token,meta,last_poll FROM sessions',
   get:'SELECT token,meta,last_poll FROM sessions WHERE token=?',
   state:'SELECT seq FROM sessions WHERE token=?',
   touch:'UPDATE sessions SET last_poll=? WHERE token=?',
   remove:'DELETE FROM sessions WHERE token=?',
   has:'SELECT 1 FROM receipts WHERE token=? AND id=?',
   remember:'INSERT OR IGNORE INTO receipts(token,id,at) VALUES(?,?,?)',
   next:'UPDATE sessions SET seq=seq+1 WHERE token=? RETURNING seq',
   push:'INSERT INTO events(token,seq,id,priority,payload,received) VALUES(?,?,?,?,?,?)',
   read:'SELECT payload,seq,received FROM events WHERE token=? AND priority=? AND seq>? ORDER BY seq LIMIT ?',
   wrap:'SELECT payload,seq,received FROM events WHERE token=? AND priority=? AND seq<=? ORDER BY seq LIMIT ?',
   count:'SELECT COUNT(*) AS pending,MIN(received) AS oldest FROM events WHERE token=?',
   ack:'DELETE FROM events WHERE token=? AND seq=?',
   streak:'INSERT INTO streaks(token,id,count,at) VALUES(?,?,?,?) ON CONFLICT(token,id) DO UPDATE SET count=MAX(count,excluded.count),at=excluded.at',
   groups:'SELECT id,count,at FROM streaks WHERE token=? AND at>?',
   prune:'DELETE FROM receipts WHERE at<? AND NOT EXISTS(SELECT 1 FROM events WHERE events.token=receipts.token AND events.id=receipts.id)',
   pruneGroups:'DELETE FROM streaks WHERE at<?',
  };
  for(const[k,v]of Object.entries(statements))this.sql[k]=this.db.prepare(v);
 }
 create(token,meta){this.sql.create.run(token,JSON.stringify(meta),Date.now());return this.queue(token);}
 recover(){return this.sql.list.all().map(r=>({token:r.token,...JSON.parse(r.meta),lastPoll:r.last_poll}));}
 recoverOne(token){const r=this.sql.get.get(token);return r?{token:r.token,...JSON.parse(r.meta),lastPoll:r.last_poll}:null;}
 queue(token){
  const store=this;
  const offered=[0,0,0,0];
  return {
   get seq(){return Number(store.sql.state.get(token)?.seq??0);},
   has:id=>Boolean(store.sql.has.get(token,id)),
   groups:()=>new Map(store.sql.groups.all(token,Date.now()-3600000).map(r=>[r.id,{count:r.count,at:r.at}])),
   touch:()=>store.sql.touch.run(Date.now(),token),
   push(e){
    const at=Date.now();store.db.exec('BEGIN IMMEDIATE');
    try{
     if(!store.sql.remember.run(token,e.id,at).changes){store.db.exec('COMMIT');return false;}
     const seq=Number(store.sql.next.get(token).seq);
     store.sql.push.run(token,seq,e.id,priority(e),JSON.stringify({...e,seq,receivedAt:at}),at);
     const group=/^gift:([a-f0-9]{32}):(\d+)$/.exec(e.id);
     if(group)store.sql.streak.run(token,group[1],Number(group[2]),at);
     store.db.exec('COMMIT');store.wake(token);return true;
    }catch(error){store.db.exec('ROLLBACK');throw error;}
   },
   ack(ids){
    if(!ids.length)return;
    store.db.exec('BEGIN IMMEDIATE');
    try{for(const id of ids)store.sql.ack.run(token,id);store.db.exec('COMMIT');}
    catch(error){store.db.exec('ROLLBACK');throw error;}
   },
   read(_after=0,limit=100){
    // Rotate within each priority so a page of backpressured gifts cannot hide later receipts.
    // All rows remain durable until explicitly acknowledged; restarting only resets this offer cursor.
    const rows=[];
    for(let p=0;p<4&&rows.length<limit;p++){
     const previous=offered[p];
     const page=store.sql.read.all(token,p,previous,limit-rows.length);
     if(page.length<limit-rows.length&&previous>0)page.push(...store.sql.wrap.all(token,p,previous,limit-rows.length-page.length));
     if(page.length)offered[p]=page.at(-1).seq;
     rows.push(...page);
    }
    const total=store.sql.count.get(token);
    return {events:rows.map(r=>JSON.parse(r.payload)),cursor:rows.at(-1)?.seq??0,gap:false,dropped:0,
     pending:Number(total.pending),oldestAgeMs:total.oldest?Date.now()-total.oldest:0};
   },
   wake:()=>store.wake(token),
   wait(ms){return new Promise(resolve=>{
    let timer;const done=()=>{clearTimeout(timer);store.listeners.get(token)?.delete(done);resolve();};
    if(!store.listeners.has(token))store.listeners.set(token,new Set());
    store.listeners.get(token).add(done);timer=setTimeout(done,ms);
   });},
  };
 }
 wake(token){for(const fn of [...(this.listeners.get(token)??[])])fn();}
 remove(token){this.wake(token);this.listeners.delete(token);this.sql.remove.run(token);}
 prune(){this.sql.prune.run(Date.now()-3600000);this.sql.pruneGroups.run(Date.now()-3600000);}
 close(){if(this.closed)return;this.closed=true;for(const token of this.listeners.keys())this.wake(token);this.db.close();}
}
