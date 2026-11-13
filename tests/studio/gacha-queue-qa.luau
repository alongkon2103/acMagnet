-- Studio MCP Server or Edit command; tests the production queue with a deterministic scheduler.
local Queue=require(game.ServerScriptService.GachaQueue)
local Rewards=require(game.ReplicatedStorage.BlackHole.GachaRewards)
local function fixture(paidLimit)
 local scheduled,events,changes={},{},{}
 local mixed=0
 local q=Queue.new({rewards=Rewards,paidLimit=paidLimit,
  random={NextNumber=function(_,low)if low then return 0 end mixed+=1 return mixed%2==1 and .1 or .9 end},
  spawn=function(fn)table.insert(scheduled,fn)end,wait=function()end,now=function()return 0 end,
  fire=function(kind,data)table.insert(events,{kind=kind,data=data})end,
  add=function(amount,sender)table.insert(changes,{mode="Prank",amount=amount,sender=sender});return amount end,
  remove=function(_,amount)table.insert(changes,{mode="Help",amount=amount});return amount end,
  meteor=function()end,sync=function()end,
 })
 return q,events,changes,function()for _,fn in scheduled do fn()end table.clear(scheduled)end
end
local function player(id)
 local p={UserId=id,DisplayName="Keyboard"..id,Parent=true,attributes={}}
 function p:SetAttribute(key,value)self.attributes[key]=value end
 return p
end
local sender={name="@viewer",seed=42,avatarId="p"..string.rep("a",32)}
local q,events,changes,drain=fixture()
local p=player(1)
assert(q.Submit(p,"Mixed",sender,2,{paid=true,giftId="HeartMe"}))
assert(q.Submit(p,"Prank",sender,1,{paid=true,giftId="GoatBusker"}))
drain()
local results={}
for _,e in events do if e.kind=="Result"then table.insert(results,e.data)end end
assert(#results==3,"One gift unit must produce one result")
assert(results[1].mode=="Prank" and results[2].mode=="Help" and results[3].mode=="Prank")
for _,r in results do
 assert(r.amount==30 and r.actual==30)
 assert(r.sender.name=="@viewer" and r.sender.avatarId==sender.avatarId)
end
assert(changes[1].sender.avatarId==sender.avatarId and changes[1].sender.gachaTier=="Common")
assert(p.attributes.GachaQueue==0)
local capacity,_,_,drainCapacity=fixture()
assert(capacity.Submit(p,"Prank",sender,32,{}))
local ok,reason=capacity.Submit(p,"Prank",sender,1,{})
assert(not ok and reason=="gacha_queue_full","Per-player queue must reject atomically")
assert(not capacity.Submit(player(2),"Mixed",sender,33,{}))
for i=2,4 do assert(capacity.Submit(player(i),"Prank",sender,32,{}))end
assert(not capacity.Submit(player(5),"Prank",sender,1,{}),"Global cap exceeded")
drainCapacity()
local bulk,bulkEvents,_,drainBulk=fixture(200)
assert(bulk.Submit(p,"Prank",sender,100,{paid=true}))
assert(bulk.Submit(p,"Mixed",sender,100,{paid=true}))
assert(not bulk.Submit(p,"Mixed",sender,1,{paid=true}),"Paid intake cap exceeded")
drainBulk()
local bulkResults=0
for _,event in bulkEvents do if event.kind=="Result"then bulkResults+=1 end end
assert(bulkResults==200,"Paid gifts must be accepted without waiting for animation slots")
local leaving,departureEvents,_,drainLeaving=fixture()
local gone=player(9)
assert(leaving.Submit(gone,"Prank",sender,2,{paid=true}))
assert(leaving.Submit(gone,"Help",{name="Keyboard9",seed=9,userId=9},1,{}))
gone.Parent=nil;leaving.RemovePlayer(gone);drainLeaving()
local paid=0
for _,e in departureEvents do if e.kind=="Result"then paid+=1 end end
assert(paid==2,"Accepted paid jobs must survive departure; keyboard jobs must cancel")
return {passed=true,results=3,perPlayerCap=32,globalCap=128,departureResults=paid}
