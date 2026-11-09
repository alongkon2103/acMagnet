local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local kit = RS:WaitForChild("BlackHole")
local Config = require(kit:WaitForChild("Config"))
local state = kit:WaitForChild("State")
local camera = workspace.CurrentCamera
local dark = Color3.fromRGB(242, 237, 225)
local white = Color3.fromRGB(54, 62, 51)
local cyan = Color3.fromRGB(69, 106, 87)
local purple = Color3.fromRGB(145, 96, 61)
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
        Font=Enum.Font.GothamMedium,TextColor3=color or white,Position=pos,Size=bounds,
        TextWrapped=true}, parent)
end
local gui = make("ScreenGui", {Name="BlackHoleHUD",ResetOnSpawn=false,IgnoreGuiInset=true}, player:WaitForChild("PlayerGui"))
local root = make("Frame", {BackgroundTransparency=1,Size=UDim2.fromScale(1,1)}, gui)
local Art=require(kit:WaitForChild("HUDArt"))
local score=Art.New("ImageLabel","score",{Name="CompactScore",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,12),Size=UDim2.fromOffset(280,57)},root)
local activeText=text(score,"0 บล็อก",18,UDim2.fromOffset(48,11),UDim2.fromOffset(146,32))
activeText.TextXAlignment=Enum.TextXAlignment.Left
local winText=text(score,"0",16,UDim2.fromOffset(220,9),UDim2.fromOffset(46,27),Color3.fromRGB(255,249,231))
winText.Font=Enum.Font.GothamBold;winText.TextStrokeColor3=Color3.fromRGB(104,65,35);winText.TextStrokeTransparency=.55
local status=text(root,"",14,UDim2.new(.5,-130,0,74),UDim2.fromOffset(260,24),cyan)
status.Name="ContextStatus";status.Visible=false
local toast=text(root,"",13,UDim2.new(.5,0,1,-78),UDim2.fromOffset(340,24))
toast.Name="GiftToast";toast.AnchorPoint=Vector2.new(.5,1);toast.TextWrapped=false;toast.TextTruncate=Enum.TextTruncate.AtEnd
local panel=make("Frame",{Name="GiftPopup",Visible=false,BackgroundColor3=dark,BackgroundTransparency=0,AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-76),Size=UDim2.fromOffset(300,88)},root)
round(panel,12)
text(panel,"ทดสอบของขวัญ",12,UDim2.fromOffset(12,4),UDim2.fromOffset(276,20),cyan)
local buttons={}
local canTest=false
local giftToggle=Art.New("ImageButton","gifts",{Name="GiftMenu",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-72,1,-16),Size=UDim2.fromOffset(44,46),Visible=false,AutoButtonColor=true},root)
if player:GetAttribute("MagnetPopup")==nil then player:SetAttribute("MagnetPopup","") end
local function refreshPopup()panel.Visible=canTest and player:GetAttribute("MagnetPopup")=="gifts" end
player:GetAttributeChangedSignal("MagnetPopup"):Connect(refreshPopup)
giftToggle.Activated:Connect(function()player:SetAttribute("MagnetPopup",panel.Visible and "" or "gifts")end)
local function sendGift(id)if canTest then kit.TestGift:FireServer(id) end end
for i,id in Config.Order do
    local gift=Config.Gifts[id]
    local b=make("TextButton",{Name=id,Text=gift.Name.."\n"..(gift.Blocks and "+"..gift.Blocks or "10 วิ"),TextSize=12,TextColor3=white,Font=Enum.Font.GothamMedium,AutoButtonColor=true,BackgroundColor3=Color3.fromRGB(227,229,215),Position=UDim2.fromOffset(12+(i-1)*72,28),Size=UDim2.fromOffset(66,48)},panel)
    round(b,8);b.Activated:Connect(function()sendGift(id)end);buttons[id]=b
end
local scoreScale=make("UIScale",{Scale=1},score)
local popupScale=make("UIScale",{Scale=1},panel)
local function resize()
    local width=camera.ViewportSize.X
    scoreScale.Scale=math.min(1,(width-32)/280)
    score.Position=UDim2.new(.5,0,0,width<600 and 56 or 12)
    status.Position=UDim2.new(.5,-130,0,width<600 and 116 or 74)
    popupScale.Scale=math.min(1,(width-32)/300)
    toast.Size=UDim2.fromOffset(math.min(340,width-32),24)
    camera.FieldOfView=Config.CameraFOV
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize);resize()
local keymap={[Enum.KeyCode.One]="Rose",[Enum.KeyCode.Two]="Roses",[Enum.KeyCode.Three]="Perfume",[Enum.KeyCode.Four]="Bear"}
UIS.InputBegan:Connect(function(input,processed)if not processed and keymap[input.KeyCode]then sendGift(keymap[input.KeyCode])end end)
local visuals = make("Folder",{Name="LocalGiftBlocks"},workspace)
local PixelPortrait=require(kit:WaitForChild("PixelPortrait"))
local Motion=require(kit:WaitForChild("BlockMotion"))
local roundedTemplate=kit:WaitForChild("RoundedBlock")
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
    for _,face in {Enum.NormalId.Bottom,Enum.NormalId.Front,Enum.NormalId.Back,Enum.NormalId.Left,Enum.NormalId.Right} do local side=surf:Clone();side.Face=face;side.Parent=part end
end
local function add(data)
    if blocks[data.id] or removed[data.id] then return end
    local capture=pendingCaptures[data.id]
    if capture then
        data.capture=capture.capture; data.owner=capture.owner; data.target=capture.target
        pendingCaptures[data.id]=nil
    end
    local templateId=tostring(math.floor(math.abs(data.sender.seed))%16+1)
    local template=roundedTemplate
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
    local tones={Color3.fromRGB(207,217,191),Color3.fromRGB(226,197,163),Color3.fromRGB(188,209,203),Color3.fromRGB(229,215,189)}
    p.Color=tones[math.floor(math.abs(data.sender.seed))%#tones+1]
    if not PixelPortrait.Apply(p,data.sender.avatarId) and not PixelPortrait.ApplyFallback(p,data.sender.seed) then
        for _,c in p:GetChildren() do if c:IsA("SurfaceGui") then c:Destroy() end end
        portrait(p,data.sender.seed)
    end
    local offset,rotation=Motion.Rest(math.max(0,(state:GetAttribute("Clock") or 0)-data.birth),data.angle,data.sender.seed)
    p.CFrame=CFrame.new(data.position+Vector3.new(0,1.1,0)+offset)*rotation
    p.LocalTransparencyModifier=0
    data.part=p
    data.baseSize=p.Size
    blocks[data.id]=data
    local sim=state:GetAttribute("Clock") or 0
    if data.capture or sim-data.birth<.9 then
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
        announce(payload.sender.name..(gift.Blocks and " +"..(gift.Blocks*payload.quantity) or " • หยุด "..(gift.Freeze*payload.quantity).." วิ"),cyan)
    elseif action=="Win" then announce("ลานสะอาด!  WIN "..payload,Color3.fromRGB(131,86,48)) end
end
kit.Event.OnClientEvent:Connect(received)
local initial = kit.Snapshot:InvokeServer()
canTest=initial.canTest
giftToggle.Visible=canTest
refreshPopup()
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
    if not frozen then
    for id,b in animated do
            local age=math.max(0,sim-b.birth)
            local position=b.position
            local offset,rotation,settled=Motion.Rest(age,b.angle,b.sender.seed)
            local pose=CFrame.new(position+Vector3.new(0,1.1,0)+offset)*rotation
            if b.capture then
                local t=math.clamp((sim-b.capture)/Config.CaptureSeconds,0,1)
                local target,muzzle=magnetTarget(b.owner,b.target)
                local shrink,fade
                pose,shrink,fade=Motion.Capture(b.position,target,math.max(0,b.capture-b.birth),t,b.angle,b.sender.seed)
                b.part.Size=b.baseSize*shrink
                b.part.LocalTransparencyModifier=fade
                if not b.beam and muzzle and beamCount<18 then
                    b.pullAttachment=make("Attachment",{},b.part)
                    b.beam=make("Beam",{Attachment0=b.pullAttachment,Attachment1=muzzle,FaceCamera=true,
                        Width0=.025,Width1=.07,Segments=5,LightEmission=1,
                        Color=ColorSequence.new(Color3.fromRGB(196,155,93)),Transparency=NumberSequence.new(.35)},b.part)
                    beamCount+=1
                end
            end
            table.insert(moveParts,b.part)
            table.insert(moveCFrames,pose)
            if not b.capture and settled then animated[id]=nil end
    end
    end
    PixelPortrait.UpdateVisibility(camera.CFrame.Position)
    if #moveParts>0 then workspace:BulkMoveTo(moveParts,moveCFrames,Enum.BulkMoveMode.FireCFrameChanged) end
    hudAccumulator+=dt
    if hudAccumulator>=.1 then
        hudAccumulator=0
        activeText.Text=tostring(state:GetAttribute("Active") or 0).." บล็อก"
        winText.Text=tostring(state:GetAttribute("Wins") or 0)
        local countdown=state:GetAttribute("ClearCountdown") or -1
        status.Visible=frozen or countdown>=0
        status.Text=frozen and string.format("แช่แข็ง  %.1f วิ",remain) or (countdown>=0 and "ลานสะอาดใน "..countdown.." วิ" or "กำลังดูดบล็อก")
        status.TextColor3=frozen and cyan or purple
    end
end)


