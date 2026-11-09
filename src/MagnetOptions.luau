local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local kit=game.ReplicatedStorage.BlackHole
local Config=require(kit.Config)
local state=kit.State
local remote=kit:WaitForChild("MagnetSettings")
local Options={}
local function make(class,props,parent)
    local v=Instance.new(class);for k,value in props do v[k]=value end;v.Parent=parent;return v
end
local function round(v,r)make("UICorner",{CornerRadius=UDim.new(0,r)},v)end
function Options.Create(panel)
    local root=make("Frame",{Name="MagnetOptions",BackgroundTransparency=1,Position=UDim2.fromOffset(12,80),Size=UDim2.fromOffset(256,150)},panel)
    local function text(str,x,y,w)
        return make("TextLabel",{Text=str,BackgroundTransparency=1,TextSize=12,Font=Enum.Font.GothamMedium,TextColor3=Color3.fromRGB(54,62,51),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,24)},root)
    end
    text("ระยะดูด",0,0,160)
    local valueText=text("",172,0,84);valueText.TextXAlignment=Enum.TextXAlignment.Right
    local hit=make("TextButton",{Name="RadiusSlider",Text="",BackgroundTransparency=1,Position=UDim2.fromOffset(0,24),Size=UDim2.fromOffset(256,32),AutoButtonColor=false},root)
    local track=make("Frame",{Name="Track",BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(205,211,191),Position=UDim2.fromOffset(9,14),Size=UDim2.new(1,-18,0,5)},hit);round(track,3)
    local fill=make("Frame",{Name="Fill",BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(108,140,108),Size=UDim2.fromScale(0,1)},track);round(fill,3)
    local knob=make("Frame",{Name="Knob",BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(246,241,223),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),Size=UDim2.fromOffset(18,18)},track);round(knob,9)
    make("UIStroke",{Color=Color3.fromRGB(157,117,78),Thickness=1},knob)
    local reset=make("TextButton",{Name="ResetRadius",Text="ค่าเดิม",TextSize=11,Font=Enum.Font.GothamMedium,TextColor3=Color3.fromRGB(119,91,62),BackgroundTransparency=1,Position=UDim2.fromOffset(176,52),Size=UDim2.fromOffset(80,26)},root)
    local dragging=nil
    local current=state:GetAttribute("PullRadius") or Config.PullRadius
    local lastSent,pending,scheduled=-1,nil,false
    local function allowed()return player:GetAttribute("CanControlTikTok")==true end
    local knobTween,fillTween
    local function draw(value,animate)
        if knobTween then knobTween:Cancel()end
        if fillTween then fillTween:Cancel()end
        current=value;valueText.Text=tostring(value).." studs"
        local fraction=(value-Config.MinPullRadius)/(Config.MaxPullRadius-Config.MinPullRadius)
        if animate then
            knobTween=TweenService:Create(knob,TweenInfo.new(.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.fromScale(fraction,.5)});knobTween:Play()
            fillTween=TweenService:Create(fill,TweenInfo.new(.12),{Size=UDim2.fromScale(fraction,1)});fillTween:Play()
        else knob.Position=UDim2.fromScale(fraction,.5);fill.Size=UDim2.fromScale(fraction,1)end
    end
    local function queue(value)
        pending=value
        if scheduled then return end
        scheduled=true
        task.delay(math.max(0,.12-(os.clock()-lastSent)),function()
            scheduled=false;local value=pending;pending=nil;lastSent=os.clock()
            if value and allowed() then remote:FireServer(value) end
        end)
    end
    local function preview(value)
        if not allowed() then return end
        value=math.clamp(math.floor(value+.5),Config.MinPullRadius,Config.MaxPullRadius)
        draw(value,false);player:SetAttribute("MagnetRadiusPreview",value);queue(value)
    end
    local function position(x)
        local fraction=math.clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        preview(Config.MinPullRadius+fraction*(Config.MaxPullRadius-Config.MinPullRadius))
    end
    local function finish()
        dragging=nil
        local value=current
        task.delay(.4,function()
            if not dragging and player:GetAttribute("MagnetRadiusPreview")==value then
                player:SetAttribute("MagnetRadiusPreview",nil);draw(state:GetAttribute("PullRadius") or Config.PullRadius,true)
            end
        end)
    end
    hit.InputBegan:Connect(function(input)
        if not allowed() then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=input;position(input.Position.X)end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input==dragging or dragging.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)then position(input.Position.X)end
    end)
    UIS.InputEnded:Connect(function(input)if dragging and (input==dragging or input.UserInputType==Enum.UserInputType.MouseButton1)then finish()end end)
    UIS.WindowFocusReleased:Connect(function()if dragging then finish()end end)
    player:GetAttributeChangedSignal("MagnetPopup"):Connect(function()if player:GetAttribute("MagnetPopup")~="live" and dragging then finish()end end)
    reset.Activated:Connect(function()if allowed()then preview(Config.PullRadius);finish()end end)
    state:GetAttributeChangedSignal("PullRadius"):Connect(function()if not dragging and player:GetAttribute("MagnetRadiusPreview")==nil then draw(state:GetAttribute("PullRadius"),true)end end)
    local function switch(name,title,attribute,y,default)
        if player:GetAttribute(attribute)==nil then player:SetAttribute(attribute,default)end
        text(title,0,y,180)
        local button=make("TextButton",{Name=name,Text="",BackgroundTransparency=1,Position=UDim2.fromOffset(208,y-3),Size=UDim2.fromOffset(48,32)},root)
        local bg=make("Frame",{BorderSizePixel=0,Position=UDim2.fromOffset(4,5),Size=UDim2.fromOffset(40,22)},button);round(bg,11)
        local thumb=make("Frame",{BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(252,247,232),Position=UDim2.fromOffset(3,3),Size=UDim2.fromOffset(16,16)},bg);round(thumb,8)
        local function refresh()
            local on=player:GetAttribute(attribute)==true
            TweenService:Create(bg,TweenInfo.new(.16),{BackgroundColor3=on and Color3.fromRGB(111,144,113)or Color3.fromRGB(194,199,182)}):Play()
            TweenService:Create(thumb,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(on and 21 or 3,3)}):Play()
        end
        button.Activated:Connect(function()player:SetAttribute(attribute,not player:GetAttribute(attribute))end)
        player:GetAttributeChangedSignal(attribute):Connect(refresh);refresh()
    end
    switch("RingToggle","แสดงวงระยะ","MagnetRingEnabled",82,false)
    switch("SoundToggle","เสียงเก็บบล็อก","MagnetSoundEnabled",118,true)
    local result={Root=root,StopDrag=finish}
    function result.Refresh()
        reset.Visible=allowed();hit.Active=allowed()
        fill.BackgroundColor3=allowed()and Color3.fromRGB(108,140,108)or Color3.fromRGB(166,174,154)
    end
    player:GetAttributeChangedSignal("CanControlTikTok"):Connect(result.Refresh)
    draw(current,false);result.Refresh()
    return result
end
return Options
