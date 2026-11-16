local module=assert(game.ServerScriptService:FindFirstChild("LiveNameCache"),"External name filtering must not block gameplay")
local Cache=assert(loadstring(module.Source))()
local registry=Instance.new("Folder")
local scheduled,calls={},0
local cache=Cache.new({registry=registry,spawn=function(fn)table.insert(scheduled,fn)end,
 filter=function(raw,owner)calls+=1;return "safe-name-"..owner end})
local name,id=cache.Get("unsafe external name",42)
assert(name=="TikTok viewer" and id and registry[id].Value==name)
assert(calls==0,"Filter must be asynchronous")
local again,againId=cache.Get("unsafe external name",42)
assert(again==name and againId==id)
for _,fn in scheduled do fn()end
local safe=cache.Get("unsafe external name",42)
assert(safe=="safe-name-42" and registry[id].Value==safe and calls==1)
local other,otherId=cache.Get("unsafe external name",43)
assert(other=="TikTok viewer" and otherId~=id,"Do not share filtering context across owners")
registry:Destroy()
return game.HttpService:JSONEncode({passed=true,calls=calls,initialName=name,filteredName=safe})
