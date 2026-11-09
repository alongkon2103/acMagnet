local AssetService=game:GetService("AssetService")
local Http=game:GetService("HttpService")
local registry=game:GetService("ReplicatedStorage"):WaitForChild("BlackHole"):WaitForChild("LivePortraits")
local images={}
local module={}
local fallbackCount=0
local desired=setmetatable({},{__mode="k"})
local function color(v) return Color3.fromRGB(math.floor(v/65536),math.floor(v/256)%256,v%256) end
local function get(id)
    if images[id] then return images[id] end
    local value=registry:FindFirstChild(id)
    if not value then return nil end
    local ok,pixels=pcall(Http.JSONDecode,Http,value.Value)
    if not ok or #pixels~=256 then return nil end
    local entry={pixels=pixels}
    local success,image=pcall(function()
        local editable=AssetService:CreateEditableImage({Size=Vector2.new(16,16)})
        if not editable then return nil end
        local bytes=buffer.create(1024)
        for i,v in pixels do
            local offset=(i-1)*4
            buffer.writeu8(bytes,offset,math.floor(v/65536))
            buffer.writeu8(bytes,offset+1,math.floor(v/256)%256)
            buffer.writeu8(bytes,offset+2,v%256)
            buffer.writeu8(bytes,offset+3,255)
        end
        editable:WritePixelsBuffer(Vector2.zero,Vector2.new(16,16),bytes)
        return editable
    end)
    if success then entry.image=image end
    images[id]=entry
    return entry
end
function module.Clear(part)
    desired[part]=nil
    local old=part:FindFirstChild("SenderPortrait")
    if old then
        if old:GetAttribute("PixelFallback") then fallbackCount-=1 end
        old:Destroy()
    end
end
function module.Apply(part,id)
    module.Clear(part)
    if type(id)~="string" then return false end
    desired[part]=id
    local entry=get(id)
    if not entry then return false end
    -- Retain the original portrait unless this renderer can create a replacement.
    if not entry.image and fallbackCount>=64 then return false end
    local gui=Instance.new("SurfaceGui")
    gui.Name="SenderPortrait";gui.Face=Enum.NormalId.Top;gui.CanvasSize=Vector2.new(160,160)
    gui.LightInfluence=0;gui.MaxDistance=100;gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize
    if entry.image then
        local label=Instance.new("ImageLabel")
        label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
        label.ResampleMode=Enum.ResamplerMode.Pixelated
        label.ImageContent=Content.fromObject(entry.image);label.Parent=gui
    else
        fallbackCount+=1;gui:SetAttribute("PixelFallback",true)
        -- Run-length rectangles reduce instances for flat regions of a 16x16 portrait.
        for y=0,15 do
            local x=0
            while x<16 do
                local v=entry.pixels[y*16+x+1]
                local finish=x+1
                while finish<16 and entry.pixels[y*16+finish+1]==v do finish+=1 end
                local frame=Instance.new("Frame");frame.BorderSizePixel=0;frame.BackgroundColor3=color(v)
                frame.Position=UDim2.fromScale(x/16,y/16);frame.Size=UDim2.fromScale((finish-x)/16,1/16);frame.Parent=gui
                x=finish
            end
        end
    end
    for _,c in part:GetChildren() do if c:IsA("SurfaceGui") then c:Destroy() end end
    gui.Parent=part
    return true
end
registry.ChildAdded:Connect(function(value)
    for part,id in desired do
        if id==value.Name and part.Parent then module.Apply(part,id) end
    end
end)
return module
