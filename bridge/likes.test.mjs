import test from 'node:test';
import assert from 'node:assert/strict';
import {LikeCounter} from './likes.mjs';
const packet=(id,count,displayId='viewer')=>({common:{msgId:id},count,total:999999,user:{displayId,avatarLarge:{urlList:['https://p16.tiktokcdn.com/profile.webp']}}});
test('150 likes per sender grants one reward and preserves excess',()=>{
 const counter=new LikeCounter();
 assert.equal(counter.accept(packet('1',149)),null);
 const reward=counter.accept(packet('2',1));
 assert.equal(reward.giftId,'Likes');assert.equal(reward.quantity,1);assert.equal(reward.sender.handle,'viewer');
 assert.equal(counter.accept(packet('3',320)).quantity,2);
 assert.equal(counter.accept(packet('4',130)).quantity,1);
});
test('likes are isolated by sender and replayed packets do not double count',()=>{
 const counter=new LikeCounter();
 assert.equal(counter.accept(packet('1',75,'a')),null);
 assert.equal(counter.accept(packet('2',75,'b')),null);
 assert.equal(counter.accept(packet('1',75,'a')),null);
 assert.equal(counter.accept(packet('3',75,'a')).quantity,1);
 assert.equal(counter.accept(packet('4',75,'b')).quantity,1);
});
test('invalid counts and missing receipt ID do not alter progress',()=>{
 const counter=new LikeCounter();
 for(const n of [0,-1,NaN,1.5,Infinity,500001])assert.equal(counter.accept(packet('bad'+n,n)),null);
 assert.equal(counter.accept(packet('',150)),null);
 assert.equal(counter.accept(packet('valid',150)).quantity,1);
});
test('raw mode forwards every valid count once so Roblox can own the 150-like threshold',()=>{
 const counter=new LikeCounter({raw:true});
 const first=counter.accept(packet('raw-1',149));
 assert.equal(first.rawLikeCount,149);
 assert.equal(first.giftId,'Likes');
 assert.equal(first.sender.handle,'viewer');
 assert.equal(counter.accept(packet('raw-1',149)),null);
 assert.equal(counter.accept(packet('raw-2',1,'other')).rawLikeCount,1);
 assert.equal(counter.accept(packet('raw-3',320)).rawLikeCount,320);
 for(const count of [0,-1,NaN,1.5,Infinity,500001])assert.equal(counter.accept(packet('bad-'+count,count)),null);
 assert.equal(counter.accept(packet('',150)),null);
});
