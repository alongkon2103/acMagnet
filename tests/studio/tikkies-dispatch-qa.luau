-- CLI: runtime/luau-tool/luau.exe tests/studio/tikkies-dispatch-qa.luau
local Dispatch=require("../../src/TikkiesDispatch")
local calls,processed={},{}
local blocked=true
local valid=true
local d=Dispatch.new({
 valid=function(owner,session)return valid and owner==42 and(session=="binding:1"or session=="binding:2")end,
 sender=function(e)return {name="safe",seed=e.sender.seed,avatarId=e.sender.portraitId,nameId="n1"}end,
 process=function(e,owner,session)table.insert(processed,{e=e,owner=owner,session=session});return true end,
 gift=function(effect,sender,n,id,owner)
  if blocked and id=="earned:d:2"then return false,"queue_full"end
  table.insert(calls,{effect=effect,sender=sender,n=n,id=id,owner=owner});return true
 end,
 helper=function(effect,owner,sender,n,id)table.insert(calls,{effect=effect,owner=owner,sender=sender,n=n,id=id});return true end,
 yield=function()end,
})
local function event(id,effect,n,extra)
 local e={id=id,effect=effect,quantity=n,sender={name="external",seed=17,portraitId="p"..string.rep("a",32)}}
 for k,v in extra or {}do e[k]=v end
 return e
end
local ok,reason=d.Submit(event("earned","Likes",201),42,"binding:1")
assert(not ok and reason=="queue_full","An earned-like burst must retain the blocked chunk")
assert(#calls==1 and calls[1].n==100 and #processed==0,"Earned likes must bypass raw-like threshold exactly once")
blocked=false
assert(d.Submit(event("earned","Likes",201),42,"binding:1"))
assert(#calls==3 and calls[2].n==100 and calls[3].n==1,"Retry must resume after the accepted chunk")
assert(d.Submit(event("earned","Likes",201),42,"binding:1"))
assert(#calls==3,"An accepted helper receipt must not repeat")
assert(d.Submit(event("earned","Likes",201),42,"binding:2"))
assert(#calls==3,"Same-room generation changes must retain accepted helper receipt identity")
assert(d.Submit(event("manual-follow","Follow",1,{test=true,triggerType="follow"}),42,"binding:1"))
assert(calls[4].effect=="Follow" and #processed==0,"Tests must not consume persistent Follow claims")
assert(d.Submit(event("live-follow","Follow",1,{triggerType="follow"}),42,"binding:1"))
assert(#processed==1 and processed[1].e.giftId=="Follow","Actual Follow triggers must retain native guard")
assert(d.Submit(event("rose","Rose",300),42,"binding:1"))
assert(#processed==2 and processed[2].e.quantity==300,"Ordinary gifts must use original processor/chunking")
for _,effect in ipairs({"Remove","Speed","Range","Storm","Shrink","WinAdd","WinRemove"})do
 assert(d.Submit(event("helper-"..effect,effect,2),42,"binding:1"))
end
assert(d.Submit(event("help","HelpGacha",201),42,"binding:1"))
local helperUnits,helpUnits=0,0
for _,c in calls do
 assert(c.owner==42 and c.sender.avatarId=="p"..string.rep("a",32),"Sender face and Roblox recipient must remain separate")
 if c.effect=="HelpGacha"then helpUnits+=c.n elseif c.id:find(":h:",1,true)then helperUnits+=c.n end
end
assert(helperUnits==14 and helpUnits==201,"Helper quantities must retain every activation/roll")
assert(not d.Submit(event("bad","unknown",1),42,"binding:1"))
assert(not d.Submit(event("zero","Rose",0),42,"binding:1"))
valid=false
assert(not d.Submit(event("stale","Rose",1),42,"binding:1"))
print("PASS Tikkies dispatch: chunks, retries, earned likes, follow guards, helpers, faces, fencing")
