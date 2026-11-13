import test from 'node:test';
import assert from 'node:assert/strict';
import {giftMap,gifts} from './gifts.mjs';
import {normalizeGift} from './core.mjs';
test('database gifts route to the current seven game actions by ID, regardless of quantity',()=>{
 assert.deepEqual(giftMap,{'5655':'Rose','8913':'Roses','9947':'Friendship','5879':'Donut','5566':'Bear','7934':'HeartMe','626064':'GoatBusker'});
 assert.deepEqual(gifts.map(g=>g.coins),[1,10,10,30,100,1,20]);
 for(const [id,key]of Object.entries(giftMap)){
  const event=normalizeGift({giftId:Number(id),repeatCount:100,repeatEnd:true,common:{msgId:'receipt-'+id},user:{displayId:'viewer'}},giftMap);
  assert.equal(event.giftId,key);assert.equal(event.quantity,100);
 }
 assert.equal(normalizeGift({giftId:5660,repeatCount:1,msgId:'other-100-coin-gift',user:{displayId:'viewer'}},giftMap),null);
});
