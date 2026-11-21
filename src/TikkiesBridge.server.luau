-- Map credentials stay in server-only LiveConfig. This transport never opens TikTok LIVE.
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local SSS=game:GetService("ServerScriptService")
local kit=game:GetService("ReplicatedStorage"):WaitForChild("BlackHole")
local live=kit:WaitForChild("LiveState")
local config=require(SSS:WaitForChild("LiveConfig"))
local Client=require(SSS:WaitForChild("TikkiesRoomClient"))
local Pump=require(SSS:WaitForChild("LiveDeliveryPump"))
local hook=SSS:WaitForChild("TikTokBridge"):WaitForChild("TikkiesGateway")
local roomId=Http:GenerateGUID(false)
script:SetAttribute("RoomId",roomId) -- Server-only diagnostic; no authentication material.
local running=true
local function request(method,path,body,_metadata)
 local headers={["X-Magnet-Key"]=config.BridgeKey,["X-Magnet-Session"]=roomId,["Content-Type"]="application/json"}
 local called,response=pcall(Http.RequestAsync,Http,{Url=config.BridgeUrl..path,Method=method,Headers=headers,
  Body=method=="POST"and Http:JSONEncode(body or {})or nil})
 if not called then
  script:SetAttribute("LastHttpError",Client.SanitizeNativeIssue(response,config.BridgeKey))
  script:SetAttribute("LastHttpErrorAt",DateTime.now().UnixTimestampMillis)
  local detail=tostring(response):lower()
  if detail:find("timed out",1,true)or detail:find("timeout",1,true)then error("HTTP_TIMEOUT",0)
  elseif detail:find("not enabled",1,true)then error("HTTP_DISABLED",0)
  elseif detail:find("too many requests",1,true)or detail:find("request limit",1,true)then error("HTTP_THROTTLED",0)end
  error("HTTP_REQUEST_FAILED",0)
 end
 local decoded,data=pcall(Http.JSONDecode,Http,response.Body)
 if not response.Success then error(Client.HttpIssue(response.StatusCode,decoded and type(data)=="table"and data.error or nil),0)end
 if not decoded then error("HTTP_INVALID_JSON",0)end
 return data
end
local client=Client.new({
 now=function()return DateTime.now().UnixTimestampMillis end,
 placeId=game.PlaceId,universeId=game.GameId,
 players=function()
  local ids={};for _,player in ipairs(Players:GetPlayers())do table.insert(ids,tostring(player.UserId))end
  table.sort(ids);return ids
 end,
 nativeBusy=function()return hook:Invoke("status").nativeBusy==true end,
 request=request,
 hook=function(...)return hook:Invoke(...)end,
 pump=Pump.new,
 publish=function(response,active,stats)
  live:SetAttribute("TikkiesStatus",response.status or "waiting")
  live:SetAttribute("TikkiesPending",response.pending or 0)
  live:SetAttribute("TikkiesLagMs",response.oldestAgeMs or 0)
  live:SetAttribute("TikkiesInFlight",stats and stats.active or 0)
  live:SetAttribute("TikkiesIssue",response.issue)
  if active then live:SetAttribute("Status","LIVE")end
 end,
})
game:BindToClose(function()running=false;client.Close()end)
while running do
 local started=os.clock()
 local ok,delay=pcall(client.Step)
 if not ok then live:SetAttribute("TikkiesStatus","retrying");live:SetAttribute("TikkiesIssue",Client.SafeIssue(delay));delay=10 end
 -- At most 44.5 event polls + 7.5 room heartbeats per minute, before long-poll time.
 task.wait(math.max(.1,(delay or 10)-(os.clock()-started)))
end
