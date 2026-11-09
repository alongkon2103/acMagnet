local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local kit=game.ReplicatedStorage:WaitForChild("BlackHole")
local Arena=require(kit:WaitForChild("ArenaMath"))
local config=require(game.ServerScriptService:WaitForChild("LiveConfig"))
local state=kit.State
local remote=kit:WaitForChild("ArenaSettings")
local collisions=workspace:WaitForChild("BlackHoleArena"):WaitForChild("ArenaCollisions")
local floor=workspace.BlackHoleArena:WaitForChild("ArenaCollisionFloor")
local Config=require(kit.Config)
local pending,lastApplied={},{}
local defaultScale=require(kit.Config).DefaultArenaPercent/100
state:SetAttribute("ArenaTransition",Http:JSONEncode({from=defaultScale,to=defaultScale,started=workspace:GetServerTimeNow()}))
local function allowed(player)
    return Arena.CanChange(RunService:IsStudio(),game.CreatorType==Enum.CreatorType.User and player.UserId==game.CreatorId,
        game.PrivateServerOwnerId~=0 and player.UserId==game.PrivateServerOwnerId,
        table.find(config.OperatorUserIds,player.UserId)~=nil)
end
remote.OnServerEvent:Connect(function(player,value)
    if not allowed(player)then return end
    local percent=Arena.NormalizePercent(value)
    if percent then pending[player]=percent end
end)
local accumulator,lastScale=0,collisions:GetScale()
local walls={}
for _,v in collisions:GetChildren()do if v.Name=="ArenaBoundary"then table.insert(walls,v)end end
local moving=false
RunService.Heartbeat:Connect(function(dt)
    local monotonic=os.clock()
    local now=workspace:GetServerTimeNow()
    for player,percent in pending do
        if monotonic-(lastApplied[player]or -1)>=.12 then
            pending[player]=nil;lastApplied[player]=monotonic
            if player.Parent==Players and allowed(player)then
                local from,target=Arena.Read(now)
                if math.abs(target-percent/100)>.0001 then
                    state:SetAttribute("ArenaTransition",Http:JSONEncode({from=from,to=percent/100,started=now}))
                end
            end
        end
    end
    accumulator+=dt
    local scale,target=Arena.Read(now)
    local resizing=math.abs(scale-target)>.00001
    if resizing~=moving then
        moving=resizing
        -- Resizing anchored walls must not impart a physics shove to nearby characters.
        for _,wall in walls do wall.CanCollide=not moving end
    end
    if accumulator>=1/30 then
        accumulator=0
        if math.abs(scale-lastScale)>.00001 then
            collisions:ScaleTo(scale);lastScale=scale
            -- A broad hidden floor supports characters during collision replication and low-FPS resizing.
            floor.Position=Vector3.new(0,Config.ArenaFloorY*scale-floor.Size.X/2,0)
            collisions:SetAttribute("AppliedScale",scale)
        end
    end
end)
Players.PlayerRemoving:Connect(function(player)pending[player]=nil;lastApplied[player]=nil end)
