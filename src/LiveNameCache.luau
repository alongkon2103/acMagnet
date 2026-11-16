-- External names are filtered asynchronously. Gameplay uses a safe placeholder while waiting.
local Http=game:GetService("HttpService")
local Text=game:GetService("TextService")
local Run=game:GetService("RunService")
local Cache={}
function Cache.new(options)
 options=options or {}
 local registry=assert(options.registry)
 local spawn=options.spawn or task.spawn
 local filter=options.filter or function(raw,owner)
  if Run:IsStudio()then return raw end
  return Text:FilterStringAsync(raw,owner):GetNonChatStringForBroadcastAsync()
 end
 local entries,jobs={},{}
 local active,size=0,0
 local pump
 pump=function()
  while active<4 and #jobs>0 do
   local entry=table.remove(jobs,1);active+=1
   spawn(function()
    local ok,value=pcall(filter,entry.raw,entry.owner)
    if ok and type(value)=="string" and #value>0 and #value<=400 then
     entry.safe=value
     if entry.value.Parent then entry.value.Value=value end
    end
    entry.pending=false;entry.retryAt=os.clock()+15
    active-=1;pump()
   end)
  end
 end
 local api={}
 function api.Get(raw,owner)
  raw=tostring(raw or "viewer")
  if #raw>160 then raw="viewer"end
  local key=tostring(owner)..":"..raw
  local entry=entries[key]
  if not entry then
   if size>=512 then return "TikTok viewer",nil end
   size+=1
   local value=Instance.new("StringValue")
   value.Name="n"..Http:GenerateGUID(false);value.Value="TikTok viewer";value.Parent=registry
   entry={raw=raw,owner=owner,safe="TikTok viewer",value=value,pending=true};entries[key]=entry
   table.insert(jobs,entry);pump()
  elseif entry.safe=="TikTok viewer" and not entry.pending and os.clock()>entry.retryAt then
   entry.pending=true;table.insert(jobs,entry);pump()
  end
  return entry.safe,entry.value.Name
 end
 return api
end
return Cache
