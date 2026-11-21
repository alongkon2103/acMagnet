import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve,relative,isAbsolute} from 'node:path';
import {createBridge} from './http.mjs';
import {TikkiesBridge} from './tikkies.mjs';
import {createHash} from 'node:crypto';
import {DatabaseSync} from 'node:sqlite';

const mapKey='map-test-key-at-least-32-characters-long';
const serviceKey='service-test-key-at-least-32-characters';
const owner='7675212136',subject='subject-device-product-aaaaaaaaaaaa';
const roomId='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const secondRoom='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const effects=['Rose','Roses','Friendship','Donut','Bear','HeartMe','GoatBusker','HelpGacha','Follow','Likes','Remove','Speed','Range','Storm','Shrink','WinAdd','WinRemove'];
const effect=(id='action-1',extra={})=>({id,effect:'Rose',quantity:1,sender:{name:'Viewer',uniqueId:'viewer',userId:'9223372036854775801'},...extra});
const magnetGame='ce4eb329-7ae9-43d4-bf6a-cfde0fe3cee7';
const productA='11111111-1111-4111-8111-111111111111',productB='22222222-2222-4222-8222-222222222222';
const credentialA='product-a-map-credential-at-least-32',credentialB='product-b-map-credential-at-least-32';
const hash=value=>createHash('sha256').update(value).digest('hex');
const gameA={placeIds:['111111111111111'],universeId:'11111111111',commands:['Meteor.Burst:V2','Shared'],credentialHash:hash(credentialA)};
const gameB={placeIds:['222222222222222'],universeId:'22222222222',commands:['Boost-Up','Shared'],credentialHash:hash(credentialB)};
const productHeaders=(gameId,key)=>({'x-tikkies-game':gameId,'x-magnet-key':key});
const removeFixture=dir=>{const child=relative(resolve(tmpdir()),resolve(dir));assert.ok(!isAbsolute(child)&&!child.startsWith('..')&&child.startsWith('magnet-tikkies-'));rmSync(dir,{recursive:true,force:true});};

async function fixture(t,options={}){
 let connectors=0;
 const app=createBridge({key:mapKey,giftMap:{},connect:()=>{connectors++;throw Error('External rooms must not open TikTok');},tikkiesKey:serviceKey,pixels:async()=>null,...options});
 await new Promise(resolve=>app.server.listen(0,'127.0.0.1',resolve));
 t.after(()=>app.close());
 const base='http://127.0.0.1:'+app.server.address().port;
 const request=async(path,body,headers={})=>{
  const response=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{'content-type':'application/json',...headers},...(body===undefined?{}:{body:JSON.stringify(body)})});
  return {...await response.json(),status:response.status};
 };
 const service=(action,body,headers={})=>request('/tikkies/service/'+action,body,{'x-tikkies-key':serviceKey,...headers});
 const map=(path,body,token=roomId,headers={})=>request(path,body,{'x-magnet-key':mapKey,'x-magnet-session':token,...headers});
 const room=(players=[owner],extra={},token=roomId)=>map('/tikkies/room',{placeId:113965026399564,universeId:10775380860,players,nativeBusy:false,...extra},token);
 const bind=(extra={})=>service('bind',{subject,ownerRobloxId:owner,channel:'host',validUntil:Date.now()+40000,...extra});
 const send=(bindingId,events=[effect()],extra={})=>service('events',{subject,bindingId,events,...extra});
 return {app,request,service,map,room,bind,send,get connectors(){return connectors;}};
}

test('two products isolate credentials, rooms, bindings and exact published commands for the same owner',async t=>{
 const f=await fixture(t);
 const a=await f.bind({gameId:productA,game:gameA}),b=await f.bind({gameId:productB,game:gameB});
 assert.equal(a.state,'waiting');assert.equal(b.state,'waiting');assert.notEqual(a.bindingId,b.bindingId);
 const register=(id,key,game)=>f.map('/tikkies/room',{placeId:game.placeIds[0],universeId:game.universeId,players:[owner],nativeBusy:false},roomId,productHeaders(id,key));
 assert.equal((await register(productA,credentialA,gameA)).status,200);
 assert.equal((await f.service('status',{gameId:productB,subject,bindingId:b.bindingId})).state,'waiting','Another product room cannot even make this owner busy');
 assert.equal((await register(productB,credentialB,gameB)).status,200,'Room IDs are scoped by product too');
 for(const [id,key,game]of [[productA,credentialB,gameA],[productB,mapKey,gameB],[productA,mapKey,gameA]])assert.equal((await register(id,key,game)).status,401);
 assert.equal((await register('unregistered-product',credentialA,gameA)).status,401);
 assert.equal((await register(productA,credentialA,gameB)).status,400);
 for(const action of ['status','release','events'])assert.equal((await f.service(action,{gameId:productB,subject,bindingId:a.bindingId,events:[effect()]})).status,404);
 assert.equal((await f.service('status',{subject,bindingId:a.bindingId})).status,404,'Missing product scope is Magnet only');
 for(const name of ['meteor.Burst:V2','Rose','Boost-Up'])assert.equal((await f.send(a.bindingId,[effect('bad-'+name,{effect:name})],{gameId:productA})).status,400);
 assert.equal((await f.send(a.bindingId,[effect('a',{effect:'Meteor.Burst:V2',quantity:10000})],{gameId:productA})).enqueued,1);
 assert.equal((await f.send(b.bindingId,[effect('b',{effect:'Boost-Up',quantity:20})],{gameId:productB})).enqueued,1);
 const pageA=await f.map('/tikkies/events',{acks:[]},roomId,productHeaders(productA,credentialA));
 const pageB=await f.map('/tikkies/events',{acks:[]},roomId,productHeaders(productB,credentialB));
 assert.equal(pageA.binding.id,a.bindingId);assert.deepEqual(pageA.events.map(e=>[e.id,e.effect,e.quantity]),[['a','Meteor.Burst:V2',10000]]);
 assert.equal(pageB.binding.id,b.bindingId);assert.deepEqual(pageB.events.map(e=>[e.id,e.effect,e.quantity]),[['b','Boost-Up',20]]);
 const stale=await f.map('/tikkies/events',{acks:[pageA.events[0].seq],binding:pageA.binding.id,generation:pageA.binding.generation},roomId,productHeaders(productB,credentialB));
 assert.equal(stale.status,409);assert.equal((await f.map('/tikkies/events',{acks:[]},roomId,productHeaders(productB,credentialB))).pending,1);
 await f.map('/tikkies/room/leave',{},roomId,productHeaders(productA,credentialA));
 assert.equal((await f.map('/tikkies/events',{acks:[]},roomId,productHeaders(productB,credentialB))).binding.id,b.bindingId,'Leaving one product cannot disconnect the other');
});

test('trusted bind strictly validates game identity, command identifiers and credential hashes before registration',async t=>{
 const f=await fixture(t);
 const invalid=[null,{}, {...gameA,placeIds:[]},{...gameA,placeIds:['01']},{...gameA,placeIds:[113965026399564]},
  {...gameA,placeIds:['1','1']},{...gameA,universeId:'0'},{...gameA,commands:['bad command']},{...gameA,commands:['_bad']},
  {...gameA,commands:['a'.repeat(81)]},{...gameA,commands:['Same','Same']},{...gameA,credentialHash:null},{...gameA,credentialHash:'not-a-hash'},
  {...gameA,unexpected:'field'}];
 for(const game of invalid){const result=await f.bind({gameId:productA,game});assert.equal(result.status,400,JSON.stringify(game));}
 assert.equal((await f.bind({gameId:productA})).status,400,'New products cannot register without trusted configuration');
 for(const gameId of ['',null,123,'bad game','x'.repeat(161)])assert.equal((await f.bind({gameId,game:gameA})).status,400);
 assert.equal((await f.bind({game:gameA})).status,400,'A missing game ID cannot register another product as legacy Magnet');
 const b=await f.bind({gameId:productA,game:{...gameA,universeId:null,commands:[]}});assert.equal(b.status,200,'A new API game may have no published commands');
 assert.equal((await f.send(b.bindingId,[effect()],{gameId:productA})).status,400);
 const legacy=await f.bind();assert.equal(legacy.status,200);await f.room();
 assert.equal((await f.map('/tikkies/events',{acks:[]},roomId,productHeaders(magnetGame,mapKey))).status,200);
});

test('catalog edits preserve exact accepted retries and paid queues while rejecting new retired commands',async t=>{
 const f=await fixture(t);const b=await f.bind({gameId:productA,game:gameA});
 const paid=effect('before-edit',{effect:'Meteor.Burst:V2',quantity:51});
 assert.equal((await f.send(b.bindingId,[paid],{gameId:productA})).enqueued,1);
 await f.map('/tikkies/room',{placeId:gameA.placeIds[0],universeId:gameA.universeId,players:[owner],nativeBusy:false},roomId,productHeaders(productA,credentialA));
 assert.equal((await f.service('status',{gameId:productA,subject,bindingId:b.bindingId})).state,'connected');
 const edited=await f.bind({gameId:productA,game:{...gameA,commands:['Shared'],placeIds:['333333333333333']}});
 assert.equal(edited.bindingId,b.bindingId);assert.equal(edited.pending,1);
 assert.equal(edited.state,'waiting','A registered room with a retired place identity must lose its binding');
 assert.equal((await f.map('/tikkies/events',{acks:[]},roomId,productHeaders(productA,credentialA))).status,409);
 assert.equal((await f.send(b.bindingId,[paid],{gameId:productA})).enqueued,0,'An exact acknowledged intake retry cannot be stranded by later catalog edits');
 assert.equal((await f.send(b.bindingId,[{...paid,id:'after-edit'}],{gameId:productA})).status,400);
 assert.equal((await f.send(b.bindingId,[{...paid,quantity:52}],{gameId:productA})).status,409,'Receipt conflicts remain enforced for retired commands');
 assert.equal((await f.map('/tikkies/room',{placeId:gameA.placeIds[0],universeId:gameA.universeId,players:[owner],nativeBusy:false},roomId,productHeaders(productA,credentialA))).status,400);
 await f.map('/tikkies/room',{placeId:'333333333333333',universeId:gameA.universeId,players:[owner],nativeBusy:false},roomId,productHeaders(productA,credentialA));
 const page=await f.map('/tikkies/events',{acks:[]},roomId,productHeaders(productA,credentialA));assert.equal(page.events[0].quantity,51);
 for(const response of [b,edited,page])for(const secret of [credentialA,gameA.credentialHash])assert.equal(JSON.stringify(response).includes(secret),false,'Configuration credentials never enter service/map responses');
});

test('trusted replay-only IDs confirm only exact durable receipts even when relay catalog is stale',async t=>{
 const f=await fixture(t);const b=await f.bind({gameId:productA,game:gameA});
 const paid=effect('confirmed-before-removal',{effect:'Meteor.Burst:V2'});
 assert.equal((await f.send(b.bindingId,[paid],{gameId:productA})).enqueued,1);
 const exact=await f.send(b.bindingId,[paid],{gameId:productA,replayOnlyIds:[paid.id]});assert.equal(exact.enqueued,0);assert.deepEqual(exact.duplicates,[paid.id]);
 const fresh={...paid,id:'not-persisted'};
 assert.equal((await f.send(b.bindingId,[fresh],{gameId:productA,replayOnlyIds:[fresh.id]})).status,400,'Stale relay command membership cannot admit replay-only intake');
 assert.equal((await f.send(b.bindingId,[{...paid,quantity:2}],{gameId:productA,replayOnlyIds:[paid.id]})).status,409);
 const accepted=await f.send(b.bindingId,[paid,effect('current',{effect:'Shared'})],{gameId:productA,replayOnlyIds:[paid.id]});assert.equal(accepted.enqueued,1);
 for(const replayOnlyIds of [null,{},'id',[paid.id,paid.id],['not-in-batch'],[1]])assert.equal((await f.send(b.bindingId,[paid],{gameId:productA,replayOnlyIds})).status,400);
 assert.equal((await f.service('status',{gameId:productA,subject,bindingId:b.bindingId})).pending,2);
});

test('product registry and queues replay after restart with backpressure, profiles and fenced JSON ACKs',async t=>{
 const dir=mkdtempSync(join(tmpdir(),'magnet-tikkies-products-'));const databasePath=join(dir,'queue.sqlite');let restarted;
 const f=await fixture(t,{tikkiesDatabasePath:databasePath,tikkiesOptions:{maxPending:2},pixels:async()=>Array(1024).fill(0x112233)});
 t.after(async()=>{await f.app.close();await restarted?.app.close();removeFixture(dir);});
 const a=await f.bind({gameId:productA,game:gameA});
 const input=effect('persisted',{effect:'Meteor.Burst:V2',quantity:9999,sender:{name:'Profile',uniqueId:'profile',avatarUrl:'https://p16.tiktokcdn.com/profile.webp'}});
 assert.equal((await f.send(a.bindingId,[input],{gameId:productA})).status,200);
 assert.equal((await f.send(a.bindingId,[effect('overflow',{effect:'Shared'})],{gameId:productA})).status,429);
 await new Promise(resolve=>setTimeout(resolve,30));await f.app.close();
 restarted=await fixture(t,{tikkiesDatabasePath:databasePath,tikkiesOptions:{maxPending:2},pixels:async()=>Array(1024).fill(0x112233)});
 const registered=await restarted.map('/tikkies/room',{placeId:gameA.placeIds[0],universeId:gameA.universeId,players:[owner],nativeBusy:false},roomId,productHeaders(productA,credentialA));assert.equal(registered.status,200,'Persisted registry authenticates maps before the next bind');
 const rebound=await restarted.bind({gameId:productA,game:gameA});assert.equal(rebound.bindingId,a.bindingId);
 const page=await restarted.map('/tikkies/events',{acks:[]},roomId,productHeaders(productA,credentialA));
 assert.equal(page.pending,2);assert.equal(page.events.find(e=>e.id==='persisted').quantity,9999);assert.ok(page.events.some(e=>e.kind==='Portrait'));
 assert.equal((await restarted.send(a.bindingId,[input],{gameId:productA})).enqueued,0);
 const ack={binding:a.bindingId,generation:page.binding.generation,acks:page.events.map(e=>e.seq)};
 assert.equal((await restarted.map('/tikkies/events',{...ack,generation:ack.generation+1},roomId,productHeaders(productA,credentialA))).status,409);
 assert.equal((await restarted.map('/tikkies/events',ack,roomId,productHeaders(productA,credentialA))).pending,0);
 const rotated='product-a-rotated-map-credential-at-least-32';
 assert.equal((await restarted.bind({gameId:productA,game:{...gameA,credentialHash:hash(rotated)}})).status,200);
 assert.equal((await restarted.map('/tikkies/events',{acks:[]},roomId,productHeaders(productA,credentialA))).status,401);
 assert.equal((await restarted.map('/tikkies/events',{acks:[]},roomId,productHeaders(productA,rotated))).status,200);
});

test('pre-product SQLite queues, receipt IDs and cached portraits migrate without losing replay',async t=>{
 const dir=mkdtempSync(join(tmpdir(),'magnet-tikkies-legacy-'));const databasePath=join(dir,'queue.sqlite');
 const legacyId='cccccccc-cccc-cccc-cccc-cccccccccccc',now=Date.now(),db=new DatabaseSync(databasePath);
 const input=effect('old-paid',{quantity:777,sender:{name:'Legacy',uniqueId:'legacy',seed:7}});
 const normalized={id:'old-paid',effect:'Rose',giftId:'Rose',quantity:777,sender:{name:'Legacy',uniqueId:'legacy',handle:'legacy',seed:7}};
 db.exec(`CREATE TABLE tk_rooms(id TEXT PRIMARY KEY,players TEXT NOT NULL,native_busy INTEGER NOT NULL,online INTEGER NOT NULL,last_seen INTEGER NOT NULL);
 CREATE TABLE tk_bindings(id TEXT PRIMARY KEY,subject TEXT NOT NULL,owner TEXT NOT NULL,channel TEXT NOT NULL,expires INTEGER NOT NULL,enabled INTEGER NOT NULL,room_id TEXT,generation INTEGER NOT NULL DEFAULT 0,seq INTEGER NOT NULL DEFAULT 0,expired_tests INTEGER NOT NULL DEFAULT 0,portrait_fallbacks INTEGER NOT NULL DEFAULT 0,created INTEGER NOT NULL,last_activity INTEGER NOT NULL DEFAULT 0,UNIQUE(subject,owner,channel));
 CREATE UNIQUE INDEX tk_room_owner ON tk_bindings(room_id) WHERE room_id IS NOT NULL;
 CREATE TABLE tk_events(binding TEXT NOT NULL REFERENCES tk_bindings(id),seq INTEGER NOT NULL,id TEXT NOT NULL,priority INTEGER NOT NULL,payload TEXT NOT NULL,received INTEGER NOT NULL,test_expires INTEGER,portrait_id TEXT,PRIMARY KEY(binding,seq),UNIQUE(binding,id));
 CREATE TABLE tk_receipts(binding TEXT NOT NULL REFERENCES tk_bindings(id),id TEXT NOT NULL,fingerprint TEXT NOT NULL,PRIMARY KEY(binding,id));
 CREATE TABLE tk_portraits(binding TEXT NOT NULL REFERENCES tk_bindings(id),id TEXT NOT NULL,url TEXT NOT NULL,pixels TEXT,next_attempt INTEGER NOT NULL DEFAULT 0,attempts INTEGER NOT NULL DEFAULT 0,offered_generation INTEGER NOT NULL DEFAULT -1,created INTEGER NOT NULL,last_used INTEGER NOT NULL DEFAULT 0,test_until INTEGER,PRIMARY KEY(binding,id));`);
 db.prepare('INSERT INTO tk_rooms VALUES(?,?,0,1,?)').run(roomId,JSON.stringify([owner]),now);
 db.prepare('INSERT INTO tk_bindings VALUES(?,?,?,?,?,1,?,3,1,0,0,?,?)').run(legacyId,subject,owner,'host',now+40000,roomId,now,now);
 db.prepare('INSERT INTO tk_events VALUES(?,1,?,1,?,?,NULL,NULL)').run(legacyId,'old-paid',JSON.stringify({...normalized,seq:1,receivedAt:now}),now);
 db.prepare('INSERT INTO tk_receipts VALUES(?,?,?)').run(legacyId,'old-paid',hash(JSON.stringify({event:normalized,url:null})));
 db.prepare('INSERT INTO tk_portraits(binding,id,url,pixels,created,last_used) VALUES(?,?,?,?,?,?)').run(legacyId,'p'+'1'.repeat(32),'https://p16.tiktokcdn.com/old.webp',JSON.stringify(Array(1024).fill(0x112233)),now,now);db.close();
 const f=await fixture(t,{tikkiesDatabasePath:databasePath});t.after(()=>removeFixture(dir));await f.room();const rebound=await f.bind();assert.equal(rebound.bindingId,legacyId);
 const page=await f.map('/tikkies/events',{acks:[]});assert.equal(page.events.find(e=>e.id==='old-paid').quantity,777);assert.ok(page.events.some(e=>e.kind==='Portrait'));assert.ok(page.binding.generation>3);
 assert.equal((await f.send(legacyId,[input])).enqueued,0,'The old fingerprint survives migration');
 const second=await f.bind({gameId:productA,game:gameA});assert.equal(second.status,200);assert.notEqual(second.bindingId,legacyId,'Old uniqueness must not prevent the same owner/channel in another product');
 assert.equal((await f.map('/tikkies/events',{acks:[]},roomId)).binding.id,legacyId);
 assert.equal((await f.map('/tikkies/events',{binding:legacyId,generation:page.binding.generation,acks:page.events.map(e=>e.seq)})).pending,0);
});

test('Roblox POST polls acknowledge through JSON without restricted header characters',async t=>{
 const f=await fixture(t);await f.room();const b=await f.bind();await f.send(b.bindingId,[effect('post-ack',{quantity:10})]);
 const page=await f.map('/tikkies/events',{waitMs:0,limit:100,acks:[]});
 assert.equal(page.status,200);assert.equal(page.events[0].quantity,10);
 const ack={waitMs:0,limit:100,binding:page.binding.id,generation:page.binding.generation,acks:page.events.map(e=>e.seq)};
 const done=await f.map('/tikkies/events',ack);assert.equal(done.status,200);assert.equal(done.pending,0);
 assert.equal((await f.map('/tikkies/events',ack)).pending,0,'Repeated ACK is harmless');
 assert.equal((await f.map('/tikkies/events')).status,200,'Legacy GET remains available');
 await f.send(b.bindingId,[effect('post-fenced')]);
 assert.equal((await f.map('/tikkies/events',{...ack,generation:ack.generation+1})).status,409);
 assert.equal((await f.map('/tikkies/events',{waitMs:0,limit:100,acks:[]})).pending,1,'A stale POST cannot erase another generation');
 for(const invalid of [{acks:'[1]'},{acks:null},{acks:[1],binding:b.bindingId,generation:0},{waitMs:'0'},{limit:'100'},{acks:[],owner:'123'},{acks:[],binding:'invalid'}])assert.equal((await f.map('/tikkies/events',invalid)).status,400);
});

test('separate service auth binds waiting and auto-connects only authoritative matching rooms',async t=>{
 const f=await fixture(t);
 assert.equal((await f.service('bind',{},{'x-tikkies-key':mapKey})).status,401);
 const binding=await f.bind();assert.equal(binding.status,200);assert.equal(binding.state,'waiting');
 assert.match(binding.bindingId,/^[a-f0-9-]{36}$/);assert.equal(binding.ownerRobloxId,owner);
 assert.equal((await f.room(['123'],{placeId:1})).status,400);
 await f.room(['123']);assert.equal((await f.service('status',{subject,bindingId:binding.bindingId})).state,'waiting');
 await f.room();const status=await f.service('status',{subject,bindingId:binding.bindingId});
 assert.equal(status.state,'connected');assert.equal(status.roomId,roomId);assert.equal(f.connectors,0);
 assert.equal('key' in status,false);
});

test('native-busy rooms and an existing owner are exclusive; two users and rooms isolate queues',async t=>{
 const f=await fixture(t);await f.room([owner,'123'],{nativeBusy:true});
 const a=await f.bind();assert.equal(a.state,'busy');
 await f.room([owner,'123']);
 const b=await f.bind({subject:'subject-other-device-bbbbbbbbbbbb',ownerRobloxId:'123'});assert.equal(b.state,'busy');
 await f.room(['123'],{},secondRoom);
 const bs=await f.service('status',{subject:'subject-other-device-bbbbbbbbbbbb',bindingId:b.bindingId});assert.equal(bs.state,'connected');
 await f.send(a.bindingId);
 await f.service('events',{subject:'subject-other-device-bbbbbbbbbbbb',bindingId:b.bindingId,events:[effect('other',{effect:'Bear'})]});
 assert.equal((await f.map('/tikkies/events')).events[0].effect,'Rose');
 assert.equal((await f.map('/tikkies/events',undefined,secondRoom)).events[0].effect,'Bear');
 for(const action of ['events','status','release'])assert.equal((await f.service(action,{subject:'subject-other-device-bbbbbbbbbbbb',bindingId:a.bindingId,events:[effect()]})).status,404);
});

test('all named effects are durable, duplicates stable and conflicting same-ID batches rejected atomically',async t=>{
 const f=await fixture(t);await f.room();const b=await f.bind();
 const batch=effects.map((name,i)=>effect('effect-'+i,{effect:name,quantity:10000,triggerType:'gift',test:true}));
 const accepted=await f.send(b.bindingId,batch);assert.equal(accepted.accepted.length,17);assert.equal(accepted.pending,17);
 const duplicate=await f.send(b.bindingId,batch);assert.equal(duplicate.enqueued,0);assert.equal(duplicate.duplicates.length,17);
 const conflict=await f.send(b.bindingId,[effect('new-first'),effect('effect-0',{quantity:2})]);assert.equal(conflict.status,409);assert.equal(conflict.error,'RECEIPT_CONFLICT');
 const page=await f.map('/tikkies/events');assert.equal(page.pending,17);assert.equal(page.events.length,17);
 assert.equal(page.events[0].sender.userId,'9223372036854775801');assert.equal(page.events[0].quantity,10000);
 for(const invalid of [effect('bad',{effect:'ArbitraryCode'}),effect('bad',{quantity:0}),effect('bad',{quantity:1.5}),effect('bad',{quantity:10001}),effect('x'.repeat(101)),effect('bad',{sender:{name:'a',userId:9223372036854776000}})])assert.equal((await f.send(b.bindingId,[invalid])).status,400);
 assert.equal((await f.send(b.bindingId,Array(101).fill(effect()))).status,400);
});

test('release and rebind preserve receipts and fence stale room-generation acknowledgments',async t=>{
 const f=await fixture(t);await f.room();const b=await f.bind();await f.send(b.bindingId);
 const original=await f.map('/tikkies/events');const seq=original.events[0].seq;
 assert.equal((await f.map('/tikkies/events',undefined,roomId,{'x-magnet-ack':JSON.stringify([seq])})).status,409);
 await f.service('release',{subject,bindingId:b.bindingId});assert.equal((await f.map('/tikkies/events')).events.length,0);
 const rebound=await f.bind();assert.equal(rebound.bindingId,b.bindingId);assert.equal(rebound.pending,1);
 const current=await f.map('/tikkies/events');assert.ok(current.binding.generation>original.binding.generation);
 const stale={'x-magnet-ack':JSON.stringify([seq]),'x-magnet-binding':b.bindingId,'x-magnet-generation':String(original.binding.generation)};
 assert.equal((await f.map('/tikkies/events',undefined,roomId,stale)).status,409);
 const valid={...stale,'x-magnet-generation':String(current.binding.generation)};
 assert.equal((await f.map('/tikkies/events',undefined,roomId,valid)).pending,0);
 assert.equal((await f.send(b.bindingId)).duplicates.length,1);
});

test('account switches and room owner departure keep pending work with its original binding',async t=>{
 const f=await fixture(t);await f.room([owner,'123']);const a=await f.bind();await f.send(a.bindingId);
 const b=await f.bind({ownerRobloxId:'123'});assert.notEqual(b.bindingId,a.bindingId);
 assert.equal((await f.service('status',{subject,bindingId:a.bindingId})).state,'paused');
 assert.equal((await f.map('/tikkies/events')).binding.id,b.bindingId);
 await f.room([owner]);assert.equal((await f.service('status',{subject,bindingId:b.bindingId})).state,'waiting');
 const resumed=await f.bind();assert.equal(resumed.bindingId,a.bindingId);assert.equal(resumed.pending,1);
});

test('lease heartbeat requires a bounded trusted validUntil and expired leases cannot deliver or ingest',async t=>{
 let now=Date.now();const f=await fixture(t,{tikkiesOptions:{now:()=>now}});await f.room();
 assert.equal((await f.bind({validUntil:now+46000})).status,400);
 const b=await f.bind({validUntil:now+1000});await f.send(b.bindingId);
 now+=1500;assert.equal((await f.map('/tikkies/events')).binding,null);
 assert.equal((await f.send(b.bindingId,[effect('expired')])).error,'LEASE_EXPIRED');
 const renewed=await f.service('status',{subject,bindingId:b.bindingId,validUntil:now+40000});assert.equal(renewed.state,'connected');
 assert.equal(renewed.pending,1);
});

test('backend restart retains external queues without native connector recovery',async t=>{
 const dir=mkdtempSync(join(tmpdir(),'magnet-tikkies-'));const path=join(dir,'tikkies.sqlite');
 let last;t.after(async()=>{await last?.app.close();removeFixture(dir);});
 const first=await fixture(t,{tikkiesDatabasePath:path});await first.room();const b=await first.bind();await first.send(b.bindingId);
 await first.app.close();
 const second=last=await fixture(t,{tikkiesDatabasePath:path});
 const status=await second.service('status',{subject,bindingId:b.bindingId});assert.equal(status.pending,1);assert.equal(status.state,'waiting');
 await second.room();const page=await second.map('/tikkies/events');assert.equal(page.events[0].id,'action-1');assert.equal(second.connectors,0);
});

test('portrait jobs persist before admission and recover after restart without holding gameplay',async t=>{
 const dir=mkdtempSync(join(tmpdir(),'magnet-tikkies-portrait-'));const path=join(dir,'tikkies.sqlite');
 let last;t.after(async()=>{await last?.app.close();removeFixture(dir);});
 const first=await fixture(t,{tikkiesDatabasePath:path,pixels:()=>new Promise(()=>{})});await first.room();const b=await first.bind();
 await first.send(b.bindingId,[effect('profile',{sender:{name:'Viewer',uniqueId:'viewer',avatarUrl:'https://p16.tiktokcdn.com/profile.webp'}})]);
 const page=await first.map('/tikkies/events');assert.equal(page.events[0].effect,'Rose');assert.match(page.events[0].sender.portraitId,/^p[a-f0-9]{32}$/);
 const portraitId=page.events[0].sender.portraitId;await first.app.close();
 const second=last=await fixture(t,{tikkiesDatabasePath:path,pixels:async()=>Array(1024).fill(0x112233)});await second.room();
 let result;
 for(let i=0;i<30;i++){result=await second.map('/tikkies/events');if(result.events.some(e=>e.kind==='Portrait'))break;await new Promise(r=>setTimeout(r,10));}
 const portrait=result.events.find(e=>e.kind==='Portrait');assert.ok(portrait);assert.equal(portrait.sender.portraitId,portraitId);assert.equal(portrait.sender.pixels.length,1024);
 assert.equal(result.events.filter(e=>e.effect==='Rose').length,1);
 assert.equal((await second.send(b.bindingId,[effect('unsafe',{sender:{name:'a',avatarUrl:'https://localhost/a.png'}})])).status,400);
});

test('bounded admission returns backpressure without partial batch writes or silently lost portraits',async t=>{
 const f=await fixture(t,{tikkiesOptions:{maxPending:2,maxPortraits:1}});await f.room();const b=await f.bind();
 assert.equal((await f.send(b.bindingId,[effect('a'),effect('b')])).accepted.length,2);
 const full=await f.send(b.bindingId,[effect('c')]);assert.equal(full.status,429);assert.equal(full.error,'BACKPRESSURE');
 assert.equal((await f.map('/tikkies/events')).pending,2);
});

test('native-only configuration leaves Tikkies routes disabled',async t=>{
 const f=await fixture(t,{tikkiesKey:undefined});
 assert.equal((await f.service('bind',{})).status,404);
 assert.equal((await f.map('/tikkies/room',{})).status,404);
});

test('room rebinding reuses pending portraits instead of growing duplicate profile receipts',async t=>{
 const f=await fixture(t,{pixels:async()=>Array(1024).fill(0x112233)});await f.room();const b=await f.bind();
 await f.send(b.bindingId,[effect('profile',{sender:{name:'Viewer',avatarUrl:'https://p16.tiktokcdn.com/profile.webp'}})]);
 let page;for(let i=0;i<30;i++){page=await f.map('/tikkies/events');if(page.pending===2)break;await new Promise(r=>setTimeout(r,10));}
 assert.equal(page.pending,2);
 for(let i=0;i<3;i++){await f.service('release',{subject,bindingId:b.bindingId});await f.bind();assert.equal((await f.map('/tikkies/events')).pending,2);}
});

test('global admission reserves durable portrait jobs across different bindings',async t=>{
 const f=await fixture(t,{tikkiesOptions:{maxTotalPending:3},pixels:()=>new Promise(()=>{})});await f.room([owner,'123']);
 const a=await f.bind(),b=await f.bind({subject:'subject-other-device-bbbbbbbbbbbb',ownerRobloxId:'123'});
 const profile=effect('profile',{sender:{name:'Viewer',avatarUrl:'https://p16.tiktokcdn.com/profile.webp'}});
 assert.equal((await f.send(a.bindingId,[profile])).status,200);
 const second=await f.service('events',{subject:'subject-other-device-bbbbbbbbbbbb',bindingId:b.bindingId,events:[profile]});
 assert.equal(second.status,429);assert.equal(second.error,'BACKPRESSURE');assert.equal(second.pending,undefined);
 assert.equal((await f.service('status',{subject:'subject-other-device-bbbbbbbbbbbb',bindingId:b.bindingId})).pending,0);
});

test('released bindings ignore heartbeat owner spoofing and never reactivate until explicit bind',async t=>{
 const f=await fixture(t);await f.room();const b=await f.bind();await f.send(b.bindingId);
 await f.service('release',{subject,bindingId:b.bindingId});
 const heartbeat=await f.service('status',{subject,bindingId:b.bindingId,ownerRobloxId:'123',validUntil:Date.now()+40000});
 assert.equal(heartbeat.state,'paused');assert.equal(heartbeat.ownerRobloxId,owner);assert.equal(heartbeat.pending,1);
 assert.equal((await f.send(b.bindingId,[effect('blocked')],{ownerRobloxId:'123',validUntil:Date.now()+40000})).status,403);
 assert.equal((await f.map('/tikkies/events')).binding,null);
});

test('long polling wakes on admitted effects and later paid work remains visible behind a blocked page',async t=>{
 const f=await fixture(t);await f.room();const b=await f.bind();
 const waiting=f.map('/tikkies/events?waitMs=1000&limit=100');await new Promise(r=>setTimeout(r,20));const start=performance.now();
 await f.send(b.bindingId);const awakened=await waiting;assert.equal(awakened.events[0].id,'action-1');assert.ok(performance.now()-start<500);
 const fences={'x-tikkies-binding':b.bindingId,'x-tikkies-generation':String(awakened.binding.generation),'x-magnet-ack':'[1]'};
 assert.equal((await f.map('/tikkies/events',undefined,roomId,fences)).pending,0);
 for(let page=0;page<2;page++)await f.send(b.bindingId,Array.from({length:75},(_,i)=>effect('blocked-'+(page*75+i))));
 const first=await f.map('/tikkies/events');assert.equal(first.events.length,100);
 await f.send(b.bindingId,[effect('later-paid',{effect:'Bear'}),effect('urgent',{effect:'Friendship'})]);
 const next=await f.map('/tikkies/events');assert.equal(next.events[0].effect,'Friendship');assert.ok(next.events.some(e=>e.id==='later-paid'));assert.equal(next.pending,152);
});

test('portrait and receipt admission roll back together on SQLite failure and the same ID can retry',()=>{
 const bridge=new TikkiesBridge({key:serviceKey,mapKey,pixels:()=>new Promise(()=>{})});
 try{
  const b=bridge.bind({subject,ownerRobloxId:owner,channel:'host',validUntil:Date.now()+40000});
  const input={subject,bindingId:b.bindingId,events:[effect('atomic',{sender:{name:'Viewer',avatarUrl:'https://p16.tiktokcdn.com/profile.webp'}})]};
  bridge.db.exec("CREATE TRIGGER fail_event BEFORE INSERT ON tk_events BEGIN SELECT RAISE(ABORT,'simulated write fault');END;");
  assert.throws(()=>bridge.service('events',input),/simulated write fault/);
  assert.equal(bridge.db.prepare('SELECT COUNT(*) AS n FROM tk_receipts').get().n,0);
  assert.equal(bridge.db.prepare('SELECT COUNT(*) AS n FROM tk_portraits').get().n,0);
  bridge.db.exec('DROP TRIGGER fail_event');const retry=bridge.service('events',input);
  assert.deepEqual(retry.accepted,['atomic']);assert.equal(retry.pending,2);
  assert.equal(bridge.db.prepare('SELECT COUNT(*) AS n FROM tk_portraits').get().n,1);
 }finally{bridge.close();}
});

test('only manual tests expire after sixty seconds and pending includes unfinished portraits',async t=>{
 let now=Date.now();const f=await fixture(t,{tikkiesOptions:{now:()=>now},pixels:()=>new Promise(()=>{})});await f.room();const b=await f.bind();
 const manual=effect('manual',{test:true,sender:{name:'TestViewer',avatarUrl:'https://p16.tiktokcdn.com/test.webp'}});
 const accepted=await f.send(b.bindingId,[manual,effect('real-paid')]);assert.equal(accepted.pending,3);assert.equal(accepted.portraitPending,1);
 now+=61000;const status=await f.service('status',{subject,bindingId:b.bindingId,validUntil:now+40000});
 assert.equal(status.pending,1);assert.equal(status.portraitPending,0);assert.equal(status.expiredTests,1);
 await f.room();const page=await f.map('/tikkies/events');assert.deepEqual(page.events.map(e=>e.id),['real-paid']);
 const retry=await f.send(b.bindingId,[manual]);assert.equal(retry.enqueued,0);assert.equal(retry.pending,1);
});

test('a portrait shared by manual and real effects keeps its durable real-event job',async t=>{
 let now=Date.now();const f=await fixture(t,{tikkiesOptions:{now:()=>now},pixels:()=>new Promise(()=>{})});await f.room();const b=await f.bind();
 const sender={name:'Viewer',uniqueId:'viewer',avatarUrl:'https://p16.tiktokcdn.com/shared.webp'};
 await f.send(b.bindingId,[effect('manual',{test:true,sender}),effect('paid',{sender})]);
 now+=61000;const status=await f.service('status',{subject,bindingId:b.bindingId,validUntil:now+40000});
 assert.equal(status.pending,2);assert.equal(status.portraitPending,1);assert.equal(status.expiredTests,1);
});

test('historical offline room records do not exhaust room capacity or delete pending effects',async t=>{
 const f=await fixture(t,{tikkiesOptions:{maxRooms:1}});await f.room();const b=await f.bind();await f.send(b.bindingId);
 await f.map('/tikkies/room/leave',{});
 assert.equal((await f.room([owner],{},secondRoom)).status,200);
 const page=await f.map('/tikkies/events',undefined,secondRoom);assert.equal(page.binding.id,b.bindingId);assert.equal(page.pending,1);
});

test('expiration wakes room long polls even when only a manual portrait job remained',async t=>{
 let now=Date.now();const created=now;
 const f=await fixture(t,{tikkiesOptions:{now:()=>now},pixels:()=>new Promise(()=>{})});await f.room();const b=await f.bind();
 await f.send(b.bindingId,[effect('manual',{test:true,sender:{name:'TestViewer',avatarUrl:'https://p16.tiktokcdn.com/test.webp'}})]);
 now=created+59000;await f.service('status',{subject,bindingId:b.bindingId,validUntil:now+40000});await f.room();
 const page=await f.map('/tikkies/events');
 const ack={'x-magnet-binding':b.bindingId,'x-magnet-generation':String(page.binding.generation),'x-magnet-ack':JSON.stringify([page.events[0].seq])};
 assert.equal((await f.map('/tikkies/events',undefined,roomId,ack)).pending,1);
 const waiting=f.map('/tikkies/events?waitMs=1000');await new Promise(r=>setTimeout(r,20));const start=performance.now();
 now=created+61000;await f.service('status',{subject,bindingId:b.bindingId});
 assert.equal((await waiting).pending,0);assert.ok(performance.now()-start<500,'Expired portrait did not wake its room');
});

test('releasing a drained binding does not report already delivered cached portraits as pending',async t=>{
 const f=await fixture(t,{pixels:async()=>Array(1024).fill(0x112233)});await f.room();const b=await f.bind();
 await f.send(b.bindingId,[effect('profile',{sender:{name:'Viewer',avatarUrl:'https://p16.tiktokcdn.com/profile.webp'}})]);
 let page;for(let i=0;i<30;i++){page=await f.map('/tikkies/events');if(page.queued===2)break;await new Promise(r=>setTimeout(r,10));}
 const ack={'x-magnet-binding':b.bindingId,'x-magnet-generation':String(page.binding.generation),'x-magnet-ack':JSON.stringify(page.events.map(e=>e.seq))};
 assert.equal((await f.map('/tikkies/events',undefined,roomId,ack)).pending,0);
 assert.equal((await f.service('release',{subject,bindingId:b.bindingId})).pending,0);
});

test('binding capacity recycles only old drained history including acknowledged profile metadata',async t=>{
 let now=Date.now();const f=await fixture(t,{tikkiesOptions:{now:()=>now,maxBindings:2},pixels:async()=>Array(1024).fill(0x112233)});await f.room();
 const old=await f.bind();await f.send(old.bindingId,[effect('drained',{sender:{name:'Viewer',avatarUrl:'https://p16.tiktokcdn.com/profile.webp'}})]);
 let page;for(let i=0;i<30;i++){page=await f.map('/tikkies/events');if(page.queued===2)break;await new Promise(r=>setTimeout(r,10));}
 await f.map('/tikkies/events',undefined,roomId,{'x-magnet-binding':old.bindingId,'x-magnet-generation':String(page.binding.generation),'x-magnet-ack':JSON.stringify(page.events.map(e=>e.seq))});
 await f.service('release',{subject,bindingId:old.bindingId});
 const recent=await f.bind({channel:'recent'});
 now+=24*60*60*1000+1;
 await f.service('status',{subject,bindingId:recent.bindingId,validUntil:now+40000});
 const next=await f.bind({channel:'new_channel',validUntil:now+40000});assert.equal(next.status,200);
 assert.equal((await f.service('status',{subject,bindingId:old.bindingId})).status,404);
 assert.equal((await f.service('status',{subject,bindingId:recent.bindingId})).status,200);
});

test('binding capacity never recycles old pending LIVE effects or unfinished portrait jobs',async t=>{
 let now=Date.now();const f=await fixture(t,{tikkiesOptions:{now:()=>now,maxBindings:2},pixels:()=>new Promise(()=>{})});await f.room();
 const paid=await f.bind();await f.send(paid.bindingId,[effect('paid')]);
 const image=await f.bind({channel:'image'});await f.send(image.bindingId,[effect('profile',{sender:{name:'Viewer',avatarUrl:'https://p16.tiktokcdn.com/profile.webp'}})]);
 const page=await f.map('/tikkies/events');
 await f.map('/tikkies/events',undefined,roomId,{'x-magnet-binding':image.bindingId,'x-magnet-generation':String(page.binding.generation),'x-magnet-ack':JSON.stringify(page.events.map(e=>e.seq))});
 await f.service('release',{subject,bindingId:image.bindingId});
 now+=24*60*60*1000+1;
 const rejected=await f.bind({channel:'third',validUntil:now+40000});assert.equal(rejected.status,429);assert.equal(rejected.error,'BINDING_CAPACITY');
 assert.equal((await f.service('status',{subject,bindingId:paid.bindingId})).pending,1);
 const pendingImage=await f.service('status',{subject,bindingId:image.bindingId});assert.equal(pendingImage.pending,1);assert.equal(pendingImage.portraitPending,1);
});

test('same-owner old binding resumes its stable ID at capacity without recycling its history',async t=>{
 let now=Date.now();const f=await fixture(t,{tikkiesOptions:{now:()=>now,maxBindings:2}});
 const original=await f.bind();await f.service('release',{subject,bindingId:original.bindingId});const other=await f.bind({channel:'other'});
 now+=24*60*60*1000+1;
 const resumed=await f.bind({validUntil:now+40000});assert.equal(resumed.status,200);assert.equal(resumed.bindingId,original.bindingId);
 assert.equal((await f.service('status',{subject,bindingId:other.bindingId})).status,200);
});

test('recent activity protects expired drained bindings even when their creation is older than a day',async t=>{
 let now=Date.now();const f=await fixture(t,{tikkiesOptions:{now:()=>now,maxBindings:2}});
 const first=await f.bind();await f.service('release',{subject,bindingId:first.bindingId});const second=await f.bind({channel:'other'});
 now+=24*60*60*1000-60000;
 await f.service('status',{subject,bindingId:first.bindingId});await f.service('release',{subject,bindingId:second.bindingId});
 now+=120000;
 const rejected=await f.bind({channel:'third',validUntil:now+40000});assert.equal(rejected.status,429);assert.equal(rejected.error,'BINDING_CAPACITY');
});

test('a drained profile slot is recycled so a new viewer effect and portrait are accepted',async t=>{
 const f=await fixture(t,{tikkiesOptions:{maxPortraits:1},pixels:async()=>Array(1024).fill(0x112233)});await f.room();const b=await f.bind();
 const first=effect('first',{sender:{name:'First',uniqueId:'first',avatarUrl:'https://p16.tiktokcdn.com/first.webp'}});
 await f.send(b.bindingId,[first]);
 let page;for(let i=0;i<30;i++){page=await f.map('/tikkies/events');if(page.queued===2)break;await new Promise(r=>setTimeout(r,10));}
 const oldPortrait=page.events.find(e=>e.kind==='Portrait').sender.portraitId;
 const ack={'x-magnet-binding':b.bindingId,'x-magnet-generation':String(page.binding.generation),'x-magnet-ack':JSON.stringify(page.events.map(e=>e.seq))};
 assert.equal((await f.map('/tikkies/events',undefined,roomId,ack)).pending,0);
 const second=await f.send(b.bindingId,[effect('second',{sender:{name:'Second',uniqueId:'second',avatarUrl:'https://p16.tiktokcdn.com/second.webp'}})]);
 assert.equal(second.status,200);assert.equal(second.portraitFallbacks,0);
 for(let i=0;i<30;i++){page=await f.map('/tikkies/events');if(page.events.some(e=>e.kind==='Portrait'))break;await new Promise(r=>setTimeout(r,10));}
 const next=page.events.find(e=>e.id==='second'),portrait=page.events.find(e=>e.kind==='Portrait');
 assert.ok(next.sender.portraitId);assert.notEqual(next.sender.portraitId,oldPortrait);assert.equal(portrait.sender.portraitId,next.sender.portraitId);
});

test('an unfinished profile slot uses a diagnosed generic face for new effects without blocking paid work',async t=>{
 const f=await fixture(t,{tikkiesOptions:{maxPortraits:1},pixels:()=>new Promise(()=>{})});await f.room();const b=await f.bind();
 await f.send(b.bindingId,[effect('first',{sender:{name:'First',uniqueId:'first',avatarUrl:'https://p16.tiktokcdn.com/first.webp'}})]);
 const second=effect('second',{sender:{name:'Second',uniqueId:'second',avatarUrl:'https://p16.tiktokcdn.com/second.webp'}});
 const admitted=await f.send(b.bindingId,[second]);assert.equal(admitted.status,200);assert.equal(admitted.portraitFallbacks,1);assert.equal(admitted.portraitPending,1);
 const page=await f.map('/tikkies/events');assert.match(page.events.find(e=>e.id==='first').sender.portraitId,/^p[a-f0-9]{32}$/);assert.equal(page.events.find(e=>e.id==='second').sender.portraitId,undefined);
 const retry=await f.send(b.bindingId,[second]);assert.equal(retry.enqueued,0);assert.equal(retry.portraitFallbacks,1);assert.equal(retry.pending,3);
});

for(const retain of ['gameplay','portrait'])test('profile recycling protects pending '+retain+' references and restores their face after rebind',async t=>{
 const f=await fixture(t,{tikkiesOptions:{maxPortraits:1},pixels:async()=>Array(1024).fill(0x112233)});await f.room();const b=await f.bind();
 await f.send(b.bindingId,[effect('first',{sender:{name:'First',uniqueId:'first',avatarUrl:'https://p16.tiktokcdn.com/first.webp'}})]);
 let page;for(let i=0;i<30;i++){page=await f.map('/tikkies/events');if(page.queued===2)break;await new Promise(r=>setTimeout(r,10));}
 const portraitId=page.events.find(e=>e.kind==='Portrait').sender.portraitId;
 const done=page.events.filter(e=>retain==='gameplay'?e.kind==='Portrait':e.kind!=='Portrait');
 await f.map('/tikkies/events',undefined,roomId,{'x-magnet-binding':b.bindingId,'x-magnet-generation':String(page.binding.generation),'x-magnet-ack':JSON.stringify(done.map(e=>e.seq))});
 const admitted=await f.send(b.bindingId,[effect('second',{sender:{name:'Second',uniqueId:'second',avatarUrl:'https://p16.tiktokcdn.com/second.webp'}})]);
 assert.equal(admitted.status,200);assert.equal(admitted.portraitFallbacks,1);
 await f.service('release',{subject,bindingId:b.bindingId});await f.bind();
 const rebound=await f.map('/tikkies/events');assert.ok(rebound.events.some(e=>e.kind==='Portrait'&&e.sender.portraitId===portraitId));
});

test('incoming batch references protect an acknowledged cached profile from eviction',async t=>{
 const f=await fixture(t,{tikkiesOptions:{maxPortraits:1},pixels:async()=>Array(1024).fill(0x112233)});await f.room();const b=await f.bind();
 const sender={name:'First',uniqueId:'first',avatarUrl:'https://p16.tiktokcdn.com/first.webp'};await f.send(b.bindingId,[effect('first',{sender})]);
 let page;for(let i=0;i<30;i++){page=await f.map('/tikkies/events');if(page.queued===2)break;await new Promise(r=>setTimeout(r,10));}
 const portraitId=page.events.find(e=>e.kind==='Portrait').sender.portraitId;
 await f.map('/tikkies/events',undefined,roomId,{'x-magnet-binding':b.bindingId,'x-magnet-generation':String(page.binding.generation),'x-magnet-ack':JSON.stringify(page.events.map(e=>e.seq))});
 const result=await f.send(b.bindingId,[effect('reuse',{sender}),effect('new',{sender:{name:'New',uniqueId:'new',avatarUrl:'https://p16.tiktokcdn.com/new.webp'}})]);
 assert.equal(result.status,200);assert.equal(result.portraitFallbacks,1);
 await f.service('release',{subject,bindingId:b.bindingId});await f.bind();
 const rebound=await f.map('/tikkies/events');assert.equal(rebound.events.find(e=>e.id==='reuse').sender.portraitId,portraitId);assert.ok(rebound.events.some(e=>e.kind==='Portrait'&&e.sender.portraitId===portraitId));
});
