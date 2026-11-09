import {TikTokLiveConnection} from 'tiktok-live-connector';
import {createBridge} from './http.mjs';
const giftMap=JSON.parse(process.env.GIFT_IDS??'{"5655":"Rose"}');
for(const [id,value] of Object.entries(giftMap))if(!/^\d+$/.test(id)||!['Rose','Roses','Perfume','Bear'].includes(value))throw new Error('Invalid GIFT_IDS');
const app=createBridge({key:process.env.MAGNET_KEY,giftMap,connect:name=>new TikTokLiveConnection(name,{enableExtendedGiftInfo:true,processInitialData:false,...(process.env.SIGN_API_KEY?{signApiKey:process.env.SIGN_API_KEY}:{})})});
app.server.listen(Number(process.env.PORT??8787),process.env.HOST??'127.0.0.1',()=>console.log('Magnet bridge ready on port '+ (process.env.PORT??8787)));
for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>{app.close();setTimeout(()=>process.exit(0),1000).unref();});
