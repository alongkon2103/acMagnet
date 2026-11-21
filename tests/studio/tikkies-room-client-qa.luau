local Client=require("../../src/TikkiesRoomClient")
local Pump=require("../../src/LiveDeliveryPump")
local now=0
local calls,hooks={},{}
local ownerPresent=true
local bindingId="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
local current={id=bindingId,ownerRobloxId="42",channel="viewer",generation=1,expiresAt=60000}
local events={{id="one",seq=1,effect="Rose",quantity=1,sender={name="sender"}}}
local returnStale=false
local c=Client.new({
 now=function()return now end,
 players=function()return ownerPresent and {"42"}or {}end,
 nativeBusy=function()return false end,
 request=function(method,path,body,headers)
  table.insert(calls,{method=method,path=path,body=body,headers=headers})
  if path~="/tikkies/events"then return {ok=true}end
  if returnStale then return {binding=nil,status="waiting",events={}}end
  local delivered={}
  for _,e in ipairs(events)do
   local acked=false
   if body.generation==current.generation and body.binding==current.id then
    for _,seq in ipairs(body.acks or {})do if seq==e.seq then acked=true end end
   end
   if not acked then table.insert(delivered,e)end
  end
  return {binding=current,status="connected",events=delivered,pending=#delivered}
 end,
 hook=function(action,...)
  local args={...};table.insert(hooks,{action=action,args=args});return true
 end,
 pump=function(options)options.spawn=function(fn)fn()end;return Pump.new(options)end,
 publish=function()end,
})
c.Step()
assert(calls[#calls].method=="POST"and calls[#calls].path=="/tikkies/events","Roblox ACKs must travel in JSON POST body, never JSON-valued HTTP headers")
assert(hooks[1].action=="begin" and hooks[2].action=="submit","Binding must open original processor before consuming receipts")
now=1500;c.Step()
local second=calls[#calls]
assert(second.body.binding==bindingId and second.body.generation==1 and second.body.acks[1]==1,"ACKs require exact binding generation")
assert(second.body.waitMs==1000 and second.body.limit==100 and next(second.headers)==nil,"ACK arrays and binding fences belong only in the POST body")
current={id=bindingId,ownerRobloxId="42",channel="viewer",generation=2,expiresAt=60000}
events={{id="two",seq=1,effect="Rose",quantity=1,sender={name="sender"}}}
now=3000;c.Step()
now=4500;c.Step()
local latest=calls[#calls]
assert(latest.body.generation==2 and latest.body.acks[1]==1,"A new generation needs its own pump")
local submits=0
for _,h in hooks do if h.action=="submit"then submits+=1 end end
assert(submits==2,"Polling replays must not repeat accepted effects")
ownerPresent=false;now=6000;c.Step()
assert(hooks[#hooks].action=="end","Owner departure must fence the native processing hook")
for _,call in calls do
 if call.path=="/tikkies/events"and call.body.generation==nil then assert(not call.body.acks or #call.body.acks==0)end
end
c.Close()
assert(calls[#calls].path=="/tikkies/room/leave","Shutdown marks room offline without deleting pending work")
print("PASS Tikkies room client: binding, generation ACK fence, replay, owner departure, leave")
