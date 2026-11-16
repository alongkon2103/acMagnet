-- Bounded concurrent receipt processing with acknowledgments only after acceptance.
local Pump={}
function Pump.new(options)
 local processing,completed,acknowledgments={},{},{}
 local active,activeFollows,failures,lastIssue=0,0,0,nil
 local spawn=options.spawn or task.spawn
 local api={}
 function api.Receive(events)
  for _,e in ipairs(events or {})do
   if active>=16 then break end
   if type(e)=="table" and type(e.seq)=="number" and e.seq%1==0 and e.seq>0 and type(e.id)=="string" and not processing[e.id] and not completed[e.id] and (e.giftId~="Follow" or activeFollows<4)then
    processing[e.id]=true;active+=1
    if e.giftId=="Follow"then activeFollows+=1 end
    spawn(function()
     local called,accepted,reason=pcall(options.process,e)
     if options.valid()then
      if called and accepted then
       completed[e.id]=true;acknowledgments[e.seq]=e.id
      else failures+=1;lastIssue=called and tostring(reason)or "event_handler_error"end
     end
     processing[e.id]=nil;active-=1
     if e.giftId=="Follow"then activeFollows-=1 end
    end)
   end
  end
 end
 function api.Acks()
  local ids={}
  for seq in acknowledgments do table.insert(ids,seq);if #ids>=100 then break end end
  return ids
 end
 function api.Confirm(ids)
  for _,seq in ids do
   local id=acknowledgments[seq]
   if id then completed[id]=nil;acknowledgments[seq]=nil end
  end
 end
 function api.Idle()return active==0 and next(acknowledgments)==nil end
 function api.Stats()return {active=active,failures=failures,lastIssue=lastIssue}end
 return api
end
return Pump
