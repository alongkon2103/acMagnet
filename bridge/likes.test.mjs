import test from 'node:test';
import assert from 'node:assert/strict';
import {LikeCounter} from './likes.mjs';
const packet=(id,count,displayId='viewer')=>({common:{msgId:id},count,total:999999,user:{displayId,avatarLarge:{urlList:['https://p16.tiktokcdn.com/profile.webp']}}});
test('50 likes per sender grants 10 blocks and preserves excess',()=>{
 const counter=new LikeCounter();
 assert.equal(counter.accept(packet('1',49)),null);
 const reward=counter.accept(packet('2',1));
 assert.equal(reward.giftId,'Likes');assert.equal(reward.quantity,1);assert.equal(reward.sender.handle,'viewer');
 assert.equal(counter.accept(packet('3',120)).quantity,2);
 assert.equal(counter.accept(packet('4',30)).quantity,1);
});
test('likes are isolated by sender and replayed packets do not double count',()=>{
 const counter=new LikeCounter();
 assert.equal(counter.accept(packet('1',25,'a')),null);
 assert.equal(counter.accept(packet('2',25,'b')),null);
 assert.equal(counter.accept(packet('1',25,'a')),null);
 assert.equal(counter.accept(packet('3',25,'a')).quantity,1);
 assert.equal(counter.accept(packet('4',25,'b')).quantity,1);
});
test('invalid counts and missing receipt ID do not alter progress',()=>{
 const counter=new LikeCounter();
 for(const n of [0,-1,NaN,1.5,Infinity,500001])assert.equal(counter.accept(packet('bad'+n,n)),null);
 assert.equal(counter.accept(packet('',50)),null);
 assert.equal(counter.accept(packet('valid',50)).quantity,1);
});
