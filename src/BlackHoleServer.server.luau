local RS = game:GetService("ReplicatedStorage")
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


