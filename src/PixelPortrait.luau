local AssetService=game:GetService("AssetService")
local Http=game:GetService("HttpService")
local registry=game:GetService("ReplicatedStorage"):WaitForChild("BlackHole"):WaitForChild("LivePortraits")
local images={}
local module={}
local fallbackCount=0
local desired=setmetatable({},{__mode="k"})
local visibilityCursor=nil
local function color(v) return Color3.fromRGB(math.floor(v/65536),math.floor(v/256)%256,v%256) end
local function get(id)
    if images[id] then return images[id] end
    local value=registry:FindFirstChild(id)
    if not value then return nil end
    local ok,pixels=pcall(Http.JSONDecode,Http,value.Value)
    if not ok or (#pixels~=256 and #pixels~=1024) then return nil end
    local size=math.sqrt(#pixels)
    local entry={pixels=pixels,size=size}
    local success,image=pcall(function()
        local editable=AssetService:CreateEditableImage({Size=Vector2.new(size,size)})
        if not editable then return nil end
        local bytes=buffer.create(#pixels*4)
        for i,v in pixels do
            local offset=(i-1)*4
            buffer.writeu8(bytes,offset,math.floor(v/65536))
            buffer.writeu8(bytes,offset+1,math.floor(v/256)%256)
            buffer.writeu8(bytes,offset+2,v%256)
            buffer.writeu8(bytes,offset+3,255)
        end
        editable:WritePixelsBuffer(Vector2.zero,Vector2.new(size,size),bytes)
        return editable
    end)
    if success then entry.image=image end
    images[id]=entry
    return entry
end
function module.Clear(part)
    if visibilityCursor==part then visibilityCursor=nil end
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
    if not entry.image and fallbackCount>=4 then return false end
    local folder=Instance.new("Folder");folder.Name="SenderPortrait"
    local content=Instance.new(entry.image and "ImageLabel" or "Frame");content.BackgroundTransparency=1
    content.Size=UDim2.fromScale(.8,.8);content.Position=UDim2.fromScale(.1,.1)
    content.ClipsDescendants=true
    local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.10,0);corner.Parent=content
    if entry.image then
        content.ResampleMode=Enum.ResamplerMode.Pixelated
        content.ImageContent=Content.fromObject(entry.image)
    else
        fallbackCount+=1;folder:SetAttribute("PixelFallback",true)
        -- Run-length rectangles reduce instances for flat regions of the portrait.
        local size=entry.size
        for y=0,size-1 do
            local x=0
            while x<size do
                local v=entry.pixels[y*size+x+1]
                local finish=x+1
                while finish<size and entry.pixels[y*size+finish+1]==v do finish+=1 end
                local frame=Instance.new("Frame");frame.BorderSizePixel=0;frame.BackgroundColor3=color(v)
                frame.Position=UDim2.fromScale(x/size,y/size);frame.Size=UDim2.fromScale((finish-x)/size,1/size);frame.Parent=content
                x=finish
            end
        end
    end
    for _,c in part:GetChildren() do if c:IsA("SurfaceGui") then c:Destroy() end end
    for _,face in {Enum.NormalId.Top,Enum.NormalId.Bottom,Enum.NormalId.Front,Enum.NormalId.Back,Enum.NormalId.Left,Enum.NormalId.Right} do
        local gui=Instance.new("SurfaceGui");gui.Name=face.Name;gui.Face=face
        -- Keep the print visible at every supported camera zoom; hidden faces are still culled below.
        gui.Adornee=part;gui.CanvasSize=Vector2.new(64,64);gui.LightInfluence=.2;gui.MaxDistance=0
        gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize
        content:Clone().Parent=gui;gui.Parent=folder
    end
    content:Destroy();folder.Parent=part
    return true
end
local normals={Top=Vector3.new(0,1,0),Bottom=Vector3.new(0,-1,0),Front=Vector3.new(0,0,-1),Back=Vector3.new(0,0,1),Left=Vector3.new(-1,0,0),Right=Vector3.new(1,0,0)}
function module.UpdateVisibility(cameraPosition)
    -- Spread visibility checks over frames; never render the three hidden faces.
    for _=1,160 do
        local part=next(desired,visibilityCursor)
        visibilityCursor=part
        if not part then return end
        if part.Parent then
            local folder=part:FindFirstChild("SenderPortrait")
            if folder then
                local view=part.CFrame:PointToObjectSpace(cameraPosition)
                for _,gui in folder:GetChildren() do
                    local enabled=view:Dot(normals[gui.Name])>0
                    if gui.Enabled~=enabled then gui.Enabled=enabled end
                end
            end
        end
    end
end
registry.ChildAdded:Connect(function(value)
    for part,id in desired do
        if id==value.Name and part.Parent then module.Apply(part,id) end
    end
end)
function module.ApplyFallback(part,seed)
    local requested=desired[part]
    local id="fallback_"..tostring(math.floor(math.abs(seed))%16)
    if not registry:FindFirstChild(id) then
        local pixels={}
        for y=0,15 do for x=0,15 do
            local v=14802388 -- warm paper
            if x>=3 and x<=12 and y>=2 and y<=12 then v=15058089 end
            if x>=3 and x<=12 and y>=2 and y<=4 then v=6442819 end
            if y>=7 and y<=8 and (x==5 or x==10)then v=4016440 end
            if y==10 and x>=6 and x<=9 then v=10453355 end
            if y>=13 and x>=2 and x<=13 then v=7974515 end
            table.insert(pixels,v)
        end end
        local value=Instance.new("StringValue");value.Name=id;value.Value=Http:JSONEncode(pixels);value.Parent=registry
    end
    local applied=module.Apply(part,id)
    -- A late-replicating live profile must still replace the temporary print.
    if requested and not requested:match("^fallback_") then desired[part]=requested end
    return applied
end
return module
