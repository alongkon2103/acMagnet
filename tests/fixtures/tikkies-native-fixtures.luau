-- Nonsecret native audit baselines and generated installer inputs. No LiveConfig source.
-- Refresh current inputs: node tests/fixtures/generate-tikkies-native-fixtures.mjs
return {bridge=[==========[local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local config = require(ServerScriptService:WaitForChild("LiveConfig"))
local kit = game:GetService("ReplicatedStorage"):WaitForChild("BlackHole")
local control = kit:WaitForChild("LiveControl")
local live = kit:WaitForChild("LiveState")
local portraits = kit:WaitForChild("LivePortraits")
local nameCache=require(ServerScriptService:WaitForChild("LiveNameCache")).new({registry=kit:WaitForChild("LiveNames")})
local DeliveryPump=require(ServerScriptService:WaitForChild("LiveDeliveryPump"))
local gateway = ServerScriptService:WaitForChild("BlackHoleServer"):WaitForChild("SubmitGift")
local token, generation, cursor, owner = nil, 0, 0, nil
local busy, cooldown = false, {}
local LikeCounter=require(ServerScriptService:WaitForChild("LikeRewardCounter"))
local likeCounter=LikeCounter.new(require(kit.Config).LikesPerReward)
local function publishLikes()
 live:SetAttribute("LikeRewardsEnabled",require(kit.Config).LikeRewardsEnabled)
 live:SetAttribute("LikeCounterStatus",likeCounter.status)
 live:SetAttribute("LikeProgress",likeCounter.remainder)
 live:SetAttribute("LikesPerReward",require(kit.Config).LikesPerReward)
end
publishLikes()
local followGuard = require(ServerScriptService:WaitForChild("FollowRewardGuard")).new(
 function(channel) return game:GetService("DataStoreService"):GetDataStore("TikTokFollowRewards_v1", channel) end,
 function() return Http:GenerateGUID(false) end)
local function isFollow(e)
 local kind=tostring(e.giftId or e.type or e.kind or e.event or ""):lower()
 return kind=="follow" or kind=="follows"
end
local function followIdentity(sender)
 -- Numeric platform IDs must arrive as strings to preserve TikTok's 64-bit precision.
 local id=sender.userId or sender.id
 if type(id)=="string" and id:match("^%d+$") and #id<=40 then return "uid:"..id end
 local username=sender.uniqueId or sender.username
 if type(username)=="string" then
  username=username:lower():gsub("^@","")
  if #username>0 and #username<=24 and username:match("^[%w_%.]+$") then return "user:"..username end
 end
 return nil
end
local function operator(player)
    -- LIVE is available to every player in this server.
    return player ~= nil and player.Parent == Players
end
local function status(value) live:SetAttribute("Status", value) end
local function request(method, path, body, session, acks)
    local response = Http:RequestAsync({Url=config.BridgeUrl..path, Method=method,
        Headers={["X-Magnet-Key"]=config.BridgeKey,["X-Magnet-Session"]=session,["Content-Type"]="application/json",["X-Magnet-Ack"]=acks and #acks>0 and Http:JSONEncode(acks)or nil},
        Body=method=="POST" and Http:JSONEncode(body or {}) or nil})
    if not response.Success then error("HTTP_"..response.StatusCode) end
    return Http:JSONDecode(response.Body)
end
local function disconnect()
    generation += 1
    local previous=token
    token=nil; owner=nil; busy=false
    likeCounter=LikeCounter.new(require(kit.Config).LikesPerReward);publishLikes()
    status("DISCONNECTED");live:SetAttribute("Username", "")
    if previous then task.spawn(function() pcall(request,"POST","/disconnect",{},previous) end) end
end
local function portrait(sender)
    local requested=sender.portraitId
    if type(requested)~="string" or #requested~=33 or not requested:match("^p%x+$") then requested=nil end
    local pixels=sender.pixels
    if type(pixels)~="table" or (#pixels~=256 and #pixels~=1024) then return requested end
    for _,v in pixels do if type(v)~="number" or v~=v or v%1~=0 or v<0 or v>16777215 then return nil end end
    -- Content-derived ID means all gifts from this profile share one image.
    local encoded=Http:JSONEncode(pixels)
    local hash=0
    for i=1,#encoded do hash=(hash*31+string.byte(encoded,i))%2147483647 end
    local id=requested or ("p"..hash)
    local existing=portraits:FindFirstChild(id)
    if existing and existing.Value~=encoded then return nil end
    if not existing then
        if #portraits:GetChildren()>=256 then return nil end
        existing=Instance.new("StringValue");existing.Name=id;existing.Value=encoded;existing.Parent=portraits
    end
    return id
end
local function filteredSender(e,playerId)
    local name,nameId=nameCache.Get(e.sender.name or "viewer",playerId)
    return {name=name,nameId=nameId,seed=e.sender.seed,avatarId=portrait(e.sender)}
end
local receiptProgress={}
local function process(e, playerId, session, version)
    if type(e)~="table" or type(e.id)~="string" or #e.id>140 or type(e.sender)~="table" then return false,"invalid_event" end
    if e.kind=="Portrait" then portrait(e.sender);return true end
    if require(kit.Config).LikeRewardsEnabled==false then
        for _,field in ipairs({"giftId","type","kind","event"})do
            local value=tostring(e[field] or ""):lower()
            if value=="like" or value=="likes" then
                live:SetAttribute("LikeRewardsEnabled",false)
                return true,"likes_disabled"
            end
        end
    end

    local liking=LikeCounter.IsLike(e)
    local following=isFollow(e)
    if not following and not liking and (type(e.quantity)~="number" or e.quantity%1~=0 or e.quantity<1 or e.quantity>10000) then return false,"invalid_quantity" end
    local identity=following and followIdentity(e.sender)
    if following and not identity then
        live:SetAttribute("LastIssue","follow_missing_account_id")
        return true,"ignored_invalid_follow"
    end
    if token~=session or generation~=version then return false,"cancelled" end
    if following then
        local sender=filteredSender(e,playerId)
        local channel=live:GetAttribute("Username")
        return followGuard(channel,identity,function()
            if token~=session or generation~=version then return false,"cancelled" end
            return gateway:Invoke("Follow",sender,1,"follow:"..channel..":"..identity)
        end)
    end
    if liking then
        local counter=likeCounter
        local ok,reason=counter:Process(e,function(quantity,receipt)
            if token~=session or generation~=version then return false,"cancelled"end
            local sender=filteredSender(e,playerId)
            return gateway:Invoke("Likes",sender,quantity,receipt,playerId)
        end)
        if counter==likeCounter then publishLikes()end
        return ok,reason
    end
    local sender=filteredSender(e,playerId)
    -- Resume the failed chunk even if a long queue outlives gateway dedup retention.
    local progress=receiptProgress[e.id]
    if not progress or progress.id~=e.id or progress.session~=session or progress.version~=version then
        progress={id=e.id,session=session,version=version,left=e.quantity,chunk=1}
        receiptProgress[e.id]=progress
    end
    while progress.left>0 do
        if token~=session or generation~=version then return false,"cancelled" end
        local gift=require(kit.Config).Gifts[e.giftId]
        if not gift then return false,"unknown_gift" end
        local amount=math.min(progress.left,math.min(100,math.floor(require(kit.Config).MaxPending/(gift.Blocks or 1))))
        local ok,reason=gateway:Invoke(e.giftId,sender,amount,e.id..":"..progress.chunk,playerId)
        if not ok and reason~="duplicate" then return false,reason end
        progress.left-=amount
        progress.chunk+=1
    end
    if receiptProgress[e.id]==progress then receiptProgress[e.id]=nil end
    return true
end
control.OnServerEvent:Connect(function(player,action,input)
    if not operator(player) then return end
    if owner and owner~=player.UserId then return end
    local now=os.clock()
    if now-(cooldown[player] or -10)<3 then return end
    cooldown[player]=now
    if action=="disconnect" then disconnect();return end
    if action~="connect" or busy then return end
    if type(input)~="string" then return end
    local name=string.lower(string.gsub(string.gsub(input,"^%s*(.-)%s*$","%1"),"^@",""))
    if #name<1 or #name>24 or not name:match("^[%w_][%w_%.]*$") then status("INVALID_USERNAME");return end
    if not config.BridgeUrl:match("^https://") or #config.BridgeKey<32 then status("SETUP_REQUIRED");return end
    require(ServerScriptService:WaitForChild("WinProfile")).SetChannel(player,name)
    disconnect();busy=true;owner=player.UserId;token=Http:GenerateGUID(false);cursor=0
    local session,version=token,generation
    status("CONNECTING");live:SetAttribute("Username",name)
    task.spawn(function()
        local ok,connected=pcall(request,"POST","/connect",{username=name,protocol=2,gacha=true,follow=true,rawLikes=true,reliable=true},session)
        if version~=generation then pcall(request,"POST","/disconnect",{},session);return end
        busy=false
        if not ok then status("ERROR");token=nil;return end
        local reliable=type(connected)=="table" and connected.capabilities and connected.capabilities.reliable==true
        local pump=reliable and DeliveryPump.new({
            valid=function()return token==session and generation==version end,
            process=function(e)return process(e,owner,session,version)end,
        })or nil
        local failures=0
        local function terminal(value)return value=="OFFLINE" or value=="ERROR" or value=="DISCONNECTED" or value=="SIGNING_REQUIRED"end
        while token==session and generation==version do
            local requested=os.clock()
            local acks=pump and pump.Acks()or nil
            local path=pump and "/session/events?limit=100&waitMs=1000"or "/session/events?after="..cursor
            local success,data=pcall(request,"GET",path,nil,session,acks)
            if version~=generation then break end
            if success and type(data)=="table" then
                failures=0;status(data.status or "ERROR")
                live:SetAttribute("ReliableDelivery",reliable)
                live:SetAttribute("Dropped",data.dropped or 0);live:SetAttribute("Unmapped",data.unmapped or 0)
                live:SetAttribute("DeliveryPending",data.pending or 0);live:SetAttribute("DeliveryLagMs",data.oldestAgeMs or 0)
                live:SetAttribute("DeliveryWriteRetries",data.retryingWrites or 0)
                if data.gap then live:SetAttribute("Gap",true)end
                if pump then
                    pump.Confirm(acks)
                    pump.Receive(data.events)
                    local stats=pump.Stats()
                    live:SetAttribute("DeliveryInFlight",stats.active);live:SetAttribute("DeliveryRetries",stats.failures)
                    if stats.lastIssue then live:SetAttribute("LastIssue",stats.lastIssue)end
                    if data.pending==0 and pump.Idle() and terminal(data.status) then
                        token=nil;pcall(request,"POST","/disconnect",{},session);break
                    end
                else
                    local blocked=false
                    for _,e in ipairs(data.events or {})do
                        local accepted,reason=process(e,owner,session,version)
                        if version~=generation or token~=session then return end
                        if not accepted then status("BACKPRESSURE");live:SetAttribute("LastIssue",reason);blocked=true;break end
                        cursor=e.seq
                    end
                    if not blocked then cursor=data.cursor or cursor end
                    if not blocked and not data.hasMore and terminal(data.status)then
                        token=nil;pcall(request,"POST","/disconnect",{},session);break
                    end
                end
            else
                failures+=1;status("RETRYING")
                if failures>=10 and not reliable then status("ERROR");token=nil;pcall(request,"POST","/disconnect",{},session);break end
            end
            if failures>0 then task.wait(math.min(10,math.max(.2,config.PollSeconds)*failures))
            elseif pump then task.wait(math.max(.01,.18-(os.clock()-requested)))
            else task.wait(math.min(.2,config.PollSeconds))end
        end
    end)
end)
Players.PlayerAdded:Connect(function(p) p:SetAttribute("CanControlTikTok",operator(p)) end)
for _,p in Players:GetPlayers() do p:SetAttribute("CanControlTikTok",operator(p)) end
Players.PlayerRemoving:Connect(function(p) cooldown[p]=nil;if owner==p.UserId then disconnect() end end)
game:BindToClose(function() if token then pcall(request,"POST","/disconnect",{},token) end end)
status("DISCONNECTED")
]==========],bridgeV1=[==========[local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local config = require(ServerScriptService:WaitForChild("LiveConfig"))
local kit = game:GetService("ReplicatedStorage"):WaitForChild("BlackHole")
local control = kit:WaitForChild("LiveControl")
local live = kit:WaitForChild("LiveState")
local portraits = kit:WaitForChild("LivePortraits")
local nameCache=require(ServerScriptService:WaitForChild("LiveNameCache")).new({registry=kit:WaitForChild("LiveNames")})
local DeliveryPump=require(ServerScriptService:WaitForChild("LiveDeliveryPump"))
local gateway = ServerScriptService:WaitForChild("BlackHoleServer"):WaitForChild("SubmitGift")
local token, generation, cursor, owner = nil, 0, 0, nil
local tikkiesExternal=nil -- TIKKIES_OWNERSHIP_V1
local busy, cooldown = false, {}
local LikeCounter=require(ServerScriptService:WaitForChild("LikeRewardCounter"))
local likeCounter=LikeCounter.new(require(kit.Config).LikesPerReward)
local function publishLikes()
 live:SetAttribute("LikeRewardsEnabled",require(kit.Config).LikeRewardsEnabled)
 live:SetAttribute("LikeCounterStatus",likeCounter.status)
 live:SetAttribute("LikeProgress",likeCounter.remainder)
 live:SetAttribute("LikesPerReward",require(kit.Config).LikesPerReward)
end
publishLikes()
local followGuard = require(ServerScriptService:WaitForChild("FollowRewardGuard")).new(
 function(channel) return game:GetService("DataStoreService"):GetDataStore("TikTokFollowRewards_v1", channel) end,
 function() return Http:GenerateGUID(false) end)
local function isFollow(e)
 local kind=tostring(e.giftId or e.type or e.kind or e.event or ""):lower()
 return kind=="follow" or kind=="follows"
end
local function followIdentity(sender)
 -- Numeric platform IDs must arrive as strings to preserve TikTok's 64-bit precision.
 local id=sender.userId or sender.id
 if type(id)=="string" and id:match("^%d+$") and #id<=40 then return "uid:"..id end
 local username=sender.uniqueId or sender.username
 if type(username)=="string" then
  username=username:lower():gsub("^@","")
  if #username>0 and #username<=24 and username:match("^[%w_%.]+$") then return "user:"..username end
 end
 return nil
end
local function operator(player)
    -- LIVE is available to every player in this server.
    return player ~= nil and player.Parent == Players
end
local function status(value) live:SetAttribute("Status", value) end
local function request(method, path, body, session, acks)
    local response = Http:RequestAsync({Url=config.BridgeUrl..path, Method=method,
        Headers={["X-Magnet-Key"]=config.BridgeKey,["X-Magnet-Session"]=session,["Content-Type"]="application/json",["X-Magnet-Ack"]=acks and #acks>0 and Http:JSONEncode(acks)or nil},
        Body=method=="POST" and Http:JSONEncode(body or {}) or nil})
    if not response.Success then error("HTTP_"..response.StatusCode) end
    return Http:JSONDecode(response.Body)
end
local function disconnect()
    generation += 1
    local previous=tikkiesExternal==nil and token or nil
    tikkiesExternal=nil;live:SetAttribute("Transport",nil)
    token=nil; owner=nil; busy=false
    likeCounter=LikeCounter.new(require(kit.Config).LikesPerReward);publishLikes()
    status("DISCONNECTED");live:SetAttribute("Username", "")
    if previous then task.spawn(function() pcall(request,"POST","/disconnect",{},previous) end) end
end
local function portrait(sender)
    local requested=sender.portraitId
    if type(requested)~="string" or #requested~=33 or not requested:match("^p%x+$") then requested=nil end
    local pixels=sender.pixels
    if type(pixels)~="table" or (#pixels~=256 and #pixels~=1024) then return requested end
    for _,v in pixels do if type(v)~="number" or v~=v or v%1~=0 or v<0 or v>16777215 then return nil end end
    -- Content-derived ID means all gifts from this profile share one image.
    local encoded=Http:JSONEncode(pixels)
    local hash=0
    for i=1,#encoded do hash=(hash*31+string.byte(encoded,i))%2147483647 end
    local id=requested or ("p"..hash)
    local existing=portraits:FindFirstChild(id)
    if existing and existing.Value~=encoded then return nil end
    if not existing then
        if #portraits:GetChildren()>=256 then return nil end
        existing=Instance.new("StringValue");existing.Name=id;existing.Value=encoded;existing.Parent=portraits
    end
    return id
end
local function filteredSender(e,playerId)
    local name,nameId=nameCache.Get(e.sender.name or "viewer",playerId)
    return {name=name,nameId=nameId,seed=e.sender.seed,avatarId=portrait(e.sender)}
end
local receiptProgress={}
local function process(e, playerId, session, version)
    if type(e)~="table" or type(e.id)~="string" or #e.id>140 or type(e.sender)~="table" then return false,"invalid_event" end
    if e.kind=="Portrait" then portrait(e.sender);return true end
    if require(kit.Config).LikeRewardsEnabled==false then
        for _,field in ipairs({"giftId","type","kind","event"})do
            local value=tostring(e[field] or ""):lower()
            if value=="like" or value=="likes" then
                live:SetAttribute("LikeRewardsEnabled",false)
                return true,"likes_disabled"
            end
        end
    end

    local liking=LikeCounter.IsLike(e)
    local following=isFollow(e)
    if not following and not liking and (type(e.quantity)~="number" or e.quantity%1~=0 or e.quantity<1 or e.quantity>10000) then return false,"invalid_quantity" end
    local identity=following and followIdentity(e.sender)
    if following and not identity then
        live:SetAttribute("LastIssue","follow_missing_account_id")
        return true,"ignored_invalid_follow"
    end
    if token~=session or generation~=version then return false,"cancelled" end
    if following then
        local sender=filteredSender(e,playerId)
        local channel=live:GetAttribute("Username")
        return followGuard(channel,identity,function()
            if token~=session or generation~=version then return false,"cancelled" end
            return gateway:Invoke("Follow",sender,1,"follow:"..channel..":"..identity)
        end)
    end
    if liking then
        local counter=likeCounter
        local ok,reason=counter:Process(e,function(quantity,receipt)
            if token~=session or generation~=version then return false,"cancelled"end
            local sender=filteredSender(e,playerId)
            return gateway:Invoke("Likes",sender,quantity,receipt,playerId)
        end)
        if counter==likeCounter then publishLikes()end
        return ok,reason
    end
    local sender=filteredSender(e,playerId)
    -- Resume the failed chunk even if a long queue outlives gateway dedup retention.
    local progress=receiptProgress[e.id]
    if not progress or progress.id~=e.id or progress.session~=session or progress.version~=version then
        progress={id=e.id,session=session,version=version,left=e.quantity,chunk=1}
        receiptProgress[e.id]=progress
    end
    while progress.left>0 do
        if token~=session or generation~=version then return false,"cancelled" end
        local gift=require(kit.Config).Gifts[e.giftId]
        if not gift then return false,"unknown_gift" end
        local amount=math.min(progress.left,math.min(100,math.floor(require(kit.Config).MaxPending/(gift.Blocks or 1))))
        local ok,reason=gateway:Invoke(e.giftId,sender,amount,e.id..":"..progress.chunk,playerId)
        if not ok and reason~="duplicate" then return false,reason end
        progress.left-=amount
        progress.chunk+=1
    end
    if receiptProgress[e.id]==progress then receiptProgress[e.id]=nil end
    return true
end
-- TIKKIES_GATEWAY_V1_BEGIN
local tikkiesDispatch=require(ServerScriptService:WaitForChild("TikkiesDispatch")).new({
 valid=function(playerId,session)
  return tikkiesExternal~=nil and tikkiesExternal.session==session and token==session
   and generation==tikkiesExternal.version and owner==playerId and Players:GetPlayerByUserId(playerId)~=nil
 end,
 sender=filteredSender,
 process=function(e,playerId,session)
  local context=tikkiesExternal
  if not context or context.session~=session then return false,"cancelled"end
  return process(e,playerId,session,context.version)
 end,
 gift=function(effect,sender,amount,receipt,playerId)return gateway:Invoke(effect,sender,amount,receipt,playerId)end,
 helper=function(effect,playerId,sender,amount,receipt)
  local player=Players:GetPlayerByUserId(playerId)
  if not player then return false,"owner_unavailable"end
  local native=ServerScriptService:WaitForChild("BlackHoleServer")
  if effect=="HelpGacha"then return native:WaitForChild("TikkiesHelpGacha"):Invoke(sender,amount,receipt,playerId)
  elseif effect=="WinAdd"or effect=="WinRemove"then
   return native:WaitForChild("TikkiesWinAdjustment"):Invoke(player,effect=="WinAdd"and 1 or -1,receipt)
  elseif effect=="Shrink"then return ServerScriptService:WaitForChild("ArenaSettings"):WaitForChild("Shrink"):Invoke(player)
  else return ServerScriptService:WaitForChild("HelperQueue"):WaitForChild("Enqueue"):Invoke(player,effect)end
 end,
 yield=function()task.wait()end,
})
local tikkiesGateway=Instance.new("BindableFunction")
tikkiesGateway.Name="TikkiesGateway";tikkiesGateway.Parent=script
tikkiesGateway.OnInvoke=function(action,a,b,c,d)
 if action=="status"then return {nativeBusy=token~=nil and tikkiesExternal==nil,external=tikkiesExternal~=nil}end
 if action=="begin"then
  local playerId=type(a)=="string"and a:match("^%d+$")and tonumber(a)or nil
  local player=playerId and Players:GetPlayerByUserId(playerId)
  if not player or type(b)~="string"or #b<1 or #b>24 or not b:match("^[%w_][%w_%.]*$")
   or type(c)~="string"or #c<1 or #c>120 or type(d)~="string"or #d~=36 then return false,"invalid_binding"end
  if tikkiesExternal then
   return tikkiesExternal.session==c and owner==playerId and tikkiesExternal.namespace==d,"room_busy"
  end
  if token or busy then return false,"native_busy"end
  disconnect()
  owner=playerId;token=c
  tikkiesExternal={session=c,version=generation,namespace=d}
  require(ServerScriptService:WaitForChild("WinProfile")).SetChannel(player,b)
  live:SetAttribute("Transport","Tikkies");live:SetAttribute("Username",b);status("LIVE")
  return true
 elseif action=="submit"then
  local context=tikkiesExternal
  if not context or context.session~=a or token~=a or generation~=context.version then return false,"cancelled"end
  if not owner or not Players:GetPlayerByUserId(owner)then return false,"owner_unavailable"end
  if type(b)~="table"or type(b.id)~="string"or type(b.sender)~="table"then return false,"invalid_event"end
  local e=table.clone(b)
  if e.kind=="Portrait"then e.id=context.namespace..":portrait:"..tostring(e.sender.portraitId)
  else
   if #e.id<1 or #e.id>100 then return false,"invalid_event_id"end
   -- Binding UUID36 + colon + external ID100 fits native processor's 140-byte bound.
   e.id=context.namespace..":"..e.id
  end
  return tikkiesDispatch.Submit(e,owner,a)
 elseif action=="end"then
  if tikkiesExternal and tikkiesExternal.session==a then disconnect();return true end
  return false,"cancelled"
 end
 return false,"invalid_action"
end
-- TIKKIES_GATEWAY_V1_END

control.OnServerEvent:Connect(function(player,action,input)
    if tikkiesExternal then return end -- Tikkies owns this shared arena lease.
    if not operator(player) then return end
    if owner and owner~=player.UserId then return end
    local now=os.clock()
    if now-(cooldown[player] or -10)<3 then return end
    cooldown[player]=now
    if action=="disconnect" then disconnect();return end
    if action~="connect" or busy then return end
    if type(input)~="string" then return end
    local name=string.lower(string.gsub(string.gsub(input,"^%s*(.-)%s*$","%1"),"^@",""))
    if #name<1 or #name>24 or not name:match("^[%w_][%w_%.]*$") then status("INVALID_USERNAME");return end
    if not config.BridgeUrl:match("^https://") or #config.BridgeKey<32 then status("SETUP_REQUIRED");return end
    require(ServerScriptService:WaitForChild("WinProfile")).SetChannel(player,name)
    disconnect();busy=true;owner=player.UserId;token=Http:GenerateGUID(false);cursor=0
    local session,version=token,generation
    live:SetAttribute("Transport","Native")
    status("CONNECTING");live:SetAttribute("Username",name)
    task.spawn(function()
        local ok,connected=pcall(request,"POST","/connect",{username=name,protocol=2,gacha=true,follow=true,rawLikes=true,reliable=true},session)
        if version~=generation then pcall(request,"POST","/disconnect",{},session);return end
        busy=false
        if not ok then status("ERROR");token=nil;return end
        local reliable=type(connected)=="table" and connected.capabilities and connected.capabilities.reliable==true
        local pump=reliable and DeliveryPump.new({
            valid=function()return token==session and generation==version end,
            process=function(e)return process(e,owner,session,version)end,
        })or nil
        local failures=0
        local function terminal(value)return value=="OFFLINE" or value=="ERROR" or value=="DISCONNECTED" or value=="SIGNING_REQUIRED"end
        while token==session and generation==version do
            local requested=os.clock()
            local acks=pump and pump.Acks()or nil
            local path=pump and "/session/events?limit=100&waitMs=1000"or "/session/events?after="..cursor
            local success,data=pcall(request,"GET",path,nil,session,acks)
            if version~=generation then break end
            if success and type(data)=="table" then
                failures=0;status(data.status or "ERROR")
                live:SetAttribute("ReliableDelivery",reliable)
                live:SetAttribute("Dropped",data.dropped or 0);live:SetAttribute("Unmapped",data.unmapped or 0)
                live:SetAttribute("DeliveryPending",data.pending or 0);live:SetAttribute("DeliveryLagMs",data.oldestAgeMs or 0)
                live:SetAttribute("DeliveryWriteRetries",data.retryingWrites or 0)
                if data.gap then live:SetAttribute("Gap",true)end
                if pump then
                    pump.Confirm(acks)
                    pump.Receive(data.events)
                    local stats=pump.Stats()
                    live:SetAttribute("DeliveryInFlight",stats.active);live:SetAttribute("DeliveryRetries",stats.failures)
                    if stats.lastIssue then live:SetAttribute("LastIssue",stats.lastIssue)end
                    if data.pending==0 and pump.Idle() and terminal(data.status) then
                        token=nil;pcall(request,"POST","/disconnect",{},session);break
                    end
                else
                    local blocked=false
                    for _,e in ipairs(data.events or {})do
                        local accepted,reason=process(e,owner,session,version)
                        if version~=generation or token~=session then return end
                        if not accepted then status("BACKPRESSURE");live:SetAttribute("LastIssue",reason);blocked=true;break end
                        cursor=e.seq
                    end
                    if not blocked then cursor=data.cursor or cursor end
                    if not blocked and not data.hasMore and terminal(data.status)then
                        token=nil;pcall(request,"POST","/disconnect",{},session);break
                    end
                end
            else
                failures+=1;status("RETRYING")
                if failures>=10 and not reliable then status("ERROR");token=nil;pcall(request,"POST","/disconnect",{},session);break end
            end
            if failures>0 then task.wait(math.min(10,math.max(.2,config.PollSeconds)*failures))
            elseif pump then task.wait(math.max(.01,.18-(os.clock()-requested)))
            else task.wait(math.min(.2,config.PollSeconds))end
        end
    end)
end)
Players.PlayerAdded:Connect(function(p) p:SetAttribute("CanControlTikTok",operator(p)) end)
for _,p in Players:GetPlayers() do p:SetAttribute("CanControlTikTok",operator(p)) end
Players.PlayerRemoving:Connect(function(p) cooldown[p]=nil;if owner==p.UserId then disconnect() end end)
game:BindToClose(function() if token and not tikkiesExternal then pcall(request,"POST","/disconnect",{},token) end end)
status("DISCONNECTED")
]==========],bridgeV2=[==========[local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local config = require(ServerScriptService:WaitForChild("LiveConfig"))
local kit = game:GetService("ReplicatedStorage"):WaitForChild("BlackHole")
local control = kit:WaitForChild("LiveControl")
local live = kit:WaitForChild("LiveState")
local portraits = kit:WaitForChild("LivePortraits")
local nameCache=require(ServerScriptService:WaitForChild("LiveNameCache")).new({registry=kit:WaitForChild("LiveNames")})
local DeliveryPump=require(ServerScriptService:WaitForChild("LiveDeliveryPump"))
local gateway = ServerScriptService:WaitForChild("BlackHoleServer"):WaitForChild("SubmitGift")
local token, generation, cursor, owner = nil, 0, 0, nil
local tikkiesExternal=nil -- TIKKIES_OWNERSHIP_V1
local busy, cooldown = false, {}
local LikeCounter=require(ServerScriptService:WaitForChild("LikeRewardCounter"))
local likeCounter=LikeCounter.new(require(kit.Config).LikesPerReward)
local function publishLikes()
 live:SetAttribute("LikeRewardsEnabled",require(kit.Config).LikeRewardsEnabled)
 live:SetAttribute("LikeCounterStatus",likeCounter.status)
 live:SetAttribute("LikeProgress",likeCounter.remainder)
 live:SetAttribute("LikesPerReward",require(kit.Config).LikesPerReward)
end
publishLikes()
local followGuard = require(ServerScriptService:WaitForChild("FollowRewardGuard")).new(
 function(channel) return game:GetService("DataStoreService"):GetDataStore("TikTokFollowRewards_v1", channel) end,
 function() return Http:GenerateGUID(false) end)
local function isFollow(e)
 local kind=tostring(e.giftId or e.type or e.kind or e.event or ""):lower()
 return kind=="follow" or kind=="follows"
end
local function followIdentity(sender)
 -- Numeric platform IDs must arrive as strings to preserve TikTok's 64-bit precision.
 local id=sender.userId or sender.id
 if type(id)=="string" and id:match("^%d+$") and #id<=40 then return "uid:"..id end
 local username=sender.uniqueId or sender.username
 if type(username)=="string" then
  username=username:lower():gsub("^@","")
  if #username>0 and #username<=24 and username:match("^[%w_%.]+$") then return "user:"..username end
 end
 return nil
end
local function operator(player)
    -- LIVE is available to every player in this server.
    return player ~= nil and player.Parent == Players
end
local function status(value) live:SetAttribute("Status", value) end
local function request(method, path, body, session, acks)
    local response = Http:RequestAsync({Url=config.BridgeUrl..path, Method=method,
        Headers={["X-Magnet-Key"]=config.BridgeKey,["X-Magnet-Session"]=session,["Content-Type"]="application/json",["X-Magnet-Ack"]=acks and #acks>0 and Http:JSONEncode(acks)or nil},
        Body=method=="POST" and Http:JSONEncode(body or {}) or nil})
    if not response.Success then error("HTTP_"..response.StatusCode) end
    return Http:JSONDecode(response.Body)
end
local function disconnect()
    generation += 1
    local previous=tikkiesExternal==nil and token or nil
    tikkiesExternal=nil;live:SetAttribute("Transport",nil)
    token=nil; owner=nil; busy=false
    likeCounter=LikeCounter.new(require(kit.Config).LikesPerReward);publishLikes()
    status("DISCONNECTED");live:SetAttribute("Username", "")
    if previous then task.spawn(function() pcall(request,"POST","/disconnect",{},previous) end) end
end
local function portrait(sender)
    local requested=sender.portraitId
    if type(requested)~="string" or #requested~=33 or not requested:match("^p%x+$") then requested=nil end
    local pixels=sender.pixels
    if type(pixels)~="table" or (#pixels~=256 and #pixels~=1024) then return requested end
    for _,v in pixels do if type(v)~="number" or v~=v or v%1~=0 or v<0 or v>16777215 then return nil end end
    -- Content-derived ID means all gifts from this profile share one image.
    local encoded=Http:JSONEncode(pixels)
    local hash=0
    for i=1,#encoded do hash=(hash*31+string.byte(encoded,i))%2147483647 end
    local id=requested or ("p"..hash)
    local existing=portraits:FindFirstChild(id)
    if existing and existing.Value~=encoded then return nil end
    if not existing then
        if #portraits:GetChildren()>=256 then return nil end
        existing=Instance.new("StringValue");existing.Name=id;existing.Value=encoded;existing.Parent=portraits
    end
    return id
end
local function filteredSender(e,playerId)
    local name,nameId=nameCache.Get(e.sender.name or "viewer",playerId)
    return {name=name,nameId=nameId,seed=e.sender.seed,avatarId=portrait(e.sender)}
end
local receiptProgress={}
local function process(e, playerId, session, version)
    if type(e)~="table" or type(e.id)~="string" or #e.id>140 or type(e.sender)~="table" then return false,"invalid_event" end
    if e.kind=="Portrait" then portrait(e.sender);return true end
    if require(kit.Config).LikeRewardsEnabled==false then
        for _,field in ipairs({"giftId","type","kind","event"})do
            local value=tostring(e[field] or ""):lower()
            if value=="like" or value=="likes" then
                live:SetAttribute("LikeRewardsEnabled",false)
                return true,"likes_disabled"
            end
        end
    end

    local liking=LikeCounter.IsLike(e)
    local following=isFollow(e)
    if not following and not liking and (type(e.quantity)~="number" or e.quantity%1~=0 or e.quantity<1 or e.quantity>10000) then return false,"invalid_quantity" end
    local identity=following and followIdentity(e.sender)
    if following and not identity then
        live:SetAttribute("LastIssue","follow_missing_account_id")
        return true,"ignored_invalid_follow"
    end
    if token~=session or generation~=version then return false,"cancelled" end
    if following then
        local sender=filteredSender(e,playerId)
        local channel=live:GetAttribute("Username")
        return followGuard(channel,identity,function()
            if token~=session or generation~=version then return false,"cancelled" end
            return gateway:Invoke("Follow",sender,1,"follow:"..channel..":"..identity)
        end)
    end
    if liking then
        local counter=likeCounter
        local ok,reason=counter:Process(e,function(quantity,receipt)
            if token~=session or generation~=version then return false,"cancelled"end
            local sender=filteredSender(e,playerId)
            return gateway:Invoke("Likes",sender,quantity,receipt,playerId)
        end)
        if counter==likeCounter then publishLikes()end
        return ok,reason
    end
    local sender=filteredSender(e,playerId)
    -- Resume the failed chunk even if a long queue outlives gateway dedup retention.
    local progress=receiptProgress[e.id]
    if not progress or progress.id~=e.id or progress.session~=session or progress.version~=version then
        progress={id=e.id,session=session,version=version,left=e.quantity,chunk=1}
        receiptProgress[e.id]=progress
    end
    while progress.left>0 do
        if token~=session or generation~=version then return false,"cancelled" end
        local gift=require(kit.Config).Gifts[e.giftId]
        if not gift then return false,"unknown_gift" end
        local amount=math.min(progress.left,math.min(100,math.floor(require(kit.Config).MaxPending/(gift.Blocks or 1))))
        local ok,reason=gateway:Invoke(e.giftId,sender,amount,e.id..":"..progress.chunk,playerId)
        if not ok and reason~="duplicate" then return false,reason end
        progress.left-=amount
        progress.chunk+=1
    end
    if receiptProgress[e.id]==progress then receiptProgress[e.id]=nil end
    return true
end
-- TIKKIES_GATEWAY_V2_BEGIN
local tikkiesDispatch=require(ServerScriptService:WaitForChild("TikkiesDispatch")).new({
 valid=function(playerId,session)
  return tikkiesExternal~=nil and tikkiesExternal.session==session and token==session
   and generation==tikkiesExternal.version and owner==playerId and Players:GetPlayerByUserId(playerId)~=nil
 end,
 sender=filteredSender,
 process=function(e,playerId,session)
  local context=tikkiesExternal
  if not context or context.session~=session then return false,"cancelled"end
  return process(e,playerId,session,context.version)
 end,
 gift=function(effect,sender,amount,receipt,playerId)return gateway:Invoke(effect,sender,amount,receipt,playerId)end,
 helper=function(effect,playerId,sender,amount,receipt)
  local player=Players:GetPlayerByUserId(playerId)
  if not player then return false,"owner_unavailable"end
  local native=ServerScriptService:WaitForChild("BlackHoleServer")
  if effect=="HelpGacha"then return native:WaitForChild("TikkiesHelpGacha"):Invoke(sender,amount,receipt,playerId)
  elseif effect=="WinAdd"or effect=="WinRemove"then
   return native:WaitForChild("TikkiesWinAdjustment"):Invoke(player,effect=="WinAdd"and 1 or -1,receipt)
  elseif effect=="Shrink"then return ServerScriptService:WaitForChild("ArenaSettings"):WaitForChild("Shrink"):Invoke(player)
  else return ServerScriptService:WaitForChild("HelperQueue"):WaitForChild("Enqueue"):Invoke(player,effect)end
 end,
 yield=function()task.wait()end,
})
local tikkiesGateway=Instance.new("BindableFunction")
tikkiesGateway.Name="TikkiesGateway";tikkiesGateway.Parent=script
tikkiesGateway.OnInvoke=function(action,a,b,c,d)
 if action=="status"then return {nativeBusy=token~=nil and tikkiesExternal==nil,external=tikkiesExternal~=nil}end
 if action=="begin"then
  local playerId=type(a)=="string"and a:match("^%d+$")and tonumber(a)or nil
  local player=playerId and Players:GetPlayerByUserId(playerId)
  if not player or type(b)~="string"or #b<1 or #b>24 or not b:match("^[%w_][%w_%.]*$")
   or type(c)~="string"or #c<1 or #c>120 or type(d)~="string"or #d~=36 then return false,"invalid_binding"end
  if tikkiesExternal then
   return tikkiesExternal.session==c and owner==playerId and tikkiesExternal.namespace==d,"room_busy"
  end
  if token or busy then return false,"native_busy"end
  disconnect()
  owner=playerId;token=c
  tikkiesExternal={session=c,version=generation,namespace=d}
  live:SetAttribute("Transport","Tikkies");live:SetAttribute("Username",b);status("LIVE")
  return true
 elseif action=="submit"then
  local context=tikkiesExternal
  if not context or context.session~=a or token~=a or generation~=context.version then return false,"cancelled"end
  if not owner or not Players:GetPlayerByUserId(owner)then return false,"owner_unavailable"end
  if type(b)~="table"or type(b.id)~="string"or type(b.sender)~="table"then return false,"invalid_event"end
  local e=table.clone(b)
  if e.kind=="Portrait"then e.id=context.namespace..":portrait:"..tostring(e.sender.portraitId)
  else
   if #e.id<1 or #e.id>100 then return false,"invalid_event_id"end
   -- Binding UUID36 + colon + external ID100 fits native processor's 140-byte bound.
   e.id=context.namespace..":"..e.id
  end
  return tikkiesDispatch.Submit(e,owner,a)
 elseif action=="end"then
  if tikkiesExternal and tikkiesExternal.session==a then disconnect();return true end
  return false,"cancelled"
 end
 return false,"invalid_action"
end
-- TIKKIES_GATEWAY_V2_END

control.OnServerEvent:Connect(function(player,action,input)
    if tikkiesExternal then return end -- Tikkies owns this shared arena lease.
    if not operator(player) then return end
    if owner and owner~=player.UserId then return end
    local now=os.clock()
    if now-(cooldown[player] or -10)<3 then return end
    cooldown[player]=now
    if action=="disconnect" then disconnect();return end
    if action~="connect" or busy then return end
    if type(input)~="string" then return end
    local name=string.lower(string.gsub(string.gsub(input,"^%s*(.-)%s*$","%1"),"^@",""))
    if #name<1 or #name>24 or not name:match("^[%w_][%w_%.]*$") then status("INVALID_USERNAME");return end
    if not config.BridgeUrl:match("^https://") or #config.BridgeKey<32 then status("SETUP_REQUIRED");return end
    require(ServerScriptService:WaitForChild("WinProfile")).SetChannel(player,name)
    disconnect();busy=true;owner=player.UserId;token=Http:GenerateGUID(false);cursor=0
    local session,version=token,generation
    live:SetAttribute("Transport","Native")
    status("CONNECTING");live:SetAttribute("Username",name)
    task.spawn(function()
        local ok,connected=pcall(request,"POST","/connect",{username=name,protocol=2,gacha=true,follow=true,rawLikes=true,reliable=true},session)
        if version~=generation then pcall(request,"POST","/disconnect",{},session);return end
        busy=false
        if not ok then status("ERROR");token=nil;return end
        local reliable=type(connected)=="table" and connected.capabilities and connected.capabilities.reliable==true
        local pump=reliable and DeliveryPump.new({
            valid=function()return token==session and generation==version end,
            process=function(e)return process(e,owner,session,version)end,
        })or nil
        local failures=0
        local function terminal(value)return value=="OFFLINE" or value=="ERROR" or value=="DISCONNECTED" or value=="SIGNING_REQUIRED"end
        while token==session and generation==version do
            local requested=os.clock()
            local acks=pump and pump.Acks()or nil
            local path=pump and "/session/events?limit=100&waitMs=1000"or "/session/events?after="..cursor
            local success,data=pcall(request,"GET",path,nil,session,acks)
            if version~=generation then break end
            if success and type(data)=="table" then
                failures=0;status(data.status or "ERROR")
                live:SetAttribute("ReliableDelivery",reliable)
                live:SetAttribute("Dropped",data.dropped or 0);live:SetAttribute("Unmapped",data.unmapped or 0)
                live:SetAttribute("DeliveryPending",data.pending or 0);live:SetAttribute("DeliveryLagMs",data.oldestAgeMs or 0)
                live:SetAttribute("DeliveryWriteRetries",data.retryingWrites or 0)
                if data.gap then live:SetAttribute("Gap",true)end
                if pump then
                    pump.Confirm(acks)
                    pump.Receive(data.events)
                    local stats=pump.Stats()
                    live:SetAttribute("DeliveryInFlight",stats.active);live:SetAttribute("DeliveryRetries",stats.failures)
                    if stats.lastIssue then live:SetAttribute("LastIssue",stats.lastIssue)end
                    if data.pending==0 and pump.Idle() and terminal(data.status) then
                        token=nil;pcall(request,"POST","/disconnect",{},session);break
                    end
                else
                    local blocked=false
                    for _,e in ipairs(data.events or {})do
                        local accepted,reason=process(e,owner,session,version)
                        if version~=generation or token~=session then return end
                        if not accepted then status("BACKPRESSURE");live:SetAttribute("LastIssue",reason);blocked=true;break end
                        cursor=e.seq
                    end
                    if not blocked then cursor=data.cursor or cursor end
                    if not blocked and not data.hasMore and terminal(data.status)then
                        token=nil;pcall(request,"POST","/disconnect",{},session);break
                    end
                end
            else
                failures+=1;status("RETRYING")
                if failures>=10 and not reliable then status("ERROR");token=nil;pcall(request,"POST","/disconnect",{},session);break end
            end
            if failures>0 then task.wait(math.min(10,math.max(.2,config.PollSeconds)*failures))
            elseif pump then task.wait(math.max(.01,.18-(os.clock()-requested)))
            else task.wait(math.min(.2,config.PollSeconds))end
        end
    end)
end)
Players.PlayerAdded:Connect(function(p) p:SetAttribute("CanControlTikTok",operator(p)) end)
for _,p in Players:GetPlayers() do p:SetAttribute("CanControlTikTok",operator(p)) end
Players.PlayerRemoving:Connect(function(p) cooldown[p]=nil;if owner==p.UserId then disconnect() end end)
game:BindToClose(function() if token and not tikkiesExternal then pcall(request,"POST","/disconnect",{},token) end end)
status("DISCONNECTED")
]==========],server=[==========[local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
Players.CharacterAutoLoads = true
local kit = RS:WaitForChild("BlackHole")
local Config = require(kit.Config)
local Arena = require(kit:WaitForChild("ArenaMath"))
local event = kit.Event
local snapshot = kit.Snapshot
local testGift = kit.TestGift
local state = kit.State
local active, queue, seen, cooldown = {}, {}, {}, {}
local nextId, count, pending, consumed, wins = 0, 0, 0, 0, 0
local WinProfile=require(script.Parent:WaitForChild("WinProfile"))
-- WIN totals are owned by individual player profiles.
local clock, freezeUntil, spawnBudget, syncTime, clearTime = 0, 0, 0, 0, nil
local random = Random.new(8254)
local initialized = false
local holes = {}
local Gather=require(kit:WaitForChild("GatherMotion"))
local function equipMagnet(player, character)
    local humanoid=character:WaitForChild("Humanoid")
    local root=character:WaitForChild("HumanoidRootPart")
    if player.Character~=character then return end
    humanoid.WalkSpeed=Config.PlayerSpeed
    humanoid.JumpPower=0
    humanoid.JumpHeight=0
    humanoid.AutoRotate=true
    root.CFrame=CFrame.new(0,5,0)
    local tool=kit:WaitForChild("ElectromagnetTool"):Clone()
    tool.Name="Electromagnet"
    tool.Parent=player:WaitForChild("Backpack")
    humanoid:EquipTool(tool)
    tool.Unequipped:Connect(function()
        task.defer(function()
            if player.Character==character and humanoid.Health>0 and tool.Parent==player.Backpack then humanoid:EquipTool(tool) end
        end)
    end)
end
local function join(player)
    holes[player.UserId] = Vector3.zero
    player.CharacterAdded:Connect(function(character) task.spawn(equipMagnet,player,character) end)
    if player.Character then task.spawn(equipMagnet,player,player.Character) end
end
Players.PlayerAdded:Connect(join)
for _, player in Players:GetPlayers() do join(player) end
local function operator(player)
    return player ~= nil and player.Parent == Players
end
local function sync()
    state:SetAttribute("Clock", clock)
    state:SetAttribute("SyncedAt", workspace:GetServerTimeNow())
    state:SetAttribute("FreezeUntil", freezeUntil)
    state:SetAttribute("Active", count)
    state:SetAttribute("ActiveCapacity", Arena.Capacity())
    state:SetAttribute("Pending", pending)
    state:SetAttribute("Consumed", consumed)
    -- Personal WIN is replicated on each Player.
    state:SetAttribute("ClearCountdown", clearTime and math.max(0, math.ceil(clearTime<math.max(0,Config.ClearSeconds-3) and Config.ClearSeconds-clearTime or math.min(3,Config.ClearSeconds)-(clearTime-math.max(0,Config.ClearSeconds-3))/2)) or -1)
end
WinProfile.Changed.Event:Connect(function(player,value)
    sync()
end)
-- Manual win adjustments are queued; the saved score changes at the impact.
local adjustWins=kit:WaitForChild("AdjustWins")
local winCooldown={}
local winQueue={}
local winWorker=false
local function playWinQueue()
 if winWorker then return end
 winWorker=true
 task.spawn(function()
  local Http=game:GetService("HttpService")
  while #winQueue>0 do
   local now=workspace:GetServerTimeNow()
   local waitUntil=now
   for _,name in ipairs({"BearPourScene","ArenaExpansionScene"})do
    local raw=state:GetAttribute(name)
    if raw then local scene=Http:JSONDecode(raw);waitUntil=math.max(waitUntil,scene.ends or now)end
   end
   if waitUntil>now then task.wait(math.min(waitUntil-now,.25));continue end
   local job=table.remove(winQueue,1)
   state:SetAttribute("WinAdjustmentQueue",#winQueue)
   local p=job.player
   local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
   local scale=Arena.Read()
   local pos=root and root.Position or Vector3.new(0,0,0)
   local started=workspace:GetServerTimeNow()+.15
   local impact=started+2.6
   local ends=impact+3.0
   state:SetAttribute("WinAdjustmentScene",Http:JSONEncode({started=started,impact=impact,ends=ends,delta=job.delta,targetUserId=p.UserId,x=pos.X,y=Config.ArenaFloorY*scale,z=pos.Z}))
   task.wait(math.max(0,impact-workspace:GetServerTimeNow()))
   WinProfile.Add(p,job.delta)
   sync()
   task.wait(math.max(0,ends-workspace:GetServerTimeNow())+.08)
  end
  winWorker=false
 end)
end
adjustWins.OnServerEvent:Connect(function(player,delta)
 if not operator(player) or (delta~=1 and delta~=-1) then return end
 local now=os.clock()
 if now-(winCooldown[player] or -1)<.12 then return end
 winCooldown[player]=now
 table.insert(winQueue,{player=player,delta=delta})
 state:SetAttribute("WinAdjustmentQueue",#winQueue)
 playWinQueue()
end)
Players.PlayerRemoving:Connect(function(player)winCooldown[player]=nil end)
local function removeTen(player,amount)
    local ids={}
    for id in active do table.insert(ids,id) end
    local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local scale=Arena.Read()
    table.sort(ids,function(a,b)
        if root then
            local da=(active[a].position*scale-root.Position).Magnitude
            local db=(active[b].position*scale-root.Position).Magnitude
            if da~=db then return da<db end
        end
        return a<b
    end)

    local removals={}
    for i=1,math.min(amount or 10,#ids) do
        local id=ids[i]
        active[id]=nil
        table.insert(removals,id)
    end
    if #removals>0 then
        count-=#removals
        consumed+=#removals
        event:FireAllClients("Erase",{ids=removals,userId=player and player.UserId or 0})
        sync()
    end
    return #removals
end
local removeGateway=Instance.new("BindableFunction")
removeGateway.Name="RemoveTenBlocks";removeGateway.Parent=script;removeGateway.OnInvoke=removeTen
-- Removal requests are queued by HelperQueue.

local function enqueue(amount, sender, readyAt)
    if pending + amount > Config.MaxPending then return false, "queue_full" end
    table.insert(queue, {remaining = amount, sender = sender, readyAt = readyAt or 0})
    pending += amount
    clearTime = nil
    return true
end
local nextMeteorCinematicAt=0
local function playBlockMeteor(amount)
 local now=workspace:GetServerTimeNow()
 if now<nextMeteorCinematicAt then return nil end
 nextMeteorCinematicAt=now+10
 state:SetAttribute("MeteorCinematicReadyAt",nextMeteorCinematicAt)
 local ends=now+5.4
 state:SetAttribute("BearPourScene",game:GetService("HttpService"):JSONEncode({
  started=now,ends=ends,impactAt=now+2.3,amount=amount
 }))
 return ends
end
-- Shared server-authoritative gacha for keyboard controls and authenticated LIVE gifts.
local gacha=kit:WaitForChild("BlockGacha")
local gachaCooldown={}
local GachaQueue=require(script.Parent:WaitForChild("GachaQueue"))
local function removeGachaBlocks(player,amount)
 local removed=removeTen(player,amount)
 local left=amount-removed
 while left>0 and #queue>0 do
  local job=queue[1]
  local take=math.min(left,job.remaining)
  job.remaining-=take
  pending-=take
  left-=take
  removed+=take
  consumed+=take
  if job.remaining==0 then table.remove(queue,1) end
 end
 sync()
 return removed
end

local gachaQueue=GachaQueue.new({
 rewards=require(kit:WaitForChild("GachaRewards")),paidLimit=Config.MaxPending,
 items=require(kit:WaitForChild("MixedGachaItems")),
 resolvePlayer=function(player,paid)
  if player and player.Parent==Players then return player end
  return paid and Players:GetPlayers()[1]or nil
 end,
 applyItem=function(item,player,sender,rollId)
  if item.gift then
   local ok,reason=script:WaitForChild("SubmitGift"):Invoke(item.gift,sender,1,"mixed-item:"..rollId,player and player.UserId or nil)
   if reason=="duplicate"then ok=true end
   local sceneEnd
   if ok and item.gift=="Bear" then
    local raw=state:GetAttribute("BearPourScene")
    if raw then local scene=game:GetService("HttpService"):JSONDecode(raw)
     if scene.ends>workspace:GetServerTimeNow()then sceneEnd=scene.ends end
    end
   end
   return ok and math.max(1,item.amount)or 0,sceneEnd,reason
  elseif not player then return 0,nil,"owner_unavailable"
  elseif item.helper=="Shrink" then
   local ok=game.ServerScriptService.ArenaSettings:WaitForChild("Shrink"):Invoke(player)
   return ok and 1 or 0
  elseif item.helper=="Remove" then
   return removeGachaBlocks(player,10)
  else
   local ok=game.ServerScriptService.HelperQueue:WaitForChild("Enqueue"):Invoke(player,item.helper)
   return ok and 1 or 0
  end
 end,
 fire=function(kind,data)gacha:FireAllClients(kind,data)end,
 add=function(amount,sender)
  local actual=math.min(amount,math.max(0,Config.MaxPending-pending))
  if actual>0 then enqueue(actual,sender)end
  return actual
 end,
 remove=removeGachaBlocks,meteor=playBlockMeteor,sync=sync,
})
gacha.OnServerEvent:Connect(function(player,mode)
 if mode~="Prank" and mode~="Help" and mode~="Mixed" then return end
 if player:GetAttribute("CanUseMagnetBoost")~=true and not operator(player) then return end
 local now=os.clock()
 if now-(gachaCooldown[player] or -math.huge)<.12 then return end
 gachaCooldown[player]=now
 local ok,reason=gachaQueue.Submit(player,mode,{name=player.DisplayName,seed=player.UserId,userId=player.UserId},1)
 if not ok and reason=="gacha_queue_full" then gacha:FireClient(player,"Full")end
end)
Players.PlayerRemoving:Connect(function(player)
 gachaCooldown[player]=nil
 gachaQueue.RemovePlayer(player)
end)

local function accept(giftId, sender, quantity, eventId, requesterUserId)
    -- Acknowledge disabled likes so the bridge advances its cursor without blocking later gifts.
    if type(giftId)=="string" and (giftId:lower()=="likes" or giftId:lower()=="like") and Config.LikeRewardsEnabled==false then
        return true,"likes_disabled"
    end
    local gift = Config.Gifts[giftId]
    if not gift then return false, "unknown_gift" end
    quantity = quantity or 1
    if type(quantity) ~= "number" or quantity ~= quantity or quantity % 1 ~= 0 or quantity < 1 or quantity > 100 then
        return false, "invalid_quantity"
    end
    if type(eventId) ~= "string" or #eventId < 1 or #eventId > 160 then return false, "invalid_event_id" end
    if seen[eventId] then return false, "duplicate" end
    if type(sender) ~= "table" or type(sender.name) ~= "string" or #sender.name > 160 then return false, "invalid_sender" end
    local cleanSender = {name = sender.name, seed = tonumber(sender.seed) or 1}
    cleanSender.blockScale=(gift.Blocks and gift.Blocks>=1000) and 1.5 or ((gift.Blocks and gift.Blocks>=100) and 1.25 or 1)
    if cleanSender.seed ~= cleanSender.seed or math.abs(cleanSender.seed) > 2147483646 then cleanSender.seed = 1 end
    if type(sender.avatarId)=="string" and ((#sender.avatarId==33 and sender.avatarId:match("^p%x+$")) or kit.LivePortraits:FindFirstChild(sender.avatarId)) then cleanSender.avatarId=sender.avatarId end
    if type(sender.nameId)=="string" and kit.LiveNames:FindFirstChild(sender.nameId)then cleanSender.nameId=sender.nameId end
    if gift.GachaMode then
        local player=type(requesterUserId)=="number" and Players:GetPlayerByUserId(requesterUserId) or nil
        local ok,reason=gachaQueue.Submit(player,gift.GachaMode,cleanSender,quantity,{paid=true,giftId=giftId})
        if not ok then return false,reason end
        seen[eventId]=workspace:GetServerTimeNow()
        sync()
        return true
    end
    if gift.Blocks then
        local now=workspace:GetServerTimeNow()
        local playMeteor=giftId=="Bear"
        local ok, reason = enqueue(gift.Blocks * quantity, cleanSender, 0)
        if not ok then return false, reason end
        if playMeteor then playBlockMeteor(gift.Blocks*quantity) end
    elseif gift.ArenaExpandPercent then
        local now = workspace:GetServerTimeNow()
        local current, target = Arena.Read(now)
        local percent = math.min(Config.MaxGiftArenaPercent, math.floor(target * 100 + .5) + gift.ArenaExpandPercent * quantity)
        local http=game:GetService("HttpService")
        local oldScene=state:GetAttribute("ArenaExpansionScene")
        local sceneStart=now
        if oldScene then
            local scene=http:JSONDecode(oldScene)
            if now<scene.ends-.5 then sceneStart=scene.started end
        end
        local starts=math.max(now,sceneStart+.5)
        state:SetAttribute("ArenaTransition", http:JSONEncode({from=current, to=percent/100, started=starts, duration=1.8}))
        if percent>target*100+.001 then
            state:SetAttribute("ArenaExpansionScene",http:JSONEncode({started=sceneStart,ends=starts+2.5,from=current,to=percent/100}))
        end
    elseif gift.Freeze then
        freezeUntil = math.max(workspace:GetServerTimeNow(), freezeUntil) + gift.Freeze * quantity
    end
    seen[eventId] = workspace:GetServerTimeNow()
    sync()
    event:FireAllClients("Gift", {id = giftId, sender = cleanSender, quantity = quantity, arenaPercent = gift.ArenaExpandPercent and select(2, Arena.Read()) * 100 or nil})
    return true
end
-- Server-only integration. External adapters must authenticate and filter names first.
-- Never expose this to clients or accept arbitrary clients as paid gift receipts.
local gateway = Instance.new("BindableFunction")
gateway.Name = "SubmitGift"
gateway.Parent = script
gateway.OnInvoke = accept
snapshot.OnServerInvoke = function(player)
    local list = {}
    for _,block in active do table.insert(list, block) end
    return {blocks = list, holes = holes, canTest = operator(player)}
end
testGift.OnServerEvent:Connect(function(player, giftId)
    if not operator(player) or type(giftId) ~= "string" then return end
    local now = workspace:GetServerTimeNow()
    if now - (cooldown[player] or 0) < 0.65 then return end
    cooldown[player] = now
    accept(giftId, {name = player.DisplayName, seed = player.UserId}, 1, "test:"..player.UserId..":"..tostring(now))
end)
Players.PlayerRemoving:Connect(function(player)
    cooldown[player] = nil
    holes[player.UserId] = nil
end)
local stormSession
local function stormRoute(from,to,scale)
 state:SetAttribute("HelperMoveFrom",from)
 state:SetAttribute("HelperMoveTo",to)
 state:SetAttribute("HelperMoveClock",clock)
 state:SetAttribute("HelperMoveDuration",(to-from).Magnitude*scale/10)
end
local function publishGather(jobs)
 for first=1,#jobs,128 do
  local batch={}
  for i=first,math.min(first+127,#jobs)do table.insert(batch,jobs[i])end
  event:FireAllClients("Gather",batch)
 end
end
local function finishStorm(session,center,scale)
 session.finishClock=clock+(session.emptyAtStart and 1.5 or .7)
 stormRoute(center,center,scale)
 state:SetAttribute("HelperPhase","Settling")
 local jobs={}
 for id in session.picked do
  local block=active[id]
  if block and block.gather then
   local index=block.gather.index or 1
   local angle=index*2.399963
   local r=math.sqrt((index%37)/37)*4.3/scale
   local from=Gather.Position(block,clock)
   local target=center+Vector3.new(math.cos(angle)*r,math.min(8,math.floor((index-1)/37))*.4/scale,math.sin(angle)*r)
   block.gather={from=from,to=target,start=clock,duration=.7,settling=true}
   table.insert(jobs,{id=id,gather=block.gather})
  end
 end
 publishGather(jobs)
end
local function updateStorm(scale)
 local session=stormSession
 if not session then return end
 local now=workspace:GetServerTimeNow()
 state:SetAttribute("HelperUntil",now+1)
 if session.finishClock then
  if clock>=session.finishClock then
   state:SetAttribute("HelperUntil",0);state:SetAttribute("HelperPhase","Idle")
   if session.player.Parent then session.player:SetAttribute("HelperUntil",0)end
   stormSession=nil
  end
  return
 end
 if clock<session.nextScan then return end
 session.nextScan=clock+Gather.ScanInterval
 local center=Gather.CurrentCenter(clock)
 local remaining=0
 local nearest,nearestDistance=nil,math.huge
 local jobs={}
 local radiusSquared=(Gather.PullRadius/scale)^2
 for id in session.candidates do
  local block=active[id]
  if not block or block.capture or block.gather then
   session.candidates[id]=nil
  else
   local flat=Vector3.new(block.position.X,0,block.position.Z)
   local delta=flat-center
   local distance=delta:Dot(delta)
   if session.count<Gather.MaxBlocks and distance<=radiusSquared then
    session.count+=1;session.picked[id]=true;session.candidates[id]=nil
    block.gather={from=block.position,start=clock,liveStorm=true,stormStart=session.start,scale=scale,phase=session.count*2.399963,index=session.count}
    table.insert(jobs,{id=id,gather=block.gather})
   else
    remaining+=1
    if distance<nearestDistance then nearestDistance=distance;nearest=id end
   end
  end
 end
 publishGather(jobs)
 local goal=math.min(Gather.MaxBlocks,session.count+remaining)
 state:SetAttribute("HelperBlockCount",session.count)
 state:SetAttribute("HelperBlockGoal",goal)
 if session.count>=Gather.MaxBlocks or remaining==0 then
  finishStorm(session,center,scale)
 else
  -- Keep a stable destination until it has been picked up; speed is always 10 world studs/sec.
  if not session.destination or not session.candidates[session.destination] or session.routeScale~=scale then
   session.destination=nearest;session.routeScale=scale
   local destination=active[nearest].position
   destination=Vector3.new(destination.X,0,destination.Z)
   local limit=math.max(1,Config.ArenaRadius-9/scale)
   if destination.Magnitude>limit then destination=destination.Unit*limit end
   stormRoute(center,destination,scale)
  end
 end
end
local gatherGateway=Instance.new("BindableFunction")
gatherGateway.Name="GatherBlocks";gatherGateway.Parent=script
gatherGateway.OnInvoke=function(player)
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local now=workspace:GetServerTimeNow()
 if not root or now<freezeUntil or stormSession then return false end
 local candidates={};local available=0
 for id,block in active do
  if not block.capture and not block.gather then candidates[id]=true;available+=1 end
 end
 local scale=Arena.Read(now)
 local look=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
 if look.Magnitude<.1 then look=Vector3.new(0,0,-1)else look=look.Unit end
 local center=Vector3.new(root.Position.X,0,root.Position.Z)+look*15
 local limit=math.max(1,Config.ArenaRadius*scale-18)
 if center.Magnitude>limit then center=center.Unit*limit end
 center/=scale
 stormSession={start=clock,count=0,candidates=candidates,picked={},nextScan=clock,player=player,emptyAtStart=available==0}
 state:SetAttribute("HelperCenter",center)
 state:SetAttribute("HelperStartClock",clock)
 state:SetAttribute("HelperStartScale",scale)
 state:SetAttribute("HelperBlockGoal",math.min(Gather.MaxBlocks,available))
 state:SetAttribute("HelperBlockCount",0)
 state:SetAttribute("HelperPhase","Seeking")
 state:SetAttribute("HelperUntil",now+1)
 player:SetAttribute("HelperUntil",now+1)
 stormRoute(center,center,scale)
 updateStorm(scale)
 return true,state:GetAttribute("HelperBlockCount")
end
enqueue(Config.InitialBlocks, {name = "MAGNET LAB", seed = 101})
sync()
RunService.Heartbeat:Connect(function(dt)
    local now = workspace:GetServerTimeNow()
    local arenaScale,targetScale=Arena.Read(now)
    -- Network-owned characters carry inward locally. Let that position arrive before a safety correction.
    local recentScale=Arena.Read(now-Config.ArenaBoundaryGraceSeconds)
    local arenaRadius=Config.ArenaRadius*math.max(arenaScale,recentScale)
    local contracting=arenaScale>targetScale+.00001 or recentScale>arenaScale+.00001
    if contracting then
        local startScale=Arena.Read(now-Config.ArenaResizeSeconds)
        arenaRadius=Config.ArenaRadius*math.max(arenaScale,startScale)
    end
    local frozen=now<freezeUntil
    clock += dt

    for _,player in Players:GetPlayers() do
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if root and humanoid and humanoid.Health>0 then
            local speed=frozen and 0 or Config.PlayerSpeed*(now<(player:GetAttribute("SpeedBoostUntil") or 0) and 2 or 1)
            if humanoid.WalkSpeed~=speed then humanoid.WalkSpeed=speed end
            local position=Vector3.new(root.Position.X,0,root.Position.Z)
            if position.Magnitude>arenaRadius then
                position=position.Unit*(arenaRadius-.2)
                root.CFrame=CFrame.new(position.X,root.Position.Y,position.Z)*root.CFrame.Rotation
                root.AssemblyLinearVelocity=Vector3.zero
            end
            if root.Position.Y < -10 then root.CFrame=CFrame.new(0,5,0); position=Vector3.zero end
            holes[player.UserId]=position
        else holes[player.UserId]=nil end
    end
    if not initialized then
        spawnBudget = Config.InitialBlocks
        initialized = true
    else
        spawnBudget = math.min(spawnBudget + dt * Config.SpawnPerSecond, 50)
    end
    local additions, removals, captures = {}, {}, {}
    local activeCapacity = Arena.Capacity(arenaScale)
    while spawnBudget >= 1 and count < activeCapacity and #queue > 0 do
        local job = queue[1]
        if now<(job.readyAt or 0) then break end
        nextId += 1
        -- Canonical coordinates scale with the room, without replicating every block each frame.
        local radius, angle = math.sqrt(random:NextNumber())*Config.ArenaRadius, random:NextNumber(0, math.pi*2)
        local block = {id = nextId, birth = clock,
            position = Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius),
            angle = angle, sender = job.sender}
        active[nextId] = block
        table.insert(additions, block)
        count += 1
        pending -= 1
        job.remaining -= 1
        spawnBudget -= 1
        if job.remaining == 0 then table.remove(queue, 1) end
    end
    updateStorm(arenaScale)
    for id, block in active do
        if block.gather then
            local position,moving=Gather.Position(block,clock)
            block.position=position
            if not moving then block.position=block.gather.to;block.gather=nil end
        end
        if not block.gather and not block.capture and now >= freezeUntil and clock-block.birth >= .5 then
            local nearest, distance = nil, math.huge
            for userId, position in holes do
                local d = (position-block.position*arenaScale).Magnitude
                local owner=Players:GetPlayerByUserId(userId)
                local boosted=owner and now<(owner:GetAttribute("MagnetBoostUntil") or 0)
                local pullRadius=(state:GetAttribute("PullRadius") or Config.PullRadius)*(boosted and 3 or 1)
                if d < pullRadius and d < distance then nearest, distance = userId, d end

            end
            if nearest then
                block.capture = clock
                block.owner = nearest
                block.target = holes[nearest]
                block.captureOrigin=block.position*arenaScale+Vector3.new(0,Arena.FloorOffset(arenaScale),0)
                table.insert(captures,{id=id, capture=clock, owner=nearest, target=block.target,origin=block.captureOrigin})
            end
        end
        if block.capture and clock-block.capture >= Config.CaptureSeconds then
            active[id] = nil
            count -= 1
            consumed += 1
            table.insert(removals, id)
        end
    end
    if #additions > 0 then event:FireAllClients("Add", additions) end
    if #captures > 0 then event:FireAllClients("Captures", captures) end
    if #removals > 0 then event:FireAllClients("Remove", removals) end
    if count == 0 and pending == 0 and now >= freezeUntil then
        clearTime = (clearTime or 0) + dt
        if clearTime >= Config.ClearSeconds+math.min(3,Config.ClearSeconds) then
            -- Finish each round at the configured starting arena size.
            local resetNow=workspace:GetServerTimeNow()
            local resetFrom=Arena.Read(resetNow)
            state:SetAttribute("ArenaExpansionScene",nil)
            state:SetAttribute("ArenaTransition",game:GetService("HttpService"):JSONEncode({
                from=resetFrom,to=Config.DefaultArenaPercent/100,started=resetNow,duration=.9}))
            state:SetAttribute("ArenaRoundReset",(state:GetAttribute("ArenaRoundReset") or 0)+1)
            wins+=1 -- Round counter only; never persisted as a player's score.
            for _,winner in ipairs(Players:GetPlayers())do
                WinProfile.Add(winner,1)
                event:FireClient(winner,"Win",WinProfile.GetWins(winner))
            end
            clearTime = nil
            enqueue(Config.InitialBlocks, {name = "ROUND "..(wins+1), seed = wins+101})
        end
    else clearTime = nil end
    syncTime += dt
    if syncTime >= 0.1 then
        syncTime = 0
        sync()
        for id, time in seen do if now-time > 3600 then seen[id] = nil end end
    end
end)
print("[MagnetLab] Ready: native character movement, electromagnet, 500 blocks, 10-second clear timer.")


]==========],dispatch=[==========[-- Routes authenticated Tikkies receipts through the existing native authorities.
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
]==========],roomClient=[==========[-- Transport state is separate from native gameplay. No credentials are stored here.
local Client={}
function Client.SanitizeNativeIssue(value,key)
 local raw=tostring(value)
 if type(key)=="string"and #key>0 then raw=raw:gsub((key:gsub("(%W)","%%%1")),"[redacted-key]")end
 raw=raw:gsub("[Hh][Tt][Tt][Pp][Ss]?://%S+","[redacted-url]")
 return raw:sub(1,1000)
end
function Client.HttpIssue(status,reason)
 if type(status)~="number"or status%1~=0 or status<100 or status>599 then return "HTTP_REQUEST_FAILED"end
 local issue="HTTP_"..status
 if type(reason)=="string"and #reason<=64 and reason:match("^[%a][%w_%-]*$")then issue..=":"..reason end
 return issue
end
function Client.SafeIssue(value)
 local raw=tostring(value)
 local status,reason=raw:match("HTTP_(%d%d%d):([%w_%-]+)")
 if status then return Client.HttpIssue(tonumber(status),reason)end
 status=raw:match("HTTP_(%d%d%d)")
 if status then return Client.HttpIssue(tonumber(status))end
 for _,code in ipairs({"HTTP_TIMEOUT","HTTP_DISABLED","HTTP_THROTTLED","HTTP_INVALID_JSON","HTTP_REQUEST_FAILED"})do
  if raw:find(code,1,true)then return code end
 end
 return "HTTP_REQUEST_FAILED"
end
function Client.new(options)
 local binding,pump=nil,nil
 local lastRegistration,failures=nil,0
 local closed=false
 local api={}
 local function same(a,b)
  return a and b and a.id==b.id and a.generation==b.generation and a.ownerRobloxId==b.ownerRobloxId and a.channel==b.channel
 end
 local function present(id)
  for _,value in ipairs(options.players())do if value==id then return true end end
  return false
 end
 local function session(b)return b.id..":"..b.generation end
 local function finish()
  if binding then options.hook("end",session(binding))end
  binding=nil;pump=nil
 end
 local function valid(b)
  return not closed and same(binding,b)and b.expiresAt>options.now()and present(b.ownerRobloxId)
 end
 local function validBinding(value)
  return type(value)=="table"and type(value.id)=="string"and #value.id==36
   and type(value.ownerRobloxId)=="string"and value.ownerRobloxId:match("^%d+$")
   and type(value.channel)=="string"and #value.channel>0 and #value.channel<=24
   and value.channel:match("^[%w_][%w_%.]*$")
   and type(value.generation)=="number"and value.generation>0 and value.generation%1==0
   and type(value.expiresAt)=="number"and value.expiresAt>options.now()
 end
 function api.Step()
  if closed then return 20 end
  if binding and not valid(binding)then finish()end
  local ok,data=pcall(function()
   local now=options.now()
   if not lastRegistration or now-lastRegistration>=8000 then
    options.request("POST","/tikkies/room",{placeId=options.placeId,universeId=options.universeId,players=options.players(),nativeBusy=options.nativeBusy()}, {})
    lastRegistration=now
   end
   local sentBinding,sentPump=binding,pump
   local acks=sentPump and sentPump.Acks()or {}
   local response=options.request("POST","/tikkies/events",{
    waitMs=1000,limit=100,
    acks=acks,binding=sentBinding and sentBinding.id,generation=sentBinding and sentBinding.generation,
   },{})
   assert(type(response)=="table","invalid_room_response")
   local nextBinding=response.binding
   if not validBinding(nextBinding)or not present(nextBinding.ownerRobloxId)then
    finish()
   else
    if not same(binding,nextBinding)then
     finish()
     local started=options.hook("begin",nextBinding.ownerRobloxId,nextBinding.channel,session(nextBinding),nextBinding.id)
     if started then
      binding=table.clone(nextBinding)
      local activeBinding=binding
      pump=options.pump({
       valid=function()return valid(activeBinding)end,
       process=function(e)
        if not valid(activeBinding)then return false,"cancelled"end
        return options.hook("submit",session(activeBinding),e)
       end,
      })
     end
    else binding.expiresAt=nextBinding.expiresAt end
    if pump and valid(binding)then
     -- A response from another generation can never confirm this generation's ACKs.
     if sentPump==pump and same(sentBinding,nextBinding)then pump.Confirm(acks)end
     pump.Receive(response.events)
    end
   end
   response.issue=nil -- A successful poll clears old transport failures.
   options.publish(response,binding~=nil,pump and pump.Stats()or nil)
   return response
  end)
  if ok then failures=0;return 1.35 end
  failures+=1
  -- A stale ACK fence must be dropped before the next poll, or every retry is stale.
  if tostring(data):find("HTTP_409",1,true)then finish()end
  options.publish({status="retrying",issue=Client.SafeIssue(data)},binding~=nil,nil)
  return math.min(20,1.35*2^math.min(failures,4))
 end
 function api.Close()
  if closed then return end
  closed=true;finish()
  pcall(options.request,"POST","/tikkies/room/leave",{}, {})
 end
 return api
end
return Client
]==========],controller=[==========[-- Map credentials stay in server-only LiveConfig. This transport never opens TikTok LIVE.
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
]==========],patches=[==========[-- Pure, checked source transforms. Install against current native scripts, never old copies.
local Patch={}
local function once(source,old,new)
 local first,last=source:find(old,1,true)
 assert(first,"Native hook anchor missing: "..old:sub(1,80))
 assert(not source:find(old,last+1,true),"Native hook anchor is ambiguous")
 return source:sub(1,first-1)..new..source:sub(last+1)
end
local bridgeHook=[====[
-- TIKKIES_GATEWAY_V3_BEGIN
local tikkiesDispatch=require(ServerScriptService:WaitForChild("TikkiesDispatch")).new({
 valid=function(playerId,session)
  return tikkiesExternal~=nil and tikkiesExternal.session==session and token==session
   and generation==tikkiesExternal.version and owner==playerId and Players:GetPlayerByUserId(playerId)~=nil
 end,
 sender=filteredSender,
 process=function(e,playerId,session)
  local context=tikkiesExternal
  if not context or context.session~=session then return false,"cancelled"end
  return process(e,playerId,session,context.version)
 end,
 gift=function(effect,sender,amount,receipt,playerId)return gateway:Invoke(effect,sender,amount,receipt,playerId)end,
 helper=function(effect,playerId,sender,amount,receipt)
  local player=Players:GetPlayerByUserId(playerId)
  if not player then return false,"owner_unavailable"end
  local native=ServerScriptService:WaitForChild("BlackHoleServer")
  if effect=="HelpGacha"then return native:WaitForChild("TikkiesHelpGacha"):Invoke(sender,amount,receipt,playerId)
  elseif effect=="WinAdd"or effect=="WinRemove"then
   return native:WaitForChild("TikkiesWinAdjustment"):Invoke(player,effect=="WinAdd"and 1 or -1,receipt)
  elseif effect=="Shrink"then return ServerScriptService:WaitForChild("ArenaSettings"):WaitForChild("Shrink"):Invoke(player)
  else return ServerScriptService:WaitForChild("HelperQueue"):WaitForChild("Enqueue"):Invoke(player,effect)end
 end,
 yield=function()task.wait()end,
})
local tikkiesGateway=Instance.new("BindableFunction")
tikkiesGateway.Name="TikkiesGateway";tikkiesGateway.Parent=script
tikkiesGateway.OnInvoke=function(action,a,b,c,d)
 if action=="status"then return {nativeBusy=token~=nil and tikkiesExternal==nil,external=tikkiesExternal~=nil}end
 if action=="begin"then
  local playerId=type(a)=="string"and a:match("^%d+$")and tonumber(a)or nil
  local player=playerId and Players:GetPlayerByUserId(playerId)
  if not player or type(b)~="string"or #b<1 or #b>24 or not b:match("^[%w_][%w_%.]*$")
   or type(c)~="string"or #c<1 or #c>120 or type(d)~="string"or #d~=36 then return false,"invalid_binding"end
  if tikkiesExternal then
   return tikkiesExternal.session==c and owner==playerId and tikkiesExternal.namespace==d,"room_busy"
  end
  if token or busy then return false,"native_busy"end
  disconnect()
  owner=playerId;token=c
  tikkiesExternal={session=c,version=generation,namespace=d}
  live:SetAttribute("Transport","Tikkies");live:SetAttribute("Username",b);status("LIVE")
  return true
 elseif action=="submit"then
  local context=tikkiesExternal
  if not context or context.session~=a or token~=a or generation~=context.version then return false,"cancelled"end
  if not owner or not Players:GetPlayerByUserId(owner)then return false,"owner_unavailable"end
  if type(b)~="table"or type(b.id)~="string"or type(b.sender)~="table"then return false,"invalid_event"end
  local e=table.clone(b)
  if e.kind=="Portrait"then e.id=context.namespace..":portrait:"..tostring(e.sender.portraitId)
  else
   if #e.id<1 or #e.id>100 then return false,"invalid_event_id"end
   -- Binding UUID36 + colon + external ID100 fits native processor's 140-byte bound.
   e.id=context.namespace..":"..e.id
  end
  return tikkiesDispatch.Submit(e,owner,a)
 elseif action=="end"then
  if tikkiesExternal and tikkiesExternal.session==a then disconnect();return true end
  return false,"cancelled"
 end
 return false,"invalid_action"
end
-- TIKKIES_GATEWAY_V3_END
]====]
local function nativePost(source)
 source=once(source,"local function request(method, path, body, session, acks)\n","local function request(method, path, body, session, acks)\n    -- TIKKIES_NATIVE_POST_V1: Roblox rejects JSON array punctuation in header values.\n    if method==\"GET\" and type(acks)==\"table\" then method=\"POST\";body={acks=acks}end\n")
 return once(source,',["X-Magnet-Ack"]=acks and #acks>0 and Http:JSONEncode(acks)or nil',"")
end
function Patch.Bridge(source)
 if source:find("-- TIKKIES_GATEWAY_V3_BEGIN",1,true)then
  assert(source:find("-- TIKKIES_GATEWAY_V3_END",1,true)and source:find("-- TIKKIES_NATIVE_POST_V1",1,true),"Incomplete Tikkies POST patch")
  return source
 end
 if source:find("-- TIKKIES_GATEWAY_V2_BEGIN",1,true)then
  assert(source:find("-- TIKKIES_GATEWAY_V2_END",1,true),"Incomplete Tikkies gateway patch")
  source=once(source,"-- TIKKIES_GATEWAY_V2_BEGIN","-- TIKKIES_GATEWAY_V3_BEGIN")
  source=once(source,"-- TIKKIES_GATEWAY_V2_END","-- TIKKIES_GATEWAY_V3_END")
  return nativePost(source)
 end
 if source:find("-- TIKKIES_GATEWAY_V1_BEGIN",1,true)then
  assert(source:find("-- TIKKIES_GATEWAY_V1_END",1,true),"Incomplete Tikkies gateway patch")
  -- Upgrade only the external hook. Native LIVE's saved-channel setter stays intact.
  source=once(source,'  require(ServerScriptService:WaitForChild("WinProfile")).SetChannel(player,b)\n',"")
  source=once(source,"-- TIKKIES_GATEWAY_V1_BEGIN","-- TIKKIES_GATEWAY_V3_BEGIN")
  source=once(source,"-- TIKKIES_GATEWAY_V1_END","-- TIKKIES_GATEWAY_V3_END")
  return nativePost(source)
 end
 source=once(source,"local token, generation, cursor, owner = nil, 0, 0, nil","local token, generation, cursor, owner = nil, 0, 0, nil\nlocal tikkiesExternal=nil -- TIKKIES_OWNERSHIP_V1")
 source=once(source,"    local previous=token\n    token=nil; owner=nil; busy=false","    local previous=tikkiesExternal==nil and token or nil\n    tikkiesExternal=nil;live:SetAttribute(\"Transport\",nil)\n    token=nil; owner=nil; busy=false")
 source=once(source,"control.OnServerEvent:Connect(function(player,action,input)",bridgeHook.."\ncontrol.OnServerEvent:Connect(function(player,action,input)\n    if tikkiesExternal then return end -- Tikkies owns this shared arena lease.")
 source=once(source,'    status("CONNECTING");live:SetAttribute("Username",name)','    live:SetAttribute("Transport","Native")\n    status("CONNECTING");live:SetAttribute("Username",name)')
 source=once(source,'game:BindToClose(function() if token then pcall(request,"POST","/disconnect",{},token) end end)','game:BindToClose(function() if token and not tikkiesExternal then pcall(request,"POST","/disconnect",{},token) end end)')
 return nativePost(source)
end
local serverHook=[====[
-- TIKKIES_GAME_GATEWAYS_V1_BEGIN
local tikkiesHelpGacha=Instance.new("BindableFunction")
tikkiesHelpGacha.Name="TikkiesHelpGacha";tikkiesHelpGacha.Parent=script
tikkiesHelpGacha.OnInvoke=function(sender,quantity,eventId,requesterUserId)
 local player=type(requesterUserId)=="number"and Players:GetPlayerByUserId(requesterUserId)or nil
 if not player then return false,"owner_unavailable"end
 if type(quantity)~="number"or quantity~=quantity or quantity%1~=0 or quantity<1 or quantity>100 then return false,"invalid_quantity"end
 if type(eventId)~="string"or #eventId<1 or #eventId>160 then return false,"invalid_event_id"end
 if seen[eventId]then return false,"duplicate"end
 if type(sender)~="table"or type(sender.name)~="string"or #sender.name>160 then return false,"invalid_sender"end
 local clean={name=sender.name,seed=tonumber(sender.seed)or 1,blockScale=1}
 if clean.seed~=clean.seed or math.abs(clean.seed)>2147483646 then clean.seed=1 end
 if type(sender.avatarId)=="string"and((#sender.avatarId==33 and sender.avatarId:match("^p%x+$"))or kit.LivePortraits:FindFirstChild(sender.avatarId))then clean.avatarId=sender.avatarId end
 if type(sender.nameId)=="string"and kit.LiveNames:FindFirstChild(sender.nameId)then clean.nameId=sender.nameId end
 local ok,reason=gachaQueue.Submit(player,"Help",clean,quantity,{paid=true,giftId="HelpGacha"})
 if not ok then return false,reason end
 seen[eventId]=workspace:GetServerTimeNow();sync();return true
end
local tikkiesWinAdjustment=Instance.new("BindableFunction")
tikkiesWinAdjustment.Name="TikkiesWinAdjustment";tikkiesWinAdjustment.Parent=script
tikkiesWinAdjustment.OnInvoke=function(player,delta,eventId)
 if not player or player.Parent~=Players then return false,"owner_unavailable"end
 if delta~=1 and delta~=-1 then return false,"invalid_quantity"end
 if type(eventId)~="string"or #eventId<1 or #eventId>160 then return false,"invalid_event_id"end
 if seen[eventId]then return false,"duplicate"end
 table.insert(winQueue,{player=player,delta=delta})
 state:SetAttribute("WinAdjustmentQueue",#winQueue)
 seen[eventId]=workspace:GetServerTimeNow();playWinQueue();return true
end
-- TIKKIES_GAME_GATEWAYS_V1_END
]====]
function Patch.Server(source)
 if source:find("-- TIKKIES_GAME_GATEWAYS_V1_BEGIN",1,true)then
  assert(source:find("-- TIKKIES_GAME_GATEWAYS_V1_END",1,true),"Incomplete Tikkies game gateway patch")
  return source
 end
 return once(source,"gateway.OnInvoke = accept","gateway.OnInvoke = accept\n"..serverHook)
end
return Patch
]==========],installer=[==========[-- Stage the FOUR exact source files below as ModuleScripts s0..s3 in
-- ServerStorage.TikkiesStage_20261121. DryRun defaults true; explicitly set false
-- only after reviewing the dry-run result. This script never reads LiveConfig.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing Tikkies")
assert(game.PlaceId==113965026399564 and game.GameId==10775380860,"This installer is only for AC Magnet")
local stage=assert(game.ServerStorage:FindFirstChild("TikkiesStage_20261121"),"Tikkies staging folder missing")
local dryRun=stage:GetAttribute("DryRun")~=false
local function canonical(source)return(source:gsub("\r\n","\n"))end
local function hash(source)local h=0;for i=1,#source do h=(h*31+string.byte(source,i))%2147483647 end;return h end
local definitions={
 {key="s0",name="TikkiesDispatch",class="ModuleScript",hash=328877201},
 {key="s1",name="TikkiesRoomClient",class="ModuleScript",hash=1034121520,previousHashes={4204728,369874353,17747929}},
 {key="s2",name="TikkiesBridge",class="Script",hash=416709790,previousHashes={1550812153,996429594,761194767}},
 {key="s3",name="TikkiesPatches",class="ModuleScript",hash=2105567924,installerOnly=true},
}
local sources={}
for _,definition in ipairs(definitions)do
 local object=assert(stage:FindFirstChild(definition.key),"Missing stage source: "..definition.name)
 assert(object:IsA("LuaSourceContainer"),"Stage source must be a script")
 local source=canonical(object.Source)
 assert(hash(source)==definition.hash,"Staged source differs from review: "..definition.name)
 assert(loadstring(source,definition.name))
 sources[definition.name]=source
end
local Patch=assert(loadstring(sources.TikkiesPatches,"TikkiesPatches"))()
local SSS=game:GetService("ServerScriptService")
local targets={}
for _,definition in ipairs(definitions)do
 if not definition.installerOnly then
  local current=SSS:FindFirstChild(definition.name)
  if current then
   assert(current.ClassName==definition.class,"Unexpected existing class: "..definition.name)
   local matches=canonical(current.Source)==sources[definition.name]
   for _,oldHash in ipairs(definition.previousHashes or {})do if hash(canonical(current.Source))==oldHash then matches=true end end
   assert(matches,"Existing Tikkies module differs; review before updating: "..definition.name)
  end
  table.insert(targets,{name=definition.name,class=definition.class,current=current,source=sources[definition.name]})
 end
end
for _,definition in ipairs({
 {name="TikTokBridge",old=2058389496,previousHashes={740631241,1140701286},new=2031171183,patch=Patch.Bridge},
 {name="BlackHoleServer",old=1913009151,new=627228452,patch=Patch.Server},
})do
 local current=assert(SSS:FindFirstChild(definition.name),"Missing native script: "..definition.name)
 local old=canonical(current.Source)
 local oldHash=hash(old)
 local expected=oldHash==definition.old or oldHash==definition.new
 for _,known in ipairs(definition.previousHashes or {})do if oldHash==known then expected=true end end
 assert(expected,"Native source changed since audit; preserve and re-review: "..definition.name)
 local patched=definition.patch(old)
 assert(hash(patched)==definition.new,"Generated native patch differs: "..definition.name)
 assert(loadstring(patched,definition.name))
 table.insert(targets,{name=definition.name,class=current.ClassName,current=current,source=patched})
end
local changed={}
for _,target in ipairs(targets)do
 if not target.current or canonical(target.current.Source)~=target.source then table.insert(changed,target.name)end
end
if dryRun then return game:GetService("HttpService"):JSONEncode({dryRun=true,compiled=5,changes=changed,credentialsUntouched=true})end
if #changed==0 then return "Tikkies already installed; no changes"end
local backup=Instance.new("Folder")
backup.Name="BeforeTikkies_"..os.date("!%Y%m%d_%H%M%S").."_"..game:GetService("HttpService"):GenerateGUID(false):sub(1,8)
backup.Parent=game.ServerStorage
for _,target in ipairs(targets)do if target.current then target.current:Clone().Parent=backup end end
for _,target in ipairs(targets)do
 local object=target.current or Instance.new(target.class)
 object.Name=target.name;object.Source=target.source;object.Parent=SSS
end
return game:GetService("HttpService"):JSONEncode({installed=true,changes=changed,backup=backup.Name,credentialsUntouched=true})
]==========]}
