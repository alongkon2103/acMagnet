-- Edit-time installer for the Blender model. Insert asset118724006904787 as CopperConservatoryImport first.
-- Repairs affect this inserted package copy; rerun these repairs on a fresh asset insertion.
local arena=workspace.BlackHoleArena
local assetId="118724006904787"
local existing=arena:FindFirstChild("ArenaVisuals")
if existing and existing:GetAttribute("SourceAssetId")==assetId then return "Conservatory already installed"end
local imported=workspace:FindFirstChild("CopperConservatoryImport")
assert(imported and imported:IsA("Model"),"Insert the conservatory package first")
local parts={}
local floor,water
for _,v in imported:GetDescendants()do
    if v:IsA("BasePart")then
        table.insert(parts,v)
        if v.Name:find("FloorTile__",1,true)then floor=v end
        if v.Name:find("BotanicalCourt__Water",1,true)then water=v end
    end
end
assert(#parts==69 and floor and water,"Incomplete imported geometry")
assert(math.abs(floor.CFrame.UpVector.Y)>.99,"Unexpected import up-axis")
-- The GLB is exported in metres. Calibrate the known90-stud circular floor rather than assuming import units.
local conversion=90/math.max(floor.Size.X,floor.Size.Z)
imported:ScaleTo(imported:GetScale()*conversion)
-- The insertion flipped the source axes by180 degrees; derive the correction from the asymmetric water court.
local actual=water.Position-floor.Position
local expected=Vector3.new(-65,0,-4)
local yaw=math.atan2(actual.Z,actual.X)-math.atan2(expected.Z,expected.X)
local pivot=floor.Position
local turn=CFrame.new(pivot)*CFrame.Angles(0,yaw,0)*CFrame.new(-pivot)
imported:PivotTo(turn*imported:GetPivot())
imported:PivotTo(CFrame.new(Vector3.new(0,-.15,0)-floor.Position)*imported:GetPivot())
local palette={
    Ivory=Color3.fromRGB(232,222,191),Porcelain=Color3.fromRGB(242,236,217),
    SageFloor=Color3.fromRGB(166,182,160),FloorFleck=Color3.fromRGB(192,203,181),
    SageEnamel=Color3.fromRGB(87,123,104),DeepGreen=Color3.fromRGB(35,77,64),
    Copper=Color3.fromRGB(180,124,80),Brass=Color3.fromRGB(212,175,106),
    Walnut=Color3.fromRGB(140,99,70),Soil=Color3.fromRGB(82,89,73),
    LeafDark=Color3.fromRGB(49,95,66),LeafLight=Color3.fromRGB(96,132,90),
    Water=Color3.fromRGB(79,139,131),Glass=Color3.fromRGB(176,203,190),
    Lamp=Color3.fromRGB(255,230,177),Charcoal=Color3.fromRGB(61,73,64),
    Clay=Color3.fromRGB(188,136,112),Ground=Color3.fromRGB(142,159,133),
}
for _,v in parts do
    local material=v.Name:match("__(.-)__")
    material=material and material:gsub("%.%d+$","")
    assert(palette[material],"Unmatched source material: "..v.Name)
    v.Color=palette[material];v.Material=Enum.Material.SmoothPlastic
    v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.CastShadow=true
    v.Transparency=0;v.Reflectance=0
    v:SetAttribute("SourceMaterial",material)
    if material=="Copper"or material=="Brass"then v.Material=Enum.Material.Metal;v.Reflectance=.035
    elseif material=="Glass"then v.Material=Enum.Material.Glass;v.Transparency=.76;v.CastShadow=false;v.Reflectance=.025
    elseif material=="Lamp"then v.Material=Enum.Material.Neon;v.CastShadow=false
    elseif material=="Water"then v.Reflectance=.12
    elseif material=="SageEnamel"then v.Reflectance=.025 end
    if v:IsA("MeshPart")then v.RenderFidelity=Enum.RenderFidelity.Automatic end
end
floor.Name="FloorTile"
assert((water.Position-Vector3.new(-65,.68,-4)).Magnitude<.01,"Water court orientation or placement mismatch")
local storage=game.ServerStorage
local backup=Instance.new("Folder");backup.Name="BeforeConservatory_20261109";backup.Parent=storage
if existing then existing.Parent=backup end
local oldHidden=arena:FindFirstChild("ArtPass")
if oldHidden then oldHidden.Parent=backup end
local L=game:GetService("Lighting")
for _,property in {"ClockTime","Brightness","ExposureCompensation","Ambient","OutdoorAmbient","EnvironmentDiffuseScale","EnvironmentSpecularScale","GeographicLatitude","ShadowSoftness"}do
    backup:SetAttribute("Lighting_"..property,L[property])
end
for _,effect in L:GetChildren()do effect.Parent=backup end
local visuals=Instance.new("Model");visuals.Name="ArenaVisuals";visuals.WorldPivot=CFrame.identity
visuals:SetAttribute("SourceAssetId",assetId);visuals:SetAttribute("ArtDirection","Copper Conservatory")
imported.Name="CopperConservatory";imported.Parent=visuals;visuals.Parent=arena
visuals.WorldPivot=CFrame.identity
local percent=require(game.ReplicatedStorage.BlackHole.Config).DefaultArenaPercent
visuals:ScaleTo(percent/100)
local backdrop=arena:FindFirstChild("Backdrop")
if backdrop then backdrop.Color=Color3.fromRGB(153,167,143);backdrop.Material=Enum.Material.SmoothPlastic;backdrop.Size=Vector3.new(2048,1,2048)end
L.ClockTime=14.2;L.Brightness=2;L.ExposureCompensation=-.05
L.Ambient=Color3.fromRGB(95,110,93);L.OutdoorAmbient=Color3.fromRGB(150,163,144)
L.EnvironmentDiffuseScale=.55;L.EnvironmentSpecularScale=.55;L.GeographicLatitude=28
L.GlobalShadows=true;L.ShadowSoftness=.45
local atmosphere=Instance.new("Atmosphere");atmosphere.Name="ConservatoryAir";atmosphere.Density=.15;atmosphere.Haze=.6;atmosphere.Glare=.05
atmosphere.Color=Color3.fromRGB(220,228,212);atmosphere.Decay=Color3.fromRGB(162,175,146);atmosphere.Parent=L
local grade=Instance.new("ColorCorrectionEffect");grade.Name="WarmPorcelainGrade";grade.Contrast=.08;grade.Saturation=-.025;grade.TintColor=Color3.fromRGB(255,249,238);grade.Parent=L
local bloom=Instance.new("BloomEffect");bloom.Name="RestrainedOpalGlow";bloom.Intensity=.08;bloom.Threshold=1.6;bloom.Size=16;bloom.Parent=L
local sky=Instance.new("Sky");sky.Name="ConservatoryDaylight";sky.StarCount=0;sky.SunAngularSize=6;sky.Parent=L
game:GetService("ChangeHistoryService"):SetWaypoint("Install Blender Copper Conservatory")
return {meshParts=#parts,conversion=conversion,yawDegrees=math.deg(yaw),defaultPercent=percent,floorTop=floor.Position.Y+floor.Size.Y/2,waterPosition=tostring(water.Position)}
