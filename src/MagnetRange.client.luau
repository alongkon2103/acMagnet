local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local kit=game.ReplicatedStorage:WaitForChild("BlackHole")
local Config=require(kit.Config)
if player:GetAttribute("MagnetRingEnabled")==nil then player:SetAttribute("MagnetRingEnabled",false)end
local parts,transforms={},{}
local folder=Instance.new("Folder");folder.Name="LocalMagnetRange"
local floor=workspace:WaitForChild("BlackHoleArena"):FindFirstChild("FloorTile")
local floorY=(floor and floor.Position.Y+floor.Size.Y/2 or .2)+.04
local radius=Config.PullRadius
local opacity,lastOpacity=0,-1
local segments=48
local function build()
    if #parts>0 then return end
    for i=1,segments do
        local p=Instance.new("Part");p.Name="RangeSegment"..i;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
        p.Material=Enum.Material.SmoothPlastic;p.Color=Color3.fromRGB(148,102,64);p.Transparency=1;p.Parent=folder
        parts[i]=p
    end
end
RunService.RenderStepped:Connect(function(dt)
    local desired=Config.PullRadius
    radius+=(desired-radius)*(1-math.exp(-14*dt))
    local show=player:GetAttribute("MagnetRingEnabled")==true
    opacity+=((show and 1 or 0)-opacity)*(1-math.exp(-16*dt))
    if not show and opacity<.005 then folder.Parent=nil;return end
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then folder.Parent=nil;return end
    build();folder.Parent=workspace
    local center=Vector3.new(root.Position.X,floorY,root.Position.Z)
    local length=2*radius*math.sin(math.pi/segments)*1.01
    local alpha=1-opacity*.62
    for i,p in parts do
        local angle=(i-.5)*2*math.pi/segments
        local point=center+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
        transforms[i]=CFrame.lookAt(point,point+Vector3.new(-math.sin(angle),0,math.cos(angle)))
        p.Size=Vector3.new(.065,.018,length)
        if math.abs(opacity-lastOpacity)>.005 then p.Transparency=alpha end
    end
    if math.abs(opacity-lastOpacity)>.005 then lastOpacity=opacity end
    workspace:BulkMoveTo(parts,transforms,Enum.BulkMoveMode.FireCFrameChanged)
    folder:SetAttribute("DisplayedRadius",radius)
end)
