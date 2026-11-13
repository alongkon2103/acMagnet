-- One follow reward per TikTok account per broadcaster, persisted across servers.
local Guard = {}
function Guard.new(getStore, newId)
 local rewarded, busy = {}, {}
 return function(channel, identity, grant)
  if type(channel)~="string" or not channel:match("^[%w_%.]+$") or #channel>24 then return false,"invalid_follow_channel" end
  if type(identity)~="string" or #identity>45 or not identity:match("^[%w_%.:]+$") then return false,"invalid_follow_identity" end
  local key=channel.."/"..identity
  if rewarded[key] then return true,"duplicate_follow" end
  if busy[key] then return false,"follow_busy" end
  busy[key]=true
  local claim=newId()
  local store=getStore(channel)
  local ok,value=pcall(function()
   return store:UpdateAsync(identity,function(old)
    if old then return old end
    return claim
   end)
  end)
  if not ok then busy[key]=nil;return false,"follow_storage_unavailable" end
  if value~=claim then rewarded[key]=true;busy[key]=nil;return true,"duplicate_follow" end
  local called,accepted,reason=pcall(grant)
  if called and (accepted or reason=="duplicate") then
   rewarded[key]=true;busy[key]=nil;return true
  end
  local released=pcall(function()
   store:UpdateAsync(identity,function(old) if old==claim then return false end return old end)
  end)
  busy[key]=nil
  if not released then return false,"follow_release_failed" end
  return false,called and reason or "follow_grant_failed"
 end
end
return Guard
