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
local score=make("Frame",{Name="CompactScore",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,12),Size=UDim2.fromOffset(260,122)},root)
local winCard=make("Frame",{Name="WinsCard",BackgroundTransparency=1,Size=UDim2.fromOffset(260,38)},score)
local winText=text(winCard,"0/10 WIN",27,UDim2.fromOffset(0,0),UDim2.fromOffset(260,38),Color3.fromRGB(255,255,255))
winText.Name="WinCount";winText.Font=Enum.Font.GothamBold
winText.TextStrokeTransparency=1
winText.TextScaled=true
make("UITextSizeConstraint",{MinTextSize=12,MaxTextSize=84},winText)
local winOutline=make("UIStroke",{Name="WinTextOutline",ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual,
    Color=Color3.fromRGB(28,35,29),Thickness=3,Transparency=0,LineJoinMode=Enum.LineJoinMode.Round},winText)
local function resizeWinOutline()
    winOutline.Thickness=math.clamp(winText.TextSize/14,2,6)
end
winText:GetPropertyChangedSignal("TextSize"):Connect(resizeWinOutline)
resizeWinOutline()
winCard.Parent=root
require(kit:WaitForChild("WinLayoutEditor")).Attach(winCard,winText,root)
local blockCard=make("Frame",{Name="BlocksCard",Position=UDim2.fromOffset(14,70),Size=UDim2.fromOffset(232,68),BackgroundColor3=Color3.fromRGB(250,248,237),BorderSizePixel=0},score)
round(blockCard,18)
make("UIStroke",{Color=Color3.fromRGB(255,252,231),Thickness=1.4,Transparency=.15},blockCard)
make("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(255,253,244),Color3.fromRGB(231,233,215)),Rotation=90},blockCard)
local iconBack=make("Frame",{Name="BlockIconBackground",Position=UDim2.fromOffset(12,11),Size=UDim2.fromOffset(46,46),BackgroundColor3=Color3.fromRGB(211,221,195),BorderSizePixel=0},blockCard)
round(iconBack,13)
local icon=make("ViewportFrame",{Name="BlockIcon",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Ambient=Color3.fromRGB(180,180,160),LightColor=Color3.fromRGB(255,245,212),LightDirection=Vector3.new(-1,-2,-1)},iconBack)
local cube=make("Part",{Name="Cube",Size=Vector3.new(2,2,2),Color=Color3.fromRGB(229,211,157),Material=Enum.Material.SmoothPlastic,Anchored=true},icon)
local iconCamera=make("Camera",{FieldOfView=35,CFrame=CFrame.lookAt(Vector3.new(4,3.2,5),Vector3.zero)},icon)
icon.CurrentCamera=iconCamera
local activeText=text(blockCard,"0",32,UDim2.fromOffset(70,6),UDim2.fromOffset(150,35),Color3.fromRGB(45,70,57))
activeText.Name="BlockCount";activeText.Font=Enum.Font.GothamBold;activeText.TextWrapped=false
activeText.TextXAlignment=Enum.TextXAlignment.Left
local pendingText=text(blockCard,"รอตกลงมา 0 บล็อก",12,UDim2.fromOffset(70,42),UDim2.fromOffset(150,18),Color3.fromRGB(110,119,91))
pendingText.Name="PendingCount";pendingText.TextWrapped=false;pendingText.TextXAlignment=Enum.TextXAlignment.Left
require(kit:WaitForChild("BlockHUDDrag")).Attach(blockCard,root)
local function countFormat(n)
    local result=tostring(math.floor(n))
    while true do local nextValue,count=result:gsub("^(-?%d+)(%d%d%d)","%1,%2");result=nextValue;if count==0 then break end end
    return result
end
local status=text(root,"",14,UDim2.new(.5,-130,0,74),UDim2.fromOffset(260,24),cyan)
status.Name="ContextStatus";status.Visible=false
local toast=text(root,"",13,UDim2.new(.5,0,1,-78),UDim2.fromOffset(340,24))
toast.Name="GiftToast";toast.AnchorPoint=Vector2.new(.5,1);toast.TextWrapped=false;toast.TextTruncate=Enum.TextTruncate.AtEnd
local panel=make("Frame",{Name="GiftPopup",Visible=false,BackgroundColor3=dark,BackgroundTransparency=0,AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-76),Size=UDim2.fromOffset(300,194)},root)
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
    local b=make("TextButton",{Name=id,Text=gift.Name.."\n"..(gift.Blocks and "+"..gift.Blocks or gift.ArenaExpandPercent and "30 เหรียญ\nฐาน +10%" or (gift.Coins.." เหรียญ\n"..gift.Freeze.." วิ")),TextSize=12,TextColor3=white,Font=Enum.Font.GothamMedium,AutoButtonColor=true,BackgroundColor3=Color3.fromRGB(227,229,215),Position=UDim2.fromOffset(12+((i-1)%3)*94,28+math.floor((i-1)/3)*56),Size=UDim2.fromOffset(88,48)},panel)
    round(b,8);b.Activated:Connect(function()sendGift(id)end);buttons[id]=b
end
-- Win controls share the existing operator-only gift menu.
local winRemote=kit:WaitForChild("AdjustWins")
local function winButton(name,caption,delta,x,color)
    local b=make("TextButton",{Name=name,Text=caption,Font=Enum.Font.GothamBold,TextSize=16,
        TextColor3=Color3.fromRGB(255,255,255),BackgroundColor3=color,BorderSizePixel=0,
        Position=UDim2.fromOffset(x,148),Size=UDim2.fromOffset(135,34),AutoButtonColor=true},panel)
    round(b,10)
    make("UIStroke",{Color=color:Lerp(Color3.new(0,0,0),.2),Thickness=1.2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},b)
    b.Activated:Connect(function()if canTest then winRemote:FireServer(delta)end end)
end
winButton("MinusWin","[X] −1 WIN",-1,12,Color3.fromRGB(192,74,80))
winButton("PlusWin","[Z] +1 WIN",1,153,Color3.fromRGB(58,151,108))
UIS.InputBegan:Connect(function(input,processed)
    if processed or UIS:GetFocusedTextBox() or not canTest then return end
    if input.KeyCode==Enum.KeyCode.Z then winRemote:FireServer(1)
    elseif input.KeyCode==Enum.KeyCode.X then winRemote:FireServer(-1) end
end)
local scoreScale=make("UIScale",{Scale=1},score)
local popupScale=make("UIScale",{Scale=1},panel)
local function resize()
    local width=camera.ViewportSize.X
    scoreScale.Scale=math.min(1,(width-32)/260)
    score.Position=UDim2.new(.5,0,0,width<600 and 56 or 12)
    status.Position=UDim2.new(.5,-130,0,width<600 and 206 or 162)
    popupScale.Scale=math.min(1,(width-32)/300)
    toast.Size=UDim2.fromOffset(math.min(340,width-32),24)
    camera.FieldOfView=Config.CameraFOV
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize);resize()
local keymap={[Enum.KeyCode.One]="Rose",[Enum.KeyCode.Two]="Roses",[Enum.KeyCode.Three]="Friendship",[Enum.KeyCode.Four]="Bear",[Enum.KeyCode.Five]="Donut"}
UIS.InputBegan:Connect(function(input,processed)if not processed and keymap[input.KeyCode]then sendGift(keymap[input.KeyCode])end end)
local visuals = make("Folder",{Name="LocalGiftBlocks"},workspace)
local PixelPortrait=require(kit:WaitForChild("PixelPortrait"))
local CaptureAudio=require(kit:WaitForChild("CaptureAudio"))
local Motion=require(kit:WaitForChild("BlockMotion"))
local Arena=require(kit:WaitForChild("ArenaMath"))
local BlockShadows=require(kit:WaitForChild("BlockShadows"))
local roundedTemplate=kit:WaitForChild("RoundedBlock")
local Gather=require(kit:WaitForChild("GatherMotion"))
local pendingGather={}
local blocks = {}
require(kit:WaitForChild("AutoPlay")).Attach(root,blocks)
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
    local surf = make("SurfaceGui",{Face=Enum.NormalId.Top,CanvasSize=Vector2.new(96,96),LightInfluence=0,MaxDistance=0,SizingMode=Enum.SurfaceGuiSizingMode.FixedSize},part)
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
    if pendingGather[data.id] then data.gather=pendingGather[data.id];pendingGather[data.id]=nil end
    local capture=pendingCaptures[data.id]
    if capture then
        data.capture=capture.capture; data.owner=capture.owner; data.target=capture.target; data.captureOrigin=capture.origin
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
    data.visualScale=math.clamp(tonumber(data.sender.blockScale) or 1,1,1.5)
    local originalHeight=p.Size.Y
    p.Size=p.Size*data.visualScale
    data.heightOffset=(p.Size.Y-originalHeight)/2
    p:SetAttribute("GiftBlockScale",data.visualScale)
    local tones={Color3.fromRGB(207,217,191),Color3.fromRGB(226,197,163),Color3.fromRGB(188,209,203),Color3.fromRGB(229,215,189)}
        p.Color=tones[math.floor(math.abs(data.sender.seed))%#tones+1]
    p.Material=Enum.Material.SmoothPlastic
    p.Reflectance=0
    p:SetAttribute("GachaTier",data.sender.gachaTier)
    if data.sender.gachaTier then
        local rarityColors={
            Common=Color3.fromRGB(191,230,192),Uncommon=Color3.fromRGB(75,204,134),
            Rare=Color3.fromRGB(75,188,244),Epic=Color3.fromRGB(173,103,231),
            Legendary=Color3.fromRGB(255,203,78)
        }
        p.Color=rarityColors[data.sender.gachaTier] or p.Color
        if data.sender.gachaTier=="Legendary" then p.Material=Enum.Material.Metal;p.Reflectance=.12 end
    end

    if not PixelPortrait.Apply(p,data.sender.avatarId) and not PixelPortrait.ApplyFallback(p,data.sender.seed) then
        for _,c in p:GetChildren() do if c:IsA("SurfaceGui") then c:Destroy() end end
        portrait(p,data.sender.seed)
    end
    local offset,rotation=Motion.Rest(math.max(0,(state:GetAttribute("Clock") or 0)-data.birth),data.angle,data.sender.seed)
    local scale=Arena.Read()
    local worldPosition=data.position*scale+Vector3.new(0,Arena.FloorOffset(scale),0)
    p.CFrame=CFrame.new(worldPosition+Vector3.new(0,1.1+data.heightOffset,0)+offset)*rotation
    p.LocalTransparencyModifier=0
    p.CastShadow=false
    data.part=p
    data.baseSize=p.Size
    blocks[data.id]=data
    local sim=state:GetAttribute("Clock") or 0
    if data.gather or data.capture or sim-data.birth<.9 then
        animated[data.id]=data
    else
        p.CFrame=CFrame.new(worldPosition+Vector3.new(0,1.1+data.heightOffset,0))*CFrame.Angles(0,data.angle,0)
    end
    data.shadow=BlockShadows.Acquire()
    data.shadow.CFrame=BlockShadows.Place(data.shadow,p.CFrame,scale,1,0,data.visualScale)
end
local toastVersion = 0
local function displayName(sender)
 local names=kit:FindFirstChild("LiveNames")
 local value=names and sender.nameId and names:FindFirstChild(sender.nameId)
 return value and value.Value or sender.name
end
local function announce(message,color)
    toastVersion += 1
    local version=toastVersion
    toast.Text=message
    toast.TextColor3=color or white
    task.delay(4,function() if toastVersion==version then toast.Text="" end end)
end
local EraseFX=require(kit:WaitForChild("BlockEraseFX"))
local function received(action,payload)
    if action=="Add" then for _,b in payload do table.insert(pendingVisuals,b) end
    elseif action=="Gather" then
        for _,job in payload do
            local b=blocks[job.id]
            if b then b.gather=job.gather;animated[b.id]=b
            elseif not removed[job.id] then pendingGather[job.id]=job.gather end
        end
    elseif action=="Captures" or action=="Capture" then
        for _,capture in (action=="Captures" and payload or {payload}) do
            local b=blocks[capture.id]
            if b then b.capture=capture.capture; b.owner=capture.owner; b.target=capture.target; b.captureOrigin=capture.origin; animated[b.id]=b
            elseif not removed[capture.id] then pendingCaptures[capture.id]=capture end
        end
    elseif action=="Remove" or action=="Erase" then
    local ids=action=="Erase" and payload.ids or payload
    if action=="Erase" then
        for index,id in ids do local block=blocks[id];if block then EraseFX.Play(block.part,index) end end
        if payload.userId==player.UserId then EraseFX.Notify(#ids) end
    end
    for _,id in ids do
        removed[id]=true
        pendingCaptures[id]=nil
        pendingGather[id]=nil
        animated[id]=nil
        local b=blocks[id]
        if b then
            if b.owner==player.UserId then CaptureAudio.Play() end
            releaseBeam(b)
            PixelPortrait.Clear(b.part)
            BlockShadows.Release(b.shadow)
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
        if gift.ArenaExpandPercent then
            announce(displayName(payload.sender).." • โดนัท ขยายฐาน "..math.floor((payload.arenaPercent or 200)+.5).."%",gift.Color)
        else
            announce(displayName(payload.sender)..(gift.Blocks and " +"..(gift.Blocks*payload.quantity) or " • หยุด "..(gift.Freeze*payload.quantity).." วิ"),cyan)
        end
    elseif action=="Win" then toast.Text="" end
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
local zoomMin,zoomMax=.5,2.5
local zoomCurrent,zoomTarget=1,1
local function setZoom(value)
    zoomTarget=math.clamp(value,zoomMin,zoomMax)
    player:SetAttribute("CameraZoomTarget",zoomTarget)
end
setZoom(1)
UIS.InputChanged:Connect(function(input,processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.UserInputType==Enum.UserInputType.MouseWheel then
        setZoom(zoomTarget*math.exp(-input.Position.Z*.12))
    end
end)
local pinchStart=1
UIS.TouchPinch:Connect(function(_,scale,_,inputState,processed)
    if processed then return end
    if inputState==Enum.UserInputState.Begin then
        pinchStart=zoomTarget
    elseif inputState==Enum.UserInputState.Change and scale>0 then
        setZoom(pinchStart/scale)
    end
end)
player:GetAttributeChangedSignal("CameraZoomTarget"):Connect(function()
    local value=player:GetAttribute("CameraZoomTarget")
    if type(value)=="number" and value==value then
        zoomTarget=math.clamp(value,zoomMin,zoomMax)
    end
end)

local WinAdjustmentCinematic=require(kit:WaitForChild("WinAdjustmentCinematic"))
local ExpansionCinematic=require(kit:WaitForChild("ExpansionCinematic"))
local BearPourCinematic=require(kit:WaitForChild("BearPourCinematic"))
RunService:BindToRenderStep("MagnetFollowCamera",Enum.RenderPriority.Camera.Value+1,function(dt)
    local character=player.Character
    local rootPart=character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    camera=workspace.CurrentCamera
    camera.CameraType=Enum.CameraType.Scriptable
    local focus=Vector3.new(rootPart.Position.X,2,rootPart.Position.Z)
    zoomCurrent+=(zoomTarget-zoomCurrent)*(1-math.exp(-14*dt))
    local follow=CFrame.lookAt(focus+Config.CameraOffset*zoomCurrent,focus)
    local frame,cinematicFocus=BearPourCinematic.Update(follow,focus,camera)
    if not frame then
        frame,cinematicFocus=ExpansionCinematic.Update(follow,focus,camera)
    else
        local expansionGui=player.PlayerGui:FindFirstChild("ArenaExpansionCinematic")
        if expansionGui then expansionGui.Enabled=false end
    end
    local winFrame,winFocus=WinAdjustmentCinematic.Update(follow,focus,camera)
    if winFrame then
        frame=winFrame;cinematicFocus=winFocus
        local expansionGui=player.PlayerGui:FindFirstChild("ArenaExpansionCinematic")
        if expansionGui then expansionGui.Enabled=false end
    end
    camera.CFrame=frame
    camera.Focus=CFrame.new(cinematicFocus)
end)
local previousArenaScale=Arena.Read()
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
    local arenaScale=Arena.Read(now)
    local arenaMoving=math.abs(arenaScale-previousArenaScale)>.00001
    previousArenaScale=arenaScale
    if arenaMoving then for id,b in blocks do if not b.capture then animated[id]=b end end end
    local sim=(state:GetAttribute("Clock") or 0)+math.clamp(now-(state:GetAttribute("SyncedAt") or now),0,.3)
    -- Animate only spawning/captured blocks, at the display's render rate.
    -- Settled blocks require no per-frame iteration or transform writes.
    table.clear(moveParts)
    table.clear(moveCFrames)
    do -- World blocks keep animating while players are frozen.
    for id,b in animated do
            local age=math.max(0,sim-b.birth)
            local canonical,gathering=Gather.Position(b,sim)
            if b.gather and not gathering then b.position=b.gather.to;b.gather=nil;canonical=b.position end
            local position=canonical*arenaScale+Vector3.new(0,Arena.FloorOffset(arenaScale),0)
            local offset,rotation,settled=Motion.Rest(age,b.angle,b.sender.seed)
            local pose=CFrame.new(position+Vector3.new(0,1.1+(b.heightOffset or 0),0)+offset)*rotation
            if b.gather then
                pose=CFrame.new(position+Vector3.new(0,1.1+(b.heightOffset or 0),0))*CFrame.Angles(sim*2+b.angle,sim*5+b.angle,sim+b.angle)
            end

            local shadowShrink,shadowFade=1,0
            if b.capture then
                local t=math.clamp((sim-b.capture)/Config.CaptureSeconds,0,1)
                local target,muzzle=magnetTarget(b.owner,b.target)
                local shrink,fade
                pose,shrink,fade=Motion.Capture(b.captureOrigin or position,target,math.max(0,b.capture-b.birth),t,b.angle,b.sender.seed)
                pose+=Vector3.new(0,(b.heightOffset or 0)*(1-t),0)
                b.part.Size=b.baseSize*shrink
                b.part.LocalTransparencyModifier=fade
                shadowShrink,shadowFade=shrink,fade
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
            table.insert(moveParts,b.shadow)
            table.insert(moveCFrames,BlockShadows.Place(b.shadow,pose,arenaScale,shadowShrink,shadowFade,b.visualScale))
            if not b.gather and not b.capture and settled and not arenaMoving then animated[id]=nil end
    end
    end
    PixelPortrait.UpdateVisibility(camera.CFrame.Position)
    if #moveParts>0 then workspace:BulkMoveTo(moveParts,moveCFrames,Enum.BulkMoveMode.FireCFrameChanged) end
    hudAccumulator+=dt
    if hudAccumulator>=.1 then
        hudAccumulator=0
        local active=math.max(0,state:GetAttribute("Active") or 0)
        local pending=math.max(0,state:GetAttribute("Pending") or 0)
        activeText.Text=countFormat(active+pending)
        pendingText.Text="รอตกลงมา "..countFormat(pending).." บล็อก"
        blockCard:SetAttribute("Active",active)
        blockCard:SetAttribute("Pending",pending)
        blockCard:SetAttribute("TotalRemaining",active+pending)

        local winValue=player:GetAttribute("Wins") or 0
        local winColor=winValue<0 and "rgb(255,74,86)" or (winValue>0 and "rgb(74,235,124)" or "rgb(255,255,255)")
        winText.RichText=true
        winText.TextColor3=Color3.new(1,1,1)
        winText.Text='<font color="'..winColor..'">'..countFormat(winValue)..'</font><font color="rgb(255,255,255)">/'..countFormat(player:GetAttribute("WinTarget") or 10)..' WIN</font>'
        local winOutline=winCard:FindFirstChild("EditOutline")
        if winOutline then winOutline.Color=Color3.fromRGB(220,246,232) end

        status.Visible=false
        status.Text=""
        status.TextColor3=frozen and cyan or purple
    end
end)


