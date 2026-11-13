import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeGift, normalizeSender, normalizeFollow, SessionQueue, username} from './core.mjs';

test('username accepts handle but rejects URLs',()=>{
 assert.equal(username(' @Some.one '),'some.one');
 assert.throws(()=>username('https://tiktok.com/@a'));
});
const gift={giftId:5655,giftType:1,repeatCount:12,repeatEnd:false,msgId:'900719925474099399',user:{uniqueId:'viewer',profilePicture:{urls:['https://p16.tiktokcdn.com/a.jpg']}}};
test('real v3 users with only avatarThumb retain their profile URL',()=>{
 const p=normalizeSender({displayId:'viewer',avatarLarge:undefined,avatarMedium:undefined,avatarThumb:{urlList:['https://p16-common-sign.tiktokcdn-eu.com/avatar.webp']}});
 assert.equal(p.avatarUrl,'https://p16-common-sign.tiktokcdn-eu.com/avatar.webp');
});
test('streak counted only once at final update, preserving unit gift',()=>{
 assert.equal(normalizeGift(gift,{'5655':'Rose'}),null);
 const e=normalizeGift({...gift,repeatEnd:true},{'5655':'Rose'});
 assert.equal(e.quantity,12); assert.equal(e.giftId,'Rose'); assert.equal(e.id,'gift:900719925474099399');
 assert.equal(e.sender.handle,'viewer');
 assert.equal(normalizeGift({...gift,repeatEnd:true},{}),null);
});
test('invalid and unsafe quantities/IDs never produce receipts',()=>{
 for(const n of [0,-1,NaN,1.5,10001]) assert.equal(normalizeGift({...gift,repeatEnd:true,repeatCount:n},{'5655':'Rose'}),null);
 assert.equal(normalizeGift({...gift,repeatEnd:true,msgId:9007199254740994},{'5655':'Rose'}),null);
});
test('installed connector v3 schema resolves displayId and avatarLarge',()=>{
 const raw={giftId:5655,giftDetails:{giftType:1},repeatCount:4,repeatEnd:false,common:{msgId:'900719925474099399'},user:{displayId:'actual_viewer',avatarLarge:{urlList:['https://p16.tiktokcdn.com/profile.webp']}}};
 assert.equal(normalizeGift(raw,{'5655':'Rose'}),null);
 const e=normalizeGift({...raw,repeatEnd:true},{'5655':'Rose'});
 assert.equal(e.sender.handle,'actual_viewer');
 assert.equal(e.avatarUrl,'https://p16.tiktokcdn.com/profile.webp');
});
test('cursor replay, deduplication and overflow are explicit',()=>{
 const q=new SessionQueue(3);
 assert.equal(q.push({id:'a'}),true); assert.equal(q.push({id:'a'}),false);
 q.push({id:'b'});q.push({id:'c'});
 assert.deepEqual(q.read(0,2).events.map(e=>e.id),['a','b']);
 assert.deepEqual(q.read(0,2).events.map(e=>e.id),['a','b']);
 q.push({id:'d'});
 assert.equal(q.read(0).gap,true);assert.equal(q.read(0).dropped,1);
 assert.equal(q.read(2,1).cursor,3);
});

test('follow ignores aggregate counts and rejects unsafe receipt IDs or unidentifiable accounts',()=>{
 const raw={common:{msgId:'follow-id'},count:900,quantity:1000,user:{id:'9223372036854775801',displayId:'follower'}};
 const event=normalizeFollow(raw);
 assert.equal(event.quantity,1);assert.equal(event.sender.userId,'9223372036854775801');
 assert.equal(normalizeFollow({...raw,common:{msgId:9007199254740994}}),null);
 assert.equal(normalizeFollow({...raw,user:{id:9007199254740994,displayId:'bad handle'}}),null);
 const fallback=normalizeFollow({...raw,user:{id:9007199254740994,displayId:'safe_handle'}});
 assert.equal(fallback.sender.userId,undefined);assert.equal(fallback.sender.uniqueId,'safe_handle');
 assert.equal(normalizeFollow(null),null);
});
