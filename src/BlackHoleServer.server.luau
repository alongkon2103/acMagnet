local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
Players.CharacterAutoLoads = true
local kit = RS:WaitForChild("BlackHole")
local Config = require(kit.Config)
local event = kit.Event
local snapshot = kit.Snapshot
local testGift = kit.TestGift
local state = kit.State
local active, queue, seen, cooldown = {}, {}, {}, {}
local nextId, count, pending, consumed, wins = 0, 0, 0, 0, 0
local clock, freezeUntil, spawnBudget, syncTime, clearTime = 0, 0, 0, 0, nil
local random = Random.new(8254)
local initialized = false
local holes = {}
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
    return RunService:IsStudio() or table.find(Config.OperatorUserIds, player.UserId) ~= nil
end
local function sync()
    state:SetAttribute("Clock", clock)
    state:SetAttribute("SyncedAt", workspace:GetServerTimeNow())
    state:SetAttribute("FreezeUntil", freezeUntil)
    state:SetAttribute("Active", count)
    state:SetAttribute("Pending", pending)
    state:SetAttribute("Consumed", consumed)
    state:SetAttribute("Wins", wins)
    state:SetAttribute("ClearCountdown", clearTime and math.max(0, math.ceil(Config.ClearSeconds-clearTime)) or -1)
end
local function enqueue(amount, sender)
    if pending + amount > Config.MaxPending then return false, "queue_full" end
    table.insert(queue, {remaining = amount, sender = sender})
    pending += amount
    clearTime = nil
    return true
end
local function accept(giftId, sender, quantity, eventId)
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
    if cleanSender.seed ~= cleanSender.seed or math.abs(cleanSender.seed) > 2147483646 then cleanSender.seed = 1 end
    if type(sender.avatarId)=="string" and kit.LivePortraits:FindFirstChild(sender.avatarId) then cleanSender.avatarId=sender.avatarId end
    if gift.Blocks then
        local ok, reason = enqueue(gift.Blocks * quantity, cleanSender)
        if not ok then return false, reason end
    else
        freezeUntil = math.max(workspace:GetServerTimeNow(), freezeUntil) + gift.Freeze * quantity
    end
    seen[eventId] = workspace:GetServerTimeNow()
    sync()
    event:FireAllClients("Gift", {id = giftId, sender = cleanSender, quantity = quantity})
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
enqueue(Config.InitialBlocks, {name = "MAGNET LAB", seed = 101})
sync()
RunService.Heartbeat:Connect(function(dt)
    local now = workspace:GetServerTimeNow()
    local frozen=now<freezeUntil
    if not frozen then clock += dt end
    for _,player in Players:GetPlayers() do
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if root and humanoid and humanoid.Health>0 then
            local speed=frozen and 0 or Config.PlayerSpeed
            if humanoid.WalkSpeed~=speed then humanoid.WalkSpeed=speed end
            local position=Vector3.new(root.Position.X,0,root.Position.Z)
            if position.Magnitude>43 then
                position=position.Unit*42.8
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
    while spawnBudget >= 1 and count < Config.MaxActive and #queue > 0 do
        local job = queue[1]
        nextId += 1
        local radius, angle = math.sqrt(random:NextNumber())*43, random:NextNumber(0, math.pi*2)
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
    for id, block in active do
        if not block.capture and now >= freezeUntil and clock-block.birth >= .5 then
            local nearest, distance = nil, Config.PullRadius
            for userId, position in holes do
                local d = (position-block.position).Magnitude
                if d < distance then nearest, distance = userId, d end
            end
            if nearest then
                block.capture = clock
                block.owner = nearest
                block.target = holes[nearest]
                table.insert(captures,{id=id, capture=clock, owner=nearest, target=block.target})
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
        if clearTime >= Config.ClearSeconds then
            wins += 1
            clearTime = nil
            event:FireAllClients("Win", wins)
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


