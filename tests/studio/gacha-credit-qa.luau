-- Deterministic regression: keep the selected result through temporary and partial credit failures.
local Queue=assert(loadstring(game.ServerScriptService.GachaQueue.Source))()
local Rewards=require(game.ReplicatedStorage.BlackHole.GachaRewards)
local scheduled,results={},{}
local p={Parent=true,UserId=1,DisplayName="QA",attributes={}}
function p:SetAttribute(k,v)self.attributes[k]=v end
local attempts,rolled=0,0
local q=Queue.new({rewards=Rewards,random={NextNumber=function()return 0 end},
 items={Roll=function()rolled+=1;return {id="freeze",mode="Prank",amount=0,tier="Rare",weight=10}end},
 spawn=function(fn)table.insert(scheduled,fn)end,wait=function()end,now=function()return 0 end,
 fire=function(kind,data)if kind=="Result"then table.insert(results,data)end end,
 applyItem=function()attempts+=1;if attempts==1 then error("temporary award failure")end;if attempts==2 then return 0,nil,"queue_full"end return 1 end,
 add=function()error("Wrong award branch")end,remove=function()return 0 end,meteor=function()end,sync=function()end,
})
assert(q.Submit(p,"Mixed",{name="viewer",seed=1},1,{paid=true}))
scheduled[1]()
assert(#results==1 and results[1].actual==1,"Temporary item failure discarded the paid reward")
assert(attempts==3 and rolled==1,"Retry must preserve the selected outcome")
local credit,total=0,0
local jobs={}
local q2=Queue.new({rewards={RollSeconds=2.4,ResultSeconds=2,Roll=function()return {amount=100,tier="Uncommon"}end},
 random={NextNumber=function()return 0 end},spawn=function(fn)table.insert(jobs,fn)end,wait=function()end,now=function()return 0 end,
 fire=function(kind,data)if kind=="Result"then assert(data.actual==100,"Partial block credits were lost")end end,
 add=function(amount)credit+=1;local n=credit==1 and 30 or amount;total+=n;return n end,
 remove=function()return 0 end,meteor=function()end,sync=function()end,
})
assert(q2.Submit(p,"Prank",{name="viewer",seed=1},1,{paid=true}));jobs[1]()
assert(total==100 and credit==2)
local work,order={},{}
local priority=Queue.new({rewards=Rewards,random={NextNumber=function()return 0 end},
 spawn=function(fn)table.insert(work,fn)end,wait=function()end,now=function()return 0 end,
 fire=function(kind,data)if kind=="Roll"then table.insert(order,data.sender.name)end end,
 add=function(n)return n end,remove=function(_,n)return n end,meteor=function()end,sync=function()end})
assert(priority.Submit(p,"Prank",{name="Free",seed=1},3,{}))
assert(priority.Submit(p,"Prank",{name="Paid",seed=2},1,{paid=true}))
work[1]()
assert(order[1]=="Paid" and #order==4,"Free hotkey backlog delayed a paid gift")
return game.HttpService:JSONEncode({passed=true,itemAttempts=attempts,rolls=rolled,blockCredits=total})
