import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve,relative,isAbsolute} from 'node:path';
import {createBridge} from './http.mjs';
import {DeliveryStore} from './delivery.mjs';

const key='reliable-test-key-at-least-32-characters';
const headers={'x-magnet-key':key,'x-magnet-session':'reliable-session-aaaaaaaaaaaaaaaa','content-type':'application/json'};
const gift=(id,msg,count=1)=>({giftId:id,common:{msgId:msg},repeatCount:count,user:{displayId:'viewer'}});
async function server(t,databasePath,deliveryStore){
 let connection;
 const app=createBridge({key,databasePath,deliveryStore,giftMap:{'5655':'Rose','5566':'Bear','9947':'Friendship'},connect:()=>{
  connection=new EventEmitter();connection.connect=async()=>({});connection.disconnect=()=>{};return connection;
 },pixels:async()=>null});
 await new Promise(r=>app.server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+app.server.address().port;
 t.after(()=>app.close());
 const request=async(path,extra={})=>(await fetch(base+path,{...extra,headers:{...headers,...extra.headers}})).json();
 return {app,request,get connection(){return connection;}};
}
test('reliable mode retains a paid gift through6000 events and only deletes explicitly acknowledged receipts',async t=>{
 const s=await server(t);
 const start=await s.request('/connect',{method:'POST',body:JSON.stringify({username:'host',protocol:2,rawLikes:true,reliable:true})});
 assert.equal(start.capabilities.reliable,true);
 s.connection.emit('gift',gift(5566,'early-bear'));
 for(let i=0;i<6000;i++)s.connection.emit('like',{common:{msgId:'like-'+i},count:1,user:{displayId:'liker'}});
 s.connection.emit('gift',gift(9947,'urgent-freeze'));
 const batch=await s.request('/session/events?limit=100');
 assert.equal(batch.pending,6002);assert.equal(batch.dropped,0);
 assert.equal(batch.events[0].giftId,'Friendship');
 assert.ok(batch.events.some(e=>e.id==='gift:early-bear'));
 const replay=await s.request('/session/events?limit=100');
 assert.equal(replay.pending,6002);assert.equal(replay.events[0].id,batch.events[0].id);
 assert.notEqual(replay.events.at(-1).id,batch.events.at(-1).id,'A blocked first page hid later receipts');
 const done=batch.events.slice(0,3).map(e=>e.seq);
 const next=await s.request('/session/events?limit=100',{headers:{'x-magnet-ack':JSON.stringify(done)}});
 assert.equal(next.pending,5999);assert.ok(next.events.every(e=>!done.includes(e.seq)));
 s.connection.emit('gift',gift(5566,'early-bear'));
 assert.equal((await s.request('/session/events')).pending,5999);
});

test('native reliable polling accepts Roblox-compatible JSON acknowledgments',async t=>{
 const s=await server(t);await s.request('/connect',{method:'POST',body:JSON.stringify({username:'host',protocol:2,reliable:true})});
 s.connection.emit('gift',gift(5655,'json-ack',10));
 const page=await s.request('/session/events?limit=100&waitMs=0',{method:'POST',body:JSON.stringify({acks:[]})});
 assert.equal(page.events[0].quantity,10);
 const ack={method:'POST',body:JSON.stringify({acks:page.events.map(e=>e.seq)})};
 assert.equal((await s.request('/session/events?limit=100',ack)).pending,0);
 assert.equal((await s.request('/session/events',ack)).pending,0);
 assert.equal((await s.request('/session/events',{method:'POST',body:JSON.stringify({acks:'[1]'})})).error,'INVALID_ACK');
 assert.equal((await s.request('/session/events',{method:'POST',body:JSON.stringify({acks:[],owner:'123'})})).error,'INVALID_REQUEST');
});

test('a backpressured page cannot hide a later same-priority reward and urgent controls remain first',async t=>{
 const s=await server(t);
 await s.request('/connect',{method:'POST',body:JSON.stringify({username:'host',protocol:2,reliable:true})});
 for(let i=0;i<150;i++)s.connection.emit('gift',gift(5655,'blocked-'+i));
 const first=await s.request('/session/events');assert.equal(first.events.length,100);
 s.connection.emit('gift',gift(5566,'later-paid'));
 s.connection.emit('gift',gift(9947,'new-control'));
 const second=await s.request('/session/events');
 assert.equal(second.events[0].giftId,'Friendship');
 assert.ok(second.events.some(e=>e.id==='gift:later-paid'));
 assert.equal(second.pending,152);
});
test('unacknowledged deliveries and streak totals survive backend restart',async t=>{
 const dir=mkdtempSync(join(tmpdir(),'magnet-reliable-'));
 const file=join(dir,'queue.sqlite');
 const a=await server(t,file);
 const start=await a.request('/connect',{method:'POST',body:JSON.stringify({username:'host',protocol:2,reliable:true})});
 assert.equal(start.capabilities.reliable,true);
 a.connection.emit('gift',{...gift(5655,'combo1',3),giftDetails:{giftType:1},groupId:'123456'});
 const before=await a.request('/session/events');assert.equal(before.events[0].quantity,3);
 await a.app.close();
 const b=await server(t,file);
 t.after(()=>{
  const child=relative(resolve(tmpdir()),resolve(dir));
  assert.ok(child&&!child.startsWith('..')&&!isAbsolute(child)&&child.startsWith('magnet-reliable-'));
  rmSync(dir,{recursive:true,force:true});
 });
 const replay=await b.request('/session/events');assert.equal(replay.events[0].id,before.events[0].id);
 b.connection.emit('gift',{...gift(5655,'combo2',5),giftDetails:{giftType:1},groupId:'123456'});
 const after=await b.request('/session/events');assert.deepEqual(after.events.sort((a,b)=>a.seq-b.seq).map(e=>e.quantity),[3,2]);
});
test('reliable long polling wakes on a gift without waiting an idle polling interval',async t=>{
 const s=await server(t);
 await s.request('/connect',{method:'POST',body:JSON.stringify({username:'host',protocol:2,reliable:true})});
 const pending=s.request('/session/events?waitMs=1000');
 await new Promise(r=>setTimeout(r,20));const at=performance.now();
 s.connection.emit('gift',gift(5655,'wake'));
 const result=await pending;
 assert.equal(result.events[0].id,'gift:wake');
 assert.ok(performance.now()-at<500,'Gift was held for an idle sleep');
});

test('reliable acknowledgments validate input and cannot delete another session receipt',async t=>{
 const s=await server(t);
 await s.request('/connect',{method:'POST',body:JSON.stringify({username:'host',protocol:2,reliable:true})});
 s.connection.emit('gift',gift(5655,'original'));
 const other='reliable-session-bbbbbbbbbbbbbbbb';
 await s.request('/connect',{method:'POST',headers:{'x-magnet-session':other},body:JSON.stringify({username:'other',protocol:2,reliable:true})});
 s.connection.emit('gift',gift(5655,'other'));
 for(const ids of [[0],[2],Array(101).fill(1),['1']]){
  assert.equal((await s.request('/session/events',{headers:{'x-magnet-ack':JSON.stringify(ids)}})).error,'INVALID_ACK');
 }
 assert.equal((await s.request('/session/events',{headers:{'x-magnet-session':other,'x-magnet-ack':'[1]'}})).pending,0);
 const original=await s.request('/session/events');
 assert.equal(original.pending,1);assert.equal(original.events[0].id,'gift:original');
});
test('a transient database write failure retries the original receipt without poisoning deduplication',async t=>{
 const store=new DeliveryStore();t.after(()=>store.close());
 const s=await server(t,undefined,store);
 await s.request('/connect',{method:'POST',body:JSON.stringify({username:'host',protocol:2,reliable:true})});
 store.db.exec('PRAGMA query_only=ON');
 s.connection.emit('gift',gift(5655,'retry-write'));
 s.connection.emit('streamEnd');
 const first=await s.request('/session/events');
 assert.equal(first.pending,0);assert.equal(first.retryingWrites,1);
 assert.equal(first.status,'DRAINING');
 store.db.exec('PRAGMA query_only=OFF');
 await new Promise(r=>setTimeout(r,600));
 const retry=await s.request('/session/events');
 assert.equal(retry.events[0].id,'gift:retry-write');assert.equal(retry.retryingWrites,0);assert.equal(retry.status,'OFFLINE');
});

test('reliable receipts resume after a three-minute outage without reconnecting a new session',async t=>{
 const store=new DeliveryStore();t.after(()=>store.close());
 const token=headers['x-magnet-session'];
 const q=store.create(token,{username:'host',protocol:2,reliable:true});
 q.push({id:'gift:before-outage',giftId:'Bear',quantity:1,sender:{name:'viewer'}});
 store.sql.touch.run(Date.now()-180000,token);
 const s=await server(t,undefined,store);
 const resumed=await s.request('/session/events');
 assert.equal(resumed.pending,1);assert.equal(resumed.events[0].id,'gift:before-outage');
 assert.equal((await s.request('/session/events',{headers:{'x-magnet-ack':'[1]'}})).pending,0);
});
