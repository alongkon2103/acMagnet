-- Edit-time art setup. Run from Studio MCP; never a runtime Script.
local kit=game.ReplicatedStorage.BlackHole
if not kit:FindFirstChild("RoundedBlock") then
    local temporary=Instance.new("Folder");temporary.Name="RoundedBlockBuild";temporary.Parent=workspace
    local origin=Vector3.new(0,-100,0)
    local pieces={}
    local function add(size,position,shape,rotation)
        local p=Instance.new("Part");p.Anchored=true;p.Size=size;p.Shape=shape or Enum.PartType.Block
        p.CFrame=CFrame.new(origin+position)*(rotation or CFrame.identity);p.Parent=temporary
        table.insert(pieces,p)
    end
    local side,inner,r=1.7,1.42,.14
    add(Vector3.new(side,inner,inner),Vector3.zero)
    add(Vector3.new(inner,side,inner),Vector3.zero)
    add(Vector3.new(inner,inner,side),Vector3.zero)
    for _,a in {-1,1} do for _,b in {-1,1} do
        add(Vector3.new(inner,r*2,r*2),Vector3.new(0,a*inner/2,b*inner/2),Enum.PartType.Cylinder)
        add(Vector3.new(inner,r*2,r*2),Vector3.new(a*inner/2,0,b*inner/2),Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
        add(Vector3.new(inner,r*2,r*2),Vector3.new(a*inner/2,b*inner/2,0),Enum.PartType.Cylinder,CFrame.Angles(0,math.pi/2,0))
        for _,c in {-1,1} do add(Vector3.new(r*2,r*2,r*2),Vector3.new(a,b,c)*inner/2,Enum.PartType.Ball) end
    end end
    local first=table.remove(pieces,1)
    local result=first:UnionAsync(pieces,Enum.CollisionFidelity.Hull,Enum.RenderFidelity.Automatic)
    result.Name="RoundedBlock";result.Anchored=true;result.CanCollide=false;result.CanTouch=false;result.CanQuery=false
    result.UsePartColor=true;result.Material=Enum.Material.SmoothPlastic;result.Reflectance=.025;result.CastShadow=true
    result.CFrame=CFrame.identity;result.Parent=kit
    temporary:Destroy()
end
local L=game:GetService("Lighting")
L.ClockTime=15.6;L.Brightness=2;L.ExposureCompensation=-.1
L.Ambient=Color3.fromRGB(90,92,82);L.OutdoorAmbient=Color3.fromRGB(130,138,121)
L.ColorShift_Top=Color3.new(0,0,0);L.ColorShift_Bottom=Color3.new(0,0,0)
L.GlobalShadows=true;L.ShadowSoftness=.5
for _,v in L:GetChildren() do
    if v:IsA("BloomEffect")then v.Enabled=false
    elseif v:IsA("DepthOfFieldEffect")then v.Enabled=false
    elseif v:IsA("SunRaysEffect")then v.Intensity=.025;v.Spread=.7
    elseif v:IsA("Atmosphere")then v.Density=.12;v.Haze=.5;v.Glare=.05;v.Color=Color3.fromRGB(232,224,204);v.Decay=Color3.fromRGB(189,202,181)
    elseif v:IsA("ColorCorrectionEffect")then v.Saturation=-.12;v.Contrast=.035;v.Brightness=0;v.TintColor=Color3.fromRGB(255,249,235)
    end
end
local sage=Color3.fromRGB(118,141,116)
local cream=Color3.fromRGB(215,209,190)
local copper=Color3.fromRGB(165,115,76)
local hide={OrbitInlay=true,RadialInlay=true,TowerWindows=true,Crystal=true,CrystalLight=true,UndersideGlow=true,CanopyFacet=true,TreeTrunk=true,FacetedCanopy=true}
local arena=workspace.BlackHoleArena
local i=0
for _,v in arena:GetDescendants() do
    if v:IsA("BasePart") then
        local n=v.Name
        if hide[n]then v.Transparency=1;v.CanCollide=false
        elseif n=="FloorTile" then
            local parity=math.floor(v.Position.X/8)+math.floor(v.Position.Z/8)
            v.Color=parity%2==0 and Color3.fromRGB(167,180,157) or Color3.fromRGB(162,176,153);v.Material=Enum.Material.SmoothPlastic;v.Reflectance=.015
        elseif n=="Backdrop" then v.Color=Color3.fromRGB(173,184,159);v.Material=Enum.Material.SmoothPlastic
        elseif n=="EdgeLight" or n=="GateLight" or n=="BollardLamp" then v.Color=Color3.fromRGB(249,224,174);v.Material=Enum.Material.SmoothPlastic
        elseif n=="DeckSeam" or n=="RimMarker" then v.Color=copper;v.Material=Enum.Material.SmoothPlastic;v.Transparency=.35
        elseif n=="ObservatoryTower" or n=="GatePillar" or n=="GardenBase" then v.Color=sage;v.Material=Enum.Material.SmoothPlastic
        elseif n=="RaisedRim" or n=="DeckBorder" or n=="InnerLip" or n=="GardenRim" then v.Color=copper;v.Material=Enum.Material.SmoothPlastic
        elseif n=="GardenBed" then v.Color=Color3.fromRGB(139,155,118);v.Material=Enum.Material.Grass
        else v.Color=cream;v.Material=Enum.Material.SmoothPlastic end
        i+=1;if i%300==0 then task.wait()end
    elseif v:IsA("Light")then v.Color=Color3.fromRGB(255,226,181);v.Brightness=.4;v.Range=12
    elseif v:IsA("TextLabel")then v.TextColor3=Color3.fromRGB(71,85,64);v.Font=Enum.Font.GothamMedium
    end
end
return {roundedBlock=kit.RoundedBlock.ClassName,recolored=i}
