-- Edit-time vivid colorway. Run after StudioConservatorySetup; geometry and gameplay are untouched.
local arena=workspace.BlackHoleArena
local visuals=arena:FindFirstChild("ArenaVisuals")
assert(visuals and visuals:GetAttribute("SourceAssetId")=="118724006904787","Install the conservatory first")
local L=game:GetService("Lighting")
local backdrop=arena:FindFirstChild("Backdrop")
local grade=L:FindFirstChild("ConservatoryVividGrade")or L:FindFirstChild("WarmPorcelainGrade")
local backup=game.ServerStorage:FindFirstChild("BeforeVividColor_20261109")
if not backup then
    backup=Instance.new("Folder");backup.Name="BeforeVividColor_20261109";backup.Parent=game.ServerStorage
    local copy=visuals:Clone();copy.Parent=backup
    for _,key in {"Ambient","OutdoorAmbient","Brightness","ExposureCompensation"}do backup:SetAttribute(key,L[key])end
    if backdrop then backup:SetAttribute("BackdropColor",backdrop.Color)end
    if grade then local copyGrade=grade:Clone();copyGrade.Parent=backup end
    local air=L:FindFirstChildOfClass("Atmosphere")
    if air then local copyAir=air:Clone();copyAir.Parent=backup end
end
local palette={
    Ivory=Color3.fromRGB(247,226,185),Porcelain=Color3.fromRGB(255,245,222),
    SageFloor=Color3.fromRGB(147,201,179),FloorFleck=Color3.fromRGB(207,231,212),
    SageEnamel=Color3.fromRGB(29,140,112),DeepGreen=Color3.fromRGB(20,89,71),
    Copper=Color3.fromRGB(207,130,62),Brass=Color3.fromRGB(235,184,64),
    Walnut=Color3.fromRGB(160,101,54),Soil=Color3.fromRGB(75,76,51),
    LeafDark=Color3.fromRGB(38,113,61),LeafLight=Color3.fromRGB(112,169,67),
    Water=Color3.fromRGB(37,171,166),Glass=Color3.fromRGB(169,219,204),
    Lamp=Color3.fromRGB(255,226,157),Charcoal=Color3.fromRGB(45,67,56),
    Clay=Color3.fromRGB(218,115,78),Ground=Color3.fromRGB(111,169,116),
}
local overrides={
    Workshop={SageEnamel=Color3.fromRGB(221,111,81),Ivory=Color3.fromRGB(255,223,157)},
    ConservatoryTrees={Walnut=Color3.fromRGB(116,78,44)},
    GalleryDetail={SageEnamel=Color3.fromRGB(25,109,83)},
    GardenPaths={Ivory=Color3.fromRGB(245,226,188)},
}
local count=0
for _,part in visuals:GetDescendants()do
    if part:IsA("BasePart")then
        local material=part:GetAttribute("SourceMaterial")
        if not material then material=part.Name:match("__(.-)__");material=material and material:gsub("%.%d+$","")end
        assert(material and palette[material],"Unmapped conservatory material: "..part.Name)
        local zone=part.Name:match("^(.-)__")
        local colors=zone and overrides[zone]
        part.Color=colors and colors[material]or palette[material]
        count+=1
    end
end
assert(count==69,"Unexpected conservatory geometry count")
if backdrop then backdrop.Color=Color3.fromRGB(140,181,145)end
L.Ambient=Color3.fromRGB(94,112,108);L.OutdoorAmbient=Color3.fromRGB(146,166,157)
L.Brightness=2;L.ExposureCompensation=-.03
if not grade then grade=Instance.new("ColorCorrectionEffect");grade.Parent=L end
grade.Name="ConservatoryVividGrade";grade.Enabled=true;grade.Brightness=0
grade.Contrast=.11;grade.Saturation=.06;grade.TintColor=Color3.fromRGB(255,253,247)
local air=L:FindFirstChildOfClass("Atmosphere")
if air then air.Density=.10;air.Haze=.30;air.Color=Color3.fromRGB(218,233,229);air.Decay=Color3.fromRGB(169,188,163)end
visuals:SetAttribute("Colorway","Vivid Garden")
game:GetService("ChangeHistoryService"):SetWaypoint("Apply vivid conservatory colors")
return {recoloredParts=count,colorway="Vivid Garden",scale=visuals:GetScale(),backup=backup.Name}
