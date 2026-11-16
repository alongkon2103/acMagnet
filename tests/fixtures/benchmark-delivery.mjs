// Synthetic queue benchmark, not TikTok network latency or Roblox rendering performance.
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve,relative,isAbsolute} from 'node:path';
import {SessionQueue} from '../../bridge/core.mjs';
import {DeliveryStore} from '../../bridge/delivery.mjs';
const dir=mkdtempSync(join(tmpdir(),'magnet-benchmark-'));
const store=new DeliveryStore(join(dir,'queue.sqlite'));
try{
 const results={};
 for(const [name,q]of [['legacy',new SessionQueue()],['reliable',store.create('benchmark',{username:'fixture',protocol:2,reliable:true})]]){
  const start=performance.now();
  q.push({id:'gift:first-bear',giftId:'Bear',quantity:1,sender:{name:'viewer'}});
  for(let i=0;i<5998;i++)q.push({id:'like:'+i,giftId:'Likes',rawLikeCount:1,sender:{name:'viewer'}});
  q.push({id:'gift:urgent-freeze',giftId:'Friendship',quantity:1,sender:{name:'viewer'}});
  const intakeMs=performance.now()-start;
  const batch=q.read(0,100);
  results[name]={intakeMs:Math.round(intakeMs),received:6000,retained:batch.pending??q.events.length,dropped:batch.dropped,
   firstBearInFirstBatch:batch.events.some(e=>e.id==='gift:first-bear'),firstReturned:batch.events[0]?.id};
 }
 console.log(JSON.stringify(results));
}finally{
 store.close();
 const child=relative(resolve(tmpdir()),resolve(dir));
 if(!child||child.startsWith('..')||isAbsolute(child)||!child.startsWith('magnet-benchmark-'))throw new Error('Unsafe temp path');
 rmSync(dir,{recursive:true,force:true});
}
