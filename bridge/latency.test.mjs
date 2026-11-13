import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {createBridge} from './http.mjs';
import {giftMap} from './gifts.mjs';

async function setup(t,pixels=async()=>null,protocol=2,gacha=true,follow=true){
 let connection;
 const headers={'x-magnet-key':'test-key-that-is-at-least-32-characters','x-magnet-session':'latency-test-session-aaaaaaaaaaaaaaa','content-type':'application/json'};
 const app=createBridge({key:headers['x-magnet-key'],giftMap,connect:()=>{
  connection=new EventEmitter();connection.connect=async()=>({});connection.disconnect=()=>{};return connection;
 },pixels});
 await new Promise(r=>app.server.listen(0,'127.0.0.1',r));t.after(()=>app.close());
 const base='http://127.0.0.1:'+app.server.address().port;
 const start=await(await fetch(base+'/connect',{method:'POST',headers,body:JSON.stringify({username:'host',...(protocol?{protocol}:{}),...(gacha?{gacha:true}:{}),...(follow?{follow:true}:{})})})).json();
 return {connection,capabilities:start.capabilities,read:async(after=0)=>(await fetch(base+'/session/events?after='+after,{headers})).json()};
}
const gift=(id,msg,extra={})=>({giftId:id,common:{msgId:msg},repeatCount:1,user:{displayId:'viewer',avatarThumb:{urlList:['https://p16.tiktokcdn.com/a.webp']}},...extra});

test('freeze and arena expansion receipts reach the same actions shown in the game',async t=>{
 const {connection,read}=await setup(t);
 connection.emit('gift',gift(9947,'freeze',{giftDetails:{giftType:1},repeatEnd:true}));
 connection.emit('gift',gift(5879,'expand',{giftDetails:{giftType:1},repeatEnd:true}));
 await new Promise(r=>setImmediate(r));
 const data=await read();
 assert.deepEqual(data.events.filter(e=>e.giftId).map(e=>e.giftId),['Friendship','Donut']);
});

test('slow profile conversion never holds a gift; late portrait cannot grant it twice',async t=>{
 let finish;
 const {connection,read}=await setup(t,()=>new Promise(r=>finish=r));
 connection.emit('gift',gift(5655,'fast'));
 const immediate=await read();
 assert.equal(immediate.events.length,1);
 assert.equal(immediate.events[0].giftId,'Rose');
 const id=immediate.events[0].sender.portraitId;
 assert.match(id,/^p[a-f0-9]{32}$/);
 connection.emit('streamEnd');
 assert.equal((await read(immediate.cursor)).status,'DRAINING');
 finish(Array(1024).fill(0xff8000));await new Promise(r=>setImmediate(r));
 const late=await read(immediate.cursor);
 assert.equal(late.events.length,1);assert.equal(late.events[0].kind,'Portrait');
 assert.equal(late.events[0].sender.portraitId,id);
 assert.equal(late.events[0].sender.pixels.length,1024);assert.equal(late.events[0].giftId,undefined);
 assert.equal(late.status,'OFFLINE');
});

test('streak deltas arrive before the final packet, with duplicate and reordered updates ignored',async t=>{
 const {connection,read}=await setup(t);
 const send=(msg,count,end=false,group='123456')=>connection.emit('gift',gift(5655,msg,{giftDetails:{giftType:1},groupId:group,repeatCount:count,repeatEnd:end}));
 send('1',1);send('2',3);send('2',3);send('old',2);send('final',3,true);
 send('new',1,false,'654321');send('new-final',1,true,'654321');
 const data=await read();
 const receipts=data.events.filter(e=>e.giftId);
 assert.deepEqual(receipts.map(e=>e.quantity),[1,2,1]);
 assert.equal(new Set(receipts.map(e=>e.id)).size,3);
});

test('streaks without a safe group ID retain final-only counting',async t=>{
 const {connection,read}=await setup(t);
 connection.emit('gift',gift(5655,'partial',{giftDetails:{giftType:1},repeatEnd:false,repeatCount:2}));
 assert.equal((await read()).events.length,0);
 connection.emit('gift',gift(5655,'final',{giftDetails:{giftType:1},repeatEnd:true,repeatCount:2}));
 await new Promise(r=>setImmediate(r));
 assert.equal((await read()).events[0].quantity,2);
});

test('a failed portrait conversion is retried on a later gift instead of poisoning the session',async t=>{
 let calls=0;
 const {connection,read}=await setup(t,async()=>++calls===1?null:Array(1024).fill(123));
 connection.emit('gift',gift(5655,'failed-image'));await new Promise(r=>setImmediate(r));
 const first=await read();assert.equal(first.events[0].giftId,'Rose');
 connection.emit('gift',gift(5655,'retry-image'));await new Promise(r=>setImmediate(r));
 const retry=await read(first.cursor);
 assert.equal(retry.events[0].giftId,'Rose');
 assert.equal(retry.events[1]?.kind,'Portrait');
 assert.equal(retry.events[1]?.sender.pixels.length,1024);
});

test('old game bridges receive inline portraits and never an unrecognized Portrait receipt',async t=>{
 let finish;
 const {connection,read}=await setup(t,()=>new Promise(r=>finish=r),null);
 connection.emit('gift',gift(5655,'legacy'));
 const waiting=await read();assert.equal(waiting.events.length,0);
 finish(Array(256).fill(123));await new Promise(r=>setImmediate(r));
 const delivered=await read();
 assert.equal(delivered.events.length,1);assert.equal(delivered.events[0].giftId,'Rose');
 assert.equal(delivered.events[0].sender.pixels.length,256);
});

test('Heart Me and G.O.A.T. Busker keep sender portraits and grant only unseen gift units',async t=>{
 let finish;
 const {connection,read}=await setup(t,()=>new Promise(r=>finish=r));
 connection.emit('gift',gift(7934,'heart',{giftDetails:{giftType:4},repeatCount:2}));
 connection.emit('gift',gift(7934,'heart',{giftDetails:{giftType:4},repeatCount:2}));
 for(const [msg,count,end]of [['goat1',1,false],['goat3',3,false],['goat-final',3,true]]){
  connection.emit('gift',gift(626064,msg,{giftDetails:{giftType:1},groupId:'626064123',repeatCount:count,repeatEnd:end}));
 }
 const before=await read();
 assert.deepEqual(before.events.map(e=>[e.giftId,e.quantity]),[['HeartMe',2],['GoatBusker',1],['GoatBusker',2]]);
 const ids=before.events.map(e=>e.sender.portraitId);
 assert.ok(ids.every(id=>id===ids[0]));assert.match(ids[0],/^p[a-f0-9]{32}$/);
 finish(Array(1024).fill(0x336699));await new Promise(r=>setImmediate(r));
 const after=await read(before.cursor);
 assert.equal(after.events.length,1);assert.equal(after.events[0].kind,'Portrait');
 assert.equal(after.events[0].sender.portraitId,ids[0]);
 assert.equal(after.events[0].sender.pixels.length,1024);
});

test('older game sessions skip unsupported gacha gifts and continue receiving normal gifts',async t=>{
 const {connection,read}=await setup(t,async()=>null,2,false);
 connection.emit('gift',gift(7934,'old-heart',{giftDetails:{giftType:4}}));
 connection.emit('gift',gift(626064,'old-goat',{giftDetails:{giftType:1},repeatEnd:true}));
 connection.emit('gift',gift(5655,'still-a-rose'));
 const data=await read();
 assert.deepEqual(data.events.filter(e=>e.giftId).map(e=>e.giftId),['Rose']);
 assert.equal(data.unmapped,2);
});

test('follow grants one profile-linked receipt immediately and keeps platform IDs as strings',async t=>{
 let finish;
 const {connection,read,capabilities}=await setup(t,()=>new Promise(r=>finish=r));
 assert.deepEqual(capabilities,{asyncPortraits:true,gacha:true,follow:true});
 const raw={common:{msgId:'follow-9223372036854775801'},user:{id:'9223372036854775801',displayId:'new_follower',avatarThumb:{urlList:['https://p16.tiktokcdn.com/follow.webp']}}};
 connection.emit('follow',raw);connection.emit('follow',raw);
 const first=await read();
 assert.equal(first.events.length,1);assert.equal(first.events[0].giftId,'Follow');
 assert.equal(first.events[0].quantity,1);assert.equal(first.events[0].sender.userId,'9223372036854775801');
 assert.equal(first.events[0].sender.uniqueId,'new_follower');
 const id=first.events[0].sender.portraitId;assert.match(id,/^p[a-f0-9]{32}$/);
 finish(Array(1024).fill(0x123456));await new Promise(r=>setImmediate(r));
 const late=await read(first.cursor);assert.equal(late.events[0].kind,'Portrait');
 assert.equal(late.events[0].sender.portraitId,id);
});

test('legacy sessions never receive unsupported follow actions',async t=>{
 const {connection,read}=await setup(t,async()=>null,2,false,false);
 connection.emit('follow',{common:{msgId:'legacy-follow'},user:{id:'123456',displayId:'follower'}});
 connection.emit('gift',gift(5655,'after-follow'));
 assert.deepEqual((await read()).events.filter(e=>e.giftId).map(e=>e.giftId),['Rose']);
});
