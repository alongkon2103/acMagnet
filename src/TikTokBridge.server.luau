local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local ServerScriptService = game:GetService("ServerScriptService")
local config = require(ServerScriptService:WaitForChild("LiveConfig"))
local kit = game:GetService("ReplicatedStorage"):WaitForChild("BlackHole")
local control = kit:WaitForChild("LiveControl")
local live = kit:WaitForChild("LiveState")
local portraits = kit:WaitForChild("LivePortraits")
local gateway = ServerScriptService:WaitForChild("BlackHoleServer"):WaitForChild("SubmitGift")
local token, generation, cursor, owner = nil, 0, 0, nil
local busy, cooldown = false, {}
local function operator(player)
    return RunService:IsStudio() or table.find(config.OperatorUserIds, player.UserId) ~= nil
        or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
        or (game.PrivateServerOwnerId ~= 0 and player.UserId == game.PrivateServerOwnerId)
end
local function status(value) live:SetAttribute("Status", value) end
local function request(method, path, body, session)
    local response = Http:RequestAsync({Url=config.BridgeUrl..path, Method=method,
        Headers={["X-Magnet-Key"]=config.BridgeKey,["X-Magnet-Session"]=session,["Content-Type"]="application/json"},
        Body=method=="POST" and Http:JSONEncode(body or {}) or nil})
    if not response.Success then error("HTTP_"..response.StatusCode) end
    return Http:JSONDecode(response.Body)
end
local function disconnect()
    generation += 1
    local previous=token
    token=nil; owner=nil; busy=false
    status("DISCONNECTED");live:SetAttribute("Username", "")
    if previous then task.spawn(function() pcall(request,"POST","/disconnect",{},previous) end) end
end
local function portrait(sender)
    local pixels=sender.pixels
    if type(pixels)~="table" or #pixels~=256 then return nil end
    for _,v in pixels do if type(v)~="number" or v~=v or v%1~=0 or v<0 or v>16777215 then return nil end end
    -- Content-derived ID means all gifts from this profile share one image.
    local encoded=Http:JSONEncode(pixels)
    local hash=0
    for i=1,#encoded do hash=(hash*31+string.byte(encoded,i))%2147483647 end
    local id="p"..hash
    local existing=portraits:FindFirstChild(id)
    if existing and existing.Value~=encoded then return nil end
    if not existing then
        if #portraits:GetChildren()>=256 then return nil end
        existing=Instance.new("StringValue");existing.Name=id;existing.Value=encoded;existing.Parent=portraits
    end
    return id
end
local function process(e, playerId, session, version)
    if type(e)~="table" or type(e.id)~="string" or #e.id>140 or type(e.sender)~="table" then return false,"invalid_event" end
    if type(e.quantity)~="number" or e.quantity%1~=0 or e.quantity<1 or e.quantity>10000 then return false,"invalid_quantity" end
    local name=tostring(e.sender.name or "viewer")
    if #name>160 then name="viewer" end
    if not RunService:IsStudio() then
        local ok,filtered=pcall(function() return TextService:FilterStringAsync(name,playerId):GetNonChatStringForBroadcastAsync() end)
        name=ok and filtered or "TikTok viewer"
    end
    if token~=session or generation~=version then return false,"cancelled" end
    local sender={name=name,seed=e.sender.seed,avatarId=portrait(e.sender)}
    -- Existing gateway accepts at most 100 per receipt. Retry retains stable chunk IDs.
    local left=e.quantity
    local chunk=0
    while left>0 do
        chunk+=1
        local gift=require(kit.Config).Gifts[e.giftId]
        if not gift then return false,"unknown_gift" end
        local amount=math.min(left,math.min(100,math.floor(require(kit.Config).MaxPending/(gift.Blocks or 1))))
        local ok,reason=gateway:Invoke(e.giftId,sender,amount,e.id..":"..chunk)
        if not ok and reason~="duplicate" then return false,reason end
        left-=amount
    end
    return true
end
control.OnServerEvent:Connect(function(player,action,input)
    if not operator(player) then return end
    local now=os.clock()
    if now-(cooldown[player] or -10)<3 then return end
    cooldown[player]=now
    if action=="disconnect" then disconnect();return end
    if action~="connect" or busy then return end
    if type(input)~="string" then return end
    local name=string.lower(string.gsub(string.gsub(input,"^%s*(.-)%s*$","%1"),"^@",""))
    if #name<1 or #name>24 or not name:match("^[%w_][%w_%.]*$") then status("INVALID_USERNAME");return end
    if not config.BridgeUrl:match("^https://") or #config.BridgeKey<32 then status("SETUP_REQUIRED");return end
    disconnect();busy=true;owner=player.UserId;token=Http:GenerateGUID(false);cursor=0
    local session,version=token,generation
    status("CONNECTING");live:SetAttribute("Username",name)
    task.spawn(function()
        local ok=pcall(request,"POST","/connect",{username=name},session)
        if version~=generation then pcall(request,"POST","/disconnect",{},session);return end
        busy=false
        if not ok then status("ERROR");token=nil;return end
        local failures=0
        while token==session and generation==version do
            local success,data=pcall(request,"GET","/session/events?after="..cursor,nil,session)
            if version~=generation then break end
            if success and type(data)=="table" then
                failures=0;status(data.status or "ERROR")
                live:SetAttribute("Dropped",data.dropped or 0);live:SetAttribute("Unmapped",data.unmapped or 0)
                if data.gap then live:SetAttribute("Gap",true) end
                local blocked=false
                for _,e in ipairs(data.events or {}) do
                    local accepted,reason=process(e,owner,session,version)
                    if version~=generation or token~=session then return end
                    if not accepted then status("BACKPRESSURE");live:SetAttribute("LastIssue",reason);blocked=true;break end
                    cursor=e.seq
                end
                if not blocked then cursor=data.cursor or cursor end
                if not blocked and not data.hasMore and (data.status=="OFFLINE" or data.status=="ERROR" or data.status=="DISCONNECTED" or data.status=="SIGNING_REQUIRED") then
                    token=nil
                    pcall(request,"POST","/disconnect",{},session);break
                end
            else
                failures+=1;status("RETRYING")
                if failures>=10 then status("ERROR");token=nil;pcall(request,"POST","/disconnect",{},session);break end
            end
            task.wait(math.min(10,config.PollSeconds*math.max(1,failures)))
        end
    end)
end)
Players.PlayerAdded:Connect(function(p) p:SetAttribute("CanControlTikTok",operator(p)) end)
for _,p in Players:GetPlayers() do p:SetAttribute("CanControlTikTok",operator(p)) end
Players.PlayerRemoving:Connect(function(p) cooldown[p]=nil;if owner==p.UserId then disconnect() end end)
game:BindToClose(function() if token then pcall(request,"POST","/disconnect",{},token) end end)
status("DISCONNECTED")
