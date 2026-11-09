// Exercise deployed authenticated endpoints without sending any TikTok interaction.
import {randomUUID} from 'node:crypto';
const base=process.argv[2]??'https://acmagnet.aclassstore.com';
const channel=process.argv[3]??'natthapornsrichinwinit1';
const headers={'X-Magnet-Key':process.env.MAGNET_KEY,'X-Magnet-Session':randomUUID(),'Content-Type':'application/json'};
const request=async(method,path,body)=>{const r=await fetch(base+path,{method,headers,body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(15000)});if(!r.ok)throw new Error('HTTP_'+r.status);return r.json();};
try{
 const health=await(await fetch(base+'/health')).json();
 const unauthorized=(await fetch(base+'/session/events?after=0')).status;
 const start=await request('POST','/connect',{username:channel});
 let state=start;
 for(let i=0;i<12;i++){
  await new Promise(r=>setTimeout(r,1000));state=await request('GET','/session/events?after=0');
  if(['LIVE','OFFLINE','ERROR','SIGNING_REQUIRED'].includes(state.status))break;
 }
 console.log(JSON.stringify({health:health.ok,unauthorized,start:start.status,channel,status:state.status,events:state.events?.length??0}));
 if(!health.ok||unauthorized!==401)process.exitCode=1;
}finally{await request('POST','/disconnect',{});}
