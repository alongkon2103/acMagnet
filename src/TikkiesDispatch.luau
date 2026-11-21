-- Routes authenticated Tikkies receipts through the existing native authorities.
-- This module has no engine side effects; the server-only hook supplies gateways.
local Dispatch={}
local ordinary={Rose=true,Roses=true,Friendship=true,Donut=true,Bear=true,HeartMe=true,GoatBusker=true}
local helpers={Remove=true,Speed=true,Range=true,Storm=true,Shrink=true,WinAdd=true,WinRemove=true}
function Dispatch.new(options)
 local records={}
 local api={}
 function api.Submit(e,owner,session)
  if not options.valid(owner,session)then return false,"cancelled"end
  if type(e)~="table"or type(e.id)~="string"or #e.id<1 or #e.id>140 or type(e.sender)~="table"then return false,"invalid_event"end
  if e.kind=="Portrait"then return options.process(e,owner,session)end
  local effect=e.effect or e.giftId
  if not ordinary[effect]and not helpers[effect]and effect~="Likes"and effect~="Follow"and effect~="HelpGacha"then return false,"unknown_effect"end
  local quantity=e.quantity
  if type(quantity)~="number"or quantity~=quantity or quantity%1~=0 or quantity<1 or quantity>10000 then return false,"invalid_quantity"end
  local copy=table.clone(e);copy.giftId=effect
  if ordinary[effect]or(effect=="Follow"and e.test~=true and tostring(e.triggerType):lower()=="follow")then
   return options.process(copy,owner,session)
  end
  -- Direct Likes already represents an earned reward. Never count it as raw likes.
  -- Manual/test Follow rewards deliberately bypass persistent real-follow claims.
  -- The hook namespaces IDs by binding UUID. Retain progress across lease generations
  -- on this same live server; changing a transport fence must not repeat helpers.
  local key=e.id
  local record=records[key]
  if record and(record.effect~=effect or record.quantity~=quantity)then return false,"event_conflict"end
  if record and record.done then return true,"duplicate"end
  if record and record.running then return false,"receipt_busy"end
  if not record then record={effect=effect,quantity=quantity,left=quantity,chunk=1};records[key]=record end
  record.running=true
  local called,accepted,reason=pcall(function()
   local sender=options.sender(e,owner)
   while record.left>0 do
    if not options.valid(owner,session)then return false,"cancelled"end
    local batch=(effect=="Likes"or effect=="Follow"or effect=="HelpGacha")and math.min(100,record.left)or 1
    local receipt=e.id..(helpers[effect]and ":h:"or ":d:")..record.chunk
    local ok,issue
    if effect=="Likes"or effect=="Follow"then ok,issue=options.gift(effect,sender,batch,receipt,owner)
    else ok,issue=options.helper(effect,owner,sender,batch,receipt)end
    if not ok and issue~="duplicate"then return false,issue end
    record.left-=batch;record.chunk+=1
    if record.left>0 and record.chunk%32==0 and options.yield then options.yield()end
   end
   record.done=true
   return true
  end)
  record.running=false
  if not called then return false,"effect_handler_error"end
  return accepted,reason
 end
 return api
end
return Dispatch
