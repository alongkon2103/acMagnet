local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local kit = RS:WaitForChild("BlackHole")
local Config = require(kit:WaitForChild("Config"))
local state = kit:WaitForChild("State")
local camera = workspace.CurrentCamera
local dark = Color3.fromRGB(13, 16, 35)
local white = Color3.fromRGB(240, 242, 255)
local cyan = Color3.fromRGB(78, 231, 255)
local purple = Color3.fromRGB(167, 95, 255)
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k,v in props do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function round(obj, radius)
    make("UICorner", {CornerRadius = UDim.new(0,radius or 12)}, obj)
end
local function text(parent, str, size, pos, bounds, color)
    return make("TextLabel", {BackgroundTransparency=1,Text=str,TextSize=size,
        Font=Enum.Font.GothamBold,TextColor3=color or white,Position=pos,Size=bounds,
        TextWrapped=true}, parent)
end
local gui = make("ScreenGui", {Name="BlackHoleHUD",ResetOnSpawn=false,IgnoreGuiInset=true}, player:WaitForChild("PlayerGui"))
local root = make("Frame", {BackgroundTransparency=1,Size=UDim2.fromScale(1,1)}, gui)
local title = text(root,"MAGNET LAB",32,UDim2.new(.5,-210,0,48),UDim2.fromOffset(420,42))
local subtitle = text(root,"แม่เหล็กไฟฟ้า • WASD / ลูกศร เพื่อเก็บบล็อก",15,UDim2.new(.5,-220,0,92),UDim2.fromOffset(440,24),cyan)
local score = make("Frame",{BackgroundColor3=dark,BackgroundTransparency=.12,Position=UDim2.new(.5,-200,0,126),Size=UDim2.fromOffset(400,68)},root)
round(score,16)
make("UIStroke",{Color=purple,Transparency=.4,Thickness=1},score)
local activeText = text(score,"0 บล็อก",25,UDim2.fromOffset(4,5),UDim2.fromOffset(230,32))
local pendingText = text(score,"คิว 0",12,UDim2.fromOffset(4,38),UDim2.fromOffset(230,20),cyan)
local winText = text(score,"WIN 0",24,UDim2.fromOffset(235,6),UDim2.fromOffset(160,50),Color3.fromRGB(255,214,112))
local status = text(root,"กำลังดูดบล็อก",21,UDim2.new(.5,-230,0,204),UDim2.fromOffset(460,34),cyan)
local toast = text(root,"",20,UDim2.new(.5,-270,1,-233),UDim2.fromOffset(540,45))
local panel = make("Frame",{BackgroundColor3=dark,BackgroundTransparency=.07,AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-24),Size=UDim2.fromOffset(660,164)},root)
round(panel,18)
local testLabel = text(panel,"รายการของขวัญ",13,UDim2.fromOffset(0,5),UDim2.new(1,0,0,24),cyan)
local buttons = {}
local canTest = false
local function sendGift(id) if canTest then kit.TestGift:FireServer(id) end end
for i,id in Config.Order do
    local gift = Config.Gifts[id]
    local b = make("TextButton",{Text="",AutoButtonColor=true,BackgroundColor3=Color3.fromRGB(28,31,57),
        Position=UDim2.fromOffset(12+(i-1)*162,35),Size=UDim2.fromOffset(150,116)},panel)
    round(b,12)
    make("UIStroke",{Color=gift.Color,Thickness=1,Transparency=.2},b)
    text(b,tostring(i),12,UDim2.fromOffset(7,5),UDim2.fromOffset(18,18),gift.Color)
    text(b,gift.Name,19,UDim2.fromOffset(0,15),UDim2.new(1,0,0,30),gift.Color)
    text(b,gift.Blocks and "+"..gift.Blocks.." บล็อก" or "แช่แข็ง 10 วิ",16,UDim2.fromOffset(0,49),UDim2.new(1,0,0,27))
    text(b,gift.Coins.." เหรียญ",14,UDim2.fromOffset(0,82),UDim2.new(1,0,0,22),Color3.fromRGB(171,177,205))
    b.Activated:Connect(function() sendGift(id) end)
    buttons[id] = b
end
local scale = make("UIScale",{Scale=1},panel)
local scoreScale = make("UIScale",{Scale=1},score)
local function resize()
    local width = camera.ViewportSize.X
    scale.Scale = math.min(1,(width-24)/660)
    local s = math.min(1,(width-24)/400)
    scoreScale.Scale = s
    score.Position = UDim2.new(.5,-200*s,0,126)
    camera.FieldOfView = Config.CameraFOV
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
resize()
local keymap = {[Enum.KeyCode.One]="Rose",[Enum.KeyCode.Two]="Roses",[Enum.KeyCode.Three]="Perfume",[Enum.KeyCode.Four]="Bear"}
UIS.InputBegan:Connect(function(input, processed)
    if not processed and keymap[input.KeyCode] then sendGift(keymap[input.KeyCode]) end
end)
local visuals = make("Folder",{Name="LocalGiftBlocks"},workspace)
local PixelPortrait=require(kit:WaitForChild("PixelPortrait"))
local blocks = {}
local animated = {}
local moveParts,moveCFrames = {},{}
local portraitTemplates=kit:FindFirstChild("PortraitTemplates")
local blockPool={}
local pooledCount=0
local pendingVisuals,pendingCaptures={},{}
local pendingIndex=1
local removed = {}
local beamCount=0
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false) end)
local function magnetTarget(userId,fallback)
    local owner=Players:GetPlayerByUserId(tonumber(userId) or 0)
    local character=owner and owner.Character
    local tool=character and character:FindFirstChild("Electromagnet")
    local muzzle=tool and tool:FindFirstChild("Muzzle",true)
    if muzzle and muzzle:IsA("Attachment") then return muzzle.WorldPosition,muzzle end
    local rootPart=character and character:FindFirstChild("HumanoidRootPart")
    return rootPart and rootPart.Position or (fallback or Vector3.zero)+Vector3.new(0,2,0),nil
end
local function releaseBeam(b)
    if b.beam then b.beam:Destroy(); b.beam=nil; beamCount-=1 end
    if b.pullAttachment then b.pullAttachment:Destroy(); b.pullAttachment=nil end
end
local function shape(parent,x,y,w,h,color,rounded)
    local f = make("Frame",{BorderSizePixel=0,BackgroundColor3=color,Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h)},parent)
    if rounded then make("UICorner",{CornerRadius=UDim.new(1,0)},f) end
    return f
end
local function portrait(part,seed)
    local rng = Random.new(math.floor(seed))
    local skin = ({Color3.fromRGB(255,211,169),Color3.fromRGB(202,140,97),Color3.fromRGB(139,86,62)})[rng:NextInteger(1,3)]
    local hair = Color3.fromHSV(rng:NextNumber(),.4,.22)
    local shirt = Color3.fromHSV(rng:NextNumber(),.65,.95)
    local surf = make("SurfaceGui",{Face=Enum.NormalId.Top,CanvasSize=Vector2.new(96,96),LightInfluence=0,MaxDistance=90,SizingMode=Enum.SurfaceGuiSizingMode.FixedSize},part)
    shape(surf,0,0,1,1,shirt,false)
    shape(surf,.18,.07,.64,.69,hair,true)
    shape(surf,.24,.22,.52,.53,skin,true)
    shape(surf,.24,.11,.52,.23,hair,true)
    shape(surf,.32,.40,.08,.1,dark,true)
    shape(surf,.60,.40,.08,.1,dark,true)
    shape(surf,.40,.60,.20,.065,Color3.fromRGB(165,66,78),true)
    shape(surf,.18,.77,.64,.23,white,true)
end
local function add(data)
    if blocks[data.id] or removed[data.id] then return end
    local capture=pendingCaptures[data.id]
    if capture then
        data.capture=capture.capture; data.owner=capture.owner; data.target=capture.target
        pendingCaptures[data.id]=nil
    end
    local templateId=tostring(math.floor(math.abs(data.sender.seed))%16+1)
    local template=portraitTemplates and portraitTemplates:FindFirstChild(templateId)
    local p
    if template then
        local pool=blockPool[templateId]
        p=pool and table.remove(pool)
        if p then pooledCount-=1 else p=template:Clone() end
        p.Size=template.Size
        p.Name="Gift_"..data.id
        p.Parent=visuals
        data.templateId=templateId
    else
        local color=Color3.fromHSV((data.sender.seed%997)/997,.52,.95)
        p=make("Part",{Name="Gift_"..data.id,Size=Vector3.new(1.7,1.7,1.7),Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,
            Material=Enum.Material.SmoothPlastic,Color=color,CastShadow=false},visuals)
        portrait(p,data.sender.seed)
    end
    PixelPortrait.Apply(p,data.sender.avatarId)
    p.CFrame=CFrame.new(data.position.X,6.1,data.position.Z)*CFrame.Angles(0,data.angle,0)
    p.LocalTransparencyModifier=0
    data.part=p
    data.baseSize=p.Size
    blocks[data.id]=data
    local sim=state:GetAttribute("Clock") or 0
    if data.capture or sim-data.birth<.5 then
        animated[data.id]=data
    else
        p.CFrame=CFrame.new(data.position.X,1.1,data.position.Z)*CFrame.Angles(0,data.angle,0)
    end
end
local toastVersion = 0
local function announce(message,color)
    toastVersion += 1
    local version=toastVersion
    toast.Text=message
    toast.TextColor3=color or white
    task.delay(4,function() if toastVersion==version then toast.Text="" end end)
end
local function received(action,payload)
    if action=="Add" then for _,b in payload do table.insert(pendingVisuals,b) end
    elseif action=="Captures" or action=="Capture" then
        for _,capture in (action=="Captures" and payload or {payload}) do
            local b=blocks[capture.id]
            if b then b.capture=capture.capture; b.owner=capture.owner; b.target=capture.target; animated[b.id]=b
            elseif not removed[capture.id] then pendingCaptures[capture.id]=capture end
        end
    elseif action=="Remove" then for _,id in payload do
        removed[id]=true
        pendingCaptures[id]=nil
        animated[id]=nil
        local b=blocks[id]
        if b then
            releaseBeam(b)
            PixelPortrait.Clear(b.part)
            if b.templateId and pooledCount<Config.MaxActive then
                b.part.Parent=nil
                blockPool[b.templateId]=blockPool[b.templateId] or {}
                table.insert(blockPool[b.templateId],b.part)
                pooledCount+=1
            else b.part:Destroy() end
            blocks[id]=nil
        end
    end
    elseif action=="Gift" then
        local gift=Config.Gifts[payload.id]
        announce(payload.sender.name.." • "..gift.Name.." ×"..payload.quantity,gift.Color)
    elseif action=="Win" then announce("ลานสะอาด!  WIN "..payload,Color3.fromRGB(255,214,112)) end
end
kit.Event.OnClientEvent:Connect(received)
local initial = kit.Snapshot:InvokeServer()
canTest=initial.canTest
testLabel.Text=canTest and "โหมดทดสอบฟรี • กด 1–4 หรือแตะของขวัญ • ส่งของขวัญทดสอบ" or "รายการของขวัญ • รอระบบเชื่อมต่อ LIVE"
for _,b in initial.blocks do table.insert(pendingVisuals,b) end
local hudAccumulator=0
-- Follow the locally simulated character every rendered frame, not 10 Hz server snapshots.
-- Fixed target height removes gait/jump bob. Only this binding writes the camera.
RunService:BindToRenderStep("MagnetFollowCamera",Enum.RenderPriority.Camera.Value+1,function()
    local character=player.Character
    local rootPart=character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    camera=workspace.CurrentCamera
    camera.CameraType=Enum.CameraType.Scriptable
    local focus=Vector3.new(rootPart.Position.X,2,rootPart.Position.Z)
    camera.CFrame=CFrame.lookAt(focus+Config.CameraOffset,focus)
    camera.Focus=CFrame.new(focus)
end)
RunService.RenderStepped:Connect(function(dt)
    -- Spread large gifts and round resets across frames instead of stalling one frame.
    local budgetStart=os.clock()
    local built=0
    while pendingIndex<=#pendingVisuals and built<40 and os.clock()-budgetStart<.002 do
        add(pendingVisuals[pendingIndex])
        pendingIndex+=1; built+=1
    end
    if pendingIndex>#pendingVisuals then table.clear(pendingVisuals); pendingIndex=1 end
    local now=workspace:GetServerTimeNow()
    local remain=math.max(0,(state:GetAttribute("FreezeUntil") or 0)-now)
    local frozen=remain>0
    local sim=(state:GetAttribute("Clock") or 0)+(frozen and 0 or math.clamp(now-(state:GetAttribute("SyncedAt") or now),0,.3))
    -- Animate only spawning/captured blocks, at the display's render rate.
    -- Settled blocks require no per-frame iteration or transform writes.
    table.clear(moveParts)
    table.clear(moveCFrames)
    for id,b in animated do
            local age=math.max(0,sim-b.birth)
            local position=b.position
            local y=1.1+math.max(0,1-age*2)*5
            local angle=b.angle
            if b.capture then
                local t=math.clamp((sim-b.capture)/Config.CaptureSeconds,0,1)
                local target,muzzle=magnetTarget(b.owner,b.target)
                local from=b.position+Vector3.new(0,1.1,0)
                local point=from:Lerp(target,t*t)+Vector3.new(0,math.sin(t*math.pi)*1.8,0)
                position=point
                y=point.Y
                angle+=t*4
                b.part.LocalTransparencyModifier=math.clamp((t-.8)*5,0,1)
                if not b.beam and muzzle and beamCount<18 then
                    b.pullAttachment=make("Attachment",{},b.part)
                    b.beam=make("Beam",{Attachment0=b.pullAttachment,Attachment1=muzzle,FaceCamera=true,
                        Width0=.06,Width1=.12,Segments=5,LightEmission=1,
                        Color=ColorSequence.new(cyan),Transparency=NumberSequence.new(.35)},b.part)
                    beamCount+=1
                end
            end
            table.insert(moveParts,b.part)
            table.insert(moveCFrames,CFrame.new(position.X,y,position.Z)*CFrame.Angles(0,angle,0))
            if not b.capture and age>=.5 then animated[id]=nil end
    end
    if #moveParts>0 then workspace:BulkMoveTo(moveParts,moveCFrames,Enum.BulkMoveMode.FireCFrameChanged) end
    hudAccumulator+=dt
    if hudAccumulator>=.1 then
        hudAccumulator=0
        activeText.Text=tostring(state:GetAttribute("Active") or 0).." บล็อก"
        pendingText.Text="คิว "..(state:GetAttribute("Pending") or 0).."  •  ดูดแล้ว "..(state:GetAttribute("Consumed") or 0)
        winText.Text="WIN "..(state:GetAttribute("Wins") or 0)
        local countdown=state:GetAttribute("ClearCountdown") or -1
        status.Text=frozen and string.format("แช่แข็ง  %.1f วิ",remain) or (countdown>=0 and "ลานสะอาดใน "..countdown.." วิ" or "กำลังดูดบล็อก")
        status.TextColor3=frozen and cyan or purple
    end
end)


