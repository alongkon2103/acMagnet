local Patch=require("../../src/TikkiesPatches")
local Dispatch=require("../../src/TikkiesDispatch")
local fixture=require("../fixtures/tikkies-native-fixtures")
local patched=Patch.Bridge(fixture.bridge)
local start=assert(patched:find("local function disconnect()",1,true))
local finish=assert(patched:find("\nend\n",start,true))
local disconnect=patched:sub(start,finish+4)
local hookStart=assert(patched:find("-- TIKKIES_GATEWAY_V3_BEGIN",1,true))
local hookEnd=assert(patched:find("-- TIKKIES_GATEWAY_V3_END",hookStart,true))
local hookSource=patched:sub(hookStart,hookEnd-1)
local requests,processed,gifts={},{},{}
local players={}
local player={UserId=42,Parent=players}
function players:GetPlayerByUserId(id)return id==42 and player or nil end
local attributes={}
local savedChannel="old_real_channel"
local live={SetAttribute=function(_,key,value)attributes[key]=value end}
local env={token="native-session",generation=1,owner=42,busy=false,Players=players,live=live,
 kit={Config="Config"},LikeCounter={new=function()return {}end},script={},ServerScriptService={WaitForChild=function(_,name)return name end},
 publishLikes=function()end,status=function(value)attributes.Status=value end,
 request=function(...)table.insert(requests,{...});return {}end,
 task={spawn=function(fn)fn()end,wait=function()end},
 Instance={new=function()return {}end},
 filteredSender=function(e)return {name="safe",seed=11,avatarId=e.sender.portraitId}end,
 process=function(e,owner,session,version)table.insert(processed,{e=e,owner=owner,session=session,version=version});return true end,
 gateway={Invoke=function(_,...)table.insert(gifts,{...});return true end},
}
env.require=function(name)
 if name=="TikkiesDispatch"then return Dispatch
 elseif name=="LikeRewardCounter"then return {new=function()return {}end}
 elseif name=="Config"then return {LikesPerReward=150}
 elseif name=="WinProfile"then return {SetChannel=function(_,channel)savedChannel=channel;return true end}end
 error("Unexpected engine dependency: "..tostring(name))
end
setmetatable(env,{__index=getfenv()})
local fn=assert(loadstring(disconnect.."\n"..hookSource.."\nreturn tikkiesGateway"));setfenv(fn,env)
local hook=fn().OnInvoke
local uuid="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
assert(not hook("begin","42","viewer","binding:1",uuid),"Native connection must prevent Tikkies takeover")
env.token=nil;env.owner=nil
assert(hook("begin","42","viewer","binding:1",uuid))
assert(savedChannel=="old_real_channel","Tikkies begin must not replace the saved native LIVE channel")
assert(not hook("begin","43","viewer","other",uuid),"Only the actual live Roblox Player may own the room")
assert(hook("status").external and not hook("status").nativeBusy)
local sender={name="TikTok sender",portraitId="p"..string.rep("b",32)}
assert(hook("submit","binding:1",{id=string.rep("x",100),effect="Rose",quantity=2,sender=sender}))
assert(#processed==1 and #processed[1].e.id==137 and processed[1].owner==42,"Binding namespacing must fit native receipt limit and preserve owner")
assert(hook("submit","binding:1",{id="likes",effect="Likes",quantity=1,sender=sender}))
assert(#gifts==1 and gifts[1][1]=="Likes"and gifts[1][2].avatarId==sender.portraitId,"Earned likes must reach native gift gateway with sender face")
assert(not hook("submit","binding:stale",{id="old",effect="Rose",quantity=1,sender=sender}))
assert(hook("end","binding:1"))
assert(#requests==0,"External begin/end must never POST legacy disconnect")
assert(env.token==nil and attributes.Transport==nil and not hook("status").external,"Ending Tikkies must restore native fallback")
assert(savedChannel=="old_real_channel","Tikkies test receipts and end must preserve SavedUsername")
print("PASS Tikkies native hook: ownership, mutual exclusion, namespacing, sender faces, no legacy cleanup")
