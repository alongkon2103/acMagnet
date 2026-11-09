-- Generated transparent artwork owned by the experience's group.
local Art={Image="rbxassetid://134106926225991"}
-- Roblox resamples the 1254px source atlas to a 1024px image texture.
local textureScale=1024/1254
local rects={
    score={44,110,1166,237},
    menu={181,522,261,274},
    gifts={809,522,260,274},
}
function Art.New(class,name,props,parent)
    local r=assert(rects[name],"Unknown HUD sprite")
    local image=Instance.new(class)
    image.BackgroundTransparency=1;image.BorderSizePixel=0
    image.Image=Art.Image
    image.ImageRectOffset=Vector2.new(math.round(r[1]*textureScale),math.round(r[2]*textureScale))
    image.ImageRectSize=Vector2.new(math.round(r[3]*textureScale),math.round(r[4]*textureScale))
    image.ScaleType=Enum.ScaleType.Stretch
    for k,v in props do image[k]=v end
    image.Parent=parent
    return image
end
return Art
