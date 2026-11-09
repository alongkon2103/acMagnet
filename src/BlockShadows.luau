-- One shared soft contact mask. Scene shadows remain native; tiny block shadows do not use shadow-map LOD.
local Lighting=game:GetService("Lighting")
local kit=game.ReplicatedStorage:WaitForChild("BlackHole")
local Config=require(kit.Config)
local module={}
local pool={}
local texture="rbxassetid://118876461475845"
local halfHeight=kit:WaitForChild("RoundedBlock").Size.Y/2
local sun=Lighting:GetSunDirection()
Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()sun=Lighting:GetSunDirection()end)
local root=Instance.new("Folder");root.Name="LocalBlockShadows"
local template=Instance.new("Part");template.Name="BlockContactShadow"
template.Anchored=true;template.CanCollide=false;template.CanTouch=false;template.CanQuery=false
template.CastShadow=false;template.Transparency=1;template.Size=Vector3.new(2.65,.01,2.4)
local decal=Instance.new("Decal");decal.Name="SoftContact";decal.Face=Enum.NormalId.Top
decal.ColorMapContent=Content.fromUri(texture);decal.Parent=template
function module.Acquire()
    if not root.Parent then root.Parent=workspace end
    local part=table.remove(pool)or template:Clone()
    part.Parent=root
    return part
end
function module.Pose(body,arenaScale,shrink,fade)
    local floorY=Config.ArenaFloorY*arenaScale
    local height=math.max(0,body.Position.Y-floorY-halfHeight*shrink)
    local offset=-Vector3.new(sun.X,0,sun.Z)*(math.min(3,height+.65)/math.max(.35,sun.Y))*.55
    local center=Vector3.new(body.Position.X+offset.X,floorY+.018,body.Position.Z+offset.Z)
    local look=body.LookVector
    local yaw=math.atan2(-look.X,-look.Z)
    local spread=(1+math.min(height,6)*.08)*shrink
    local size=Vector3.new(2.65*spread,.01,2.4*spread)
    local transparency=math.clamp(1-(1-fade)*math.sqrt(shrink)/(1+height*.2),0,1)
    return CFrame.new(center)*CFrame.Angles(0,yaw,0),size,transparency
end
function module.Place(part,body,arenaScale,shrink,fade)
    local pose,size,transparency=module.Pose(body,arenaScale,shrink,fade)
    if (part.Size-size).Magnitude>.0001 then part.Size=size end
    local image=part.SoftContact
    if math.abs(image.Transparency-transparency)>.001 then image.Transparency=transparency end
    return pose
end
function module.Release(part)
    if not part then return end
    if #pool<Config.MaxActive then part.Parent=nil;table.insert(pool,part)else part:Destroy()end
end
return module
