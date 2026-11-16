import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {createBridge} from './http.mjs';

test('raw-likes negotiation forwards149+1 from different viewers once, with late portraits',async t=>{
 let connection;
 const pending=[];
 const key='raw-likes-test-key-at-least32-characters';
 const app=createBridge({key,giftMap:{},connect:()=>{
  connection=new EventEmitter();connection.connect=async()=>({});connection.disconnect=()=>{};return connection;
 },pixels:()=>new Promise(resolve=>pending.push(resolve))});
 await new Promise(r=>app.server.listen(0,'127.0.0.1',r));t.after(()=>app.close());
 const base='http://127.0.0.1:'+app.server.address().port;
 const headers={'x-magnet-key':key,'x-magnet-session':'raw-likes-session-aaaaaaaaaaaaaaaa','content-type':'application/json'};
 const started=await(await fetch(base+'/connect',{method:'POST',headers,body:JSON.stringify({username:'host',protocol:2,rawLikes:true})})).json();
 assert.equal(started.capabilities.rawLikes,true);
 const packet=(id,count,handle)=>({common:{msgId:id},count,total:999999,user:{displayId:handle,avatarThumb:{urlList:['https://p16.tiktokcdn.com/'+handle+'.webp']}}});
 connection.emit('like',packet('149-a',149,'viewer_a'));
 connection.emit('like',packet('1-b',1,'viewer_b'));
 connection.emit('like',packet('1-b',1,'viewer_b'));
 const read=async after=>(await fetch(base+'/session/events?after='+after,{headers})).json();
 const first=await read(0);
 assert.deepEqual(first.events.map(e=>[e.rawLikeCount,e.sender.handle]),[[149,'viewer_a'],[1,'viewer_b']]);
 assert.ok(first.events.every(e=>e.quantity===undefined));
 assert.notEqual(first.events[0].sender.portraitId,first.events[1].sender.portraitId);
 for(const resolve of pending)resolve(Array(1024).fill(0x66aa88));
 await new Promise(r=>setImmediate(r));
 const portraits=await read(first.cursor);
 assert.equal(portraits.events.length,2);
 assert.ok(portraits.events.every(e=>e.kind==='Portrait'&&e.sender.pixels.length===1024));
 assert.deepEqual(new Set(portraits.events.map(e=>e.sender.portraitId)),new Set(first.events.map(e=>e.sender.portraitId)));
});
