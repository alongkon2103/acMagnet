local RunService=game:GetService("RunService")
local player=game:GetService("Players").LocalPlayer
local kit=game.ReplicatedStorage:WaitForChild("BlackHole")
local Arena=require(kit:WaitForChild("ArenaMath"))
local Config=require(kit.Config)
local visuals=workspace:WaitForChild("BlackHoleArena"):WaitForChild("ArenaVisuals")
local last=visuals:GetScale()
local rendered=last
RunService:BindToRenderStep("MagnetArenaResize",Enum.RenderPriority.Camera.Value,function()
    local scale=Arena.Read()
    -- Carry an edge player inward with the contracting stage instead of waiting for a wall correction.
    if scale<last then
        local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local position=root.Position
            local flat=Vector3.new(position.X,0,position.Z)
            if flat.Magnitude>Config.ArenaRadius*scale*.85 then
                local carried=flat*(scale/last)
                local edge=Config.ArenaRadius*scale-.2
                if carried.Magnitude>edge then carried=carried.Unit*edge end
                root.CFrame+=carried-flat
            end
        end
    end
    last=scale
    if math.abs(scale-rendered)>.00001 then visuals:ScaleTo(scale);rendered=scale end
end)
