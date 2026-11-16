// Synthetic connector packets through the real HTTP bridge; no external requests.
import {EventEmitter} from 'node:events';
import {createBridge} from '../../bridge/http.mjs';
let connection;
const key='fixture-key-local-only-at-least32-characters';
const app=createBridge({key,giftMap:{},connect:()=>{
 connection=new EventEmitter();connection.connect=async()=>({});connection.disconnect=()=>{};return connection;
},pixels:async url=>Array(1024).fill(url.includes('viewer_a')?0xbb8866:0x66aa88)});
try{
 await new Promise(r=>app.server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+app.server.address().port;
 const headers={'x-magnet-key':key,'x-magnet-session':'fixture-session-aaaaaaaaaaaaaaaaa','content-type':'application/json'};
 const started=await(await fetch(base+'/connect',{method:'POST',headers,body:JSON.stringify({username:'fixture',protocol:2,rawLikes:true})})).json();
 if(!started.capabilities?.rawLikes)throw new Error('RAW_LIKES_UNAVAILABLE');
 for(const [handle,count]of [['viewer_a',149],['viewer_b',1]]){
  connection.emit('like',{common:{msgId:'fixture-'+handle},count,total:999999,user:{displayId:handle,avatarThumb:{urlList:['https://p16.tiktokcdn.com/'+handle+'.webp']}}});
 }
 await new Promise(r=>setImmediate(r));
 const batch=await(await fetch(base+'/session/events?after=0',{headers})).json();
 console.log(JSON.stringify(batch));
}finally{app.close();}
