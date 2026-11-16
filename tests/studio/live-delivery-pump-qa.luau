local m=assert(game.ServerScriptService:FindFirstChild("LiveDeliveryPump"),"A blocked receipt must not block other events")
local Pump=assert(loadstring(m.Source))()
local scheduled,calls={},{}
local blocked=true
local pump=Pump.new({spawn=function(fn)table.insert(scheduled,fn)end,valid=function()return true end,
 process=function(e)table.insert(calls,e.seq);if e.seq==1 and blocked then return false,"queue_full"end return true end})
local events={{id="blocked",seq=1},{id="freeze",seq=2},{id="profile",seq=3}}
pump.Receive(events);for _,fn in scheduled do fn()end;table.clear(scheduled)
local acks=pump.Acks();table.sort(acks)
assert(#acks==2 and acks[1]==2 and acks[2]==3,"Only accepted receipts may be acknowledged")
blocked=false;pump.Receive(events);for _,fn in scheduled do fn()end;table.clear(scheduled)
assert(#calls==4,"Unacknowledged successes must not be applied again")
local all=pump.Acks();assert(#all==3);pump.Confirm(all)
assert(pump.Idle())
local workers={}
local fair=Pump.new({spawn=function(fn)table.insert(workers,fn)end,valid=function()return true end,process=function()return true end})
local burst={}
for i=1,20 do table.insert(burst,{id="follow-"..i,seq=i,giftId="Follow"})end
table.insert(burst,{id="paid",seq=21,giftId="Bear"})
fair.Receive(burst)
assert(#workers==5,"Slow follow datastore requests occupied all gift workers")
for _,fn in workers do fn()end
local accepted=fair.Acks();table.sort(accepted)
assert(#accepted==5 and accepted[5]==21,"Paid gift was blocked behind follow requests")
return game.HttpService:JSONEncode({passed=true,processed=#calls,acknowledged=#all})
