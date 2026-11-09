// Read-only public LIVE probe; never sends chat, follows, or gifts.
import {TikTokLiveConnection} from 'tiktok-live-connector';
import {avatarPixels} from './avatar.mjs';
const channels=process.argv.slice(2);if(!channels.length)throw new Error('Pass one or more TikTok handles');
for(const username of channels){
 const c=new TikTokLiveConnection(username,{enableExtendedGiftInfo:false,processInitialData:false,...(process.env.SIGN_API_KEY?{signApiKey:process.env.SIGN_API_KEY}:{})});
 c.on('error',()=>{});
 let checkedProfile=false;
 const checkProfile=async data=>{if(checkedProfile)return;const url=data.user?.avatarLarge?.urlList?.[0];if(!url)return;checkedProfile=true;const pixels=await avatarPixels(url);console.log(JSON.stringify({event:'profile_conversion',pixels:pixels?.length??0}));};
 c.on('chat',checkProfile);c.on('gift',checkProfile);
 let timer;
 try{
  const result=await Promise.race([c.connect(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('PROBE_TIMEOUT')),20000);})]);
  console.log(JSON.stringify({username,connected:true,roomId:String(result.roomId??''),giftCatalog:c.availableGifts?.length??c.state?.availableGifts?.length??0}));
  c.on('gift',g=>console.log(JSON.stringify({event:'gift',giftId:g.giftId,quantity:g.repeatCount,final:g.repeatEnd,hasProfile:Boolean(g.user?.avatarLarge?.urlList?.length)})));
  await new Promise(r=>setTimeout(r,8000));
  break;
 }catch(e){console.log(JSON.stringify({username,connected:false,error:e.name,message:String(e.message).replace(/https?:\/\/\S+/g,'[URL]').slice(0,300)}));}
 finally{clearTimeout(timer);c.disconnect();}
}
process.exit(0);
