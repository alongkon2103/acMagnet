local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local kit=game:GetService("ReplicatedStorage"):WaitForChild("BlackHole")
local Config=require(kit.Config)
local Rules=require(kit:WaitForChild("MagnetSettingsRules"))
local liveConfig=require(game.ServerScriptService:WaitForChild("LiveConfig"))
local remote=kit:WaitForChild("MagnetSettings")
local state=kit.State
local pending,lastApplied={},{}
state:SetAttribute("PullRadius",Config.PullRadius)
local function allowed(player)
    return Rules.CanChange(RunService:IsStudio(),game.CreatorType==Enum.CreatorType.User and player.UserId==game.CreatorId,
        game.PrivateServerOwnerId~=0 and player.UserId==game.PrivateServerOwnerId,
        table.find(liveConfig.OperatorUserIds,player.UserId)~=nil)
end
remote.OnServerEvent:Connect(function(player,value)
    if not allowed(player) then return end
    local radius=Rules.Normalize(value,Config.MinPullRadius,Config.MaxPullRadius)
    if not radius then return end
    -- Coalesce drag updates, including the final release value, instead of dropping it.
    pending[player]=radius
end)
RunService.Heartbeat:Connect(function()
    local now=os.clock()
    for player,radius in pending do
        if now-(lastApplied[player] or -1)>=.1 then
            pending[player]=nil;lastApplied[player]=now
            if player.Parent==Players and allowed(player) then state:SetAttribute("PullRadius",radius)end
        end
    end
end)
Players.PlayerRemoving:Connect(function(player)pending[player]=nil;lastApplied[player]=nil end)
