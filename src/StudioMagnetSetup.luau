-- Edit-time bake of the generated warm magnet into the existing equip contract.
local kit=game.ReplicatedStorage.BlackHole
local source=workspace:FindFirstChild("Magnet") or game.ServerStorage:FindFirstChild("WarmMagnetSource")
assert(source,"Generate the warm magnet model before baking")
local baked=Instance.new("Model");baked.Name="BakedMagnet"
baked.WorldPivot=source:GetPivot()
for _,p in source:GetDescendants()do if p:IsA("BasePart")then p:Clone().Parent=baked end end
local _,bounds=baked:GetBoundingBox()
baked:ScaleTo(3.25/math.max(bounds.X,bounds.Y,bounds.Z))
baked:PivotTo(CFrame.identity)
local cuff=baked:FindFirstChild("BottomCuff")
assert(cuff,"Missing grip cuff")
local gripPoint=cuff.Position
local rotation=CFrame.Angles(0,math.pi,0)*CFrame.Angles(math.pi/2,0,0)
local transform=rotation*CFrame.new(-gripPoint)
local old=kit.ElectromagnetTool
local backup=game.ServerStorage:FindFirstChild("BeforeWarmToyLab_20261109")
if backup and not backup:FindFirstChild("ElectromagnetTool")then old:Clone().Parent=backup end
local tool=Instance.new("Tool");tool.Name="ElectromagnetTool";tool.CanBeDropped=false;tool.RequiresHandle=true
tool.Grip=old.Grip
local handle=Instance.new("Part");handle.Name="Handle";handle.Size=Vector3.new(.32,.85,.32)
handle.Transparency=1;handle.CanCollide=false;handle.CanTouch=false;handle.CanQuery=false;handle.Massless=true;handle.Parent=tool
local count=0
for _,p in baked:GetChildren()do
    p.CFrame=transform*p.CFrame;p.Anchored=false;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true
    p.CastShadow=true;p.Parent=tool
    local weld=Instance.new("WeldConstraint");weld.Part0=handle;weld.Part1=p;weld.Parent=p
    count+=1
end
local left=tool:FindFirstChild("PlateLeft");local right=tool:FindFirstChild("PlateRight")
local muzzle=Instance.new("Attachment");muzzle.Name="Muzzle";muzzle.Position=(left.Position+right.Position)/2+Vector3.new(0,0,-.1);muzzle.Parent=handle
local poleA=Instance.new("Attachment");poleA.Name="PoleLeft";poleA.Position=left.Position;poleA.Parent=handle
local poleB=Instance.new("Attachment");poleB.Name="PoleRight";poleB.Position=right.Position;poleB.Parent=handle
old:Destroy();tool.Parent=kit;baked:Destroy()
source.Name="WarmMagnetSource";source.Parent=game.ServerStorage
return {parts=count,grip=tostring(tool.Grip),muzzle=tostring(muzzle.Position)}
