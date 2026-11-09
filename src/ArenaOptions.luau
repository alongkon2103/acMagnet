local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local kit=game.ReplicatedStorage.BlackHole
local Config=require(kit.Config)
local Arena=require(kit:WaitForChild("ArenaMath"))
local remote=kit:WaitForChild("ArenaSettings")
local Options={}
local function make(class,props,parent)
    local v=Instance.new(class);for k,value in props do v[k]=value end;v.Parent=parent;return v
end
local function round(v,r)make("UICorner",{CornerRadius=UDim.new(0,r)},v)end
function Options.Create(root)
    local function text(str,x,w)
        return make("TextLabel",{Text=str,BackgroundTransparency=1,TextSize=12,Font=Enum.Font.GothamMedium,TextColor3=Color3.fromRGB(54,62,51),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(x,0),Size=UDim2.fromOffset(w,24)},root)
    end
    text("ขนาดสนาม",0,160)
    local valueText=text("",172,84);valueText.TextXAlignment=Enum.TextXAlignment.Right
    local hit=make("TextButton",{Name="ArenaSlider",Text="",BackgroundTransparency=1,Position=UDim2.fromOffset(0,24),Size=UDim2.fromOffset(256,32),AutoButtonColor=false},root)
    local track=make("Frame",{Name="Track",BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(205,211,191),Position=UDim2.fromOffset(9,14),Size=UDim2.new(1,-18,0,5)},hit);round(track,3)
    local fill=make("Frame",{Name="Fill",BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(108,140,108),Size=UDim2.fromScale(0,1)},track);round(fill,3)
    local knob=make("Frame",{Name="Knob",BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(246,241,223),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),Size=UDim2.fromOffset(18,18)},track);round(knob,9)
    make("UIStroke",{Color=Color3.fromRGB(157,117,78),Thickness=1},knob)
    local reset=make("TextButton",{Name="ResetArena",Text="ขนาดเริ่มต้น",TextSize=11,Font=Enum.Font.GothamMedium,TextColor3=Color3.fromRGB(119,91,62),BackgroundTransparency=1,Position=UDim2.fromOffset(154,52),Size=UDim2.fromOffset(102,26)},root)
    local dragging,knobTween,fillTween
    local lastSent,pending,scheduled=-1,nil,false
    local function allowed()return player:GetAttribute("CanControlTikTok")==true end
    local function draw(value,animate)
        if knobTween then knobTween:Cancel()end;if fillTween then fillTween:Cancel()end
        valueText.Text=tostring(value).."%"
        local fraction=(value-Config.MinArenaPercent)/(Config.MaxArenaPercent-Config.MinArenaPercent)
        if animate then
            knobTween=TweenService:Create(knob,TweenInfo.new(.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.fromScale(fraction,.5)});knobTween:Play()
            fillTween=TweenService:Create(fill,TweenInfo.new(.12),{Size=UDim2.fromScale(fraction,1)});fillTween:Play()
        else knob.Position=UDim2.fromScale(fraction,.5);fill.Size=UDim2.fromScale(fraction,1)end
    end
    local function sync()
        if not dragging then local _,target=Arena.Read();draw(math.floor(target*100+.5),true)end
    end
    local function queue(value)
        pending=value
        if scheduled then return end
        scheduled=true
        task.delay(math.max(0,.12-(os.clock()-lastSent)),function()
            scheduled=false;local value=pending;pending=nil;lastSent=os.clock()
            if value and allowed()then remote:FireServer(value)end
        end)
    end
    local function preview(value)
        if not allowed()then return end
        value=Arena.NormalizePercent(value);draw(value,false);queue(value)
    end
    local function position(x)
        local fraction=math.clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        preview(Config.MinArenaPercent+fraction*(Config.MaxArenaPercent-Config.MinArenaPercent))
    end
    local function finish()dragging=nil;task.delay(.4,sync)end
    hit.InputBegan:Connect(function(input)
        if allowed()and(input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch)then dragging=input;position(input.Position.X)end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and(input==dragging or dragging.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)then position(input.Position.X)end
    end)
    UIS.InputEnded:Connect(function(input)
        if dragging and(input==dragging or dragging.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)then finish()end
    end)
    UIS.WindowFocusReleased:Connect(function()if dragging then finish()end end)
    player:GetAttributeChangedSignal("MagnetPopup"):Connect(function()if player:GetAttribute("MagnetPopup")~="live"and dragging then finish()end end)
    reset.Activated:Connect(function()if allowed()then preview(Config.DefaultArenaPercent);finish()end end)
    kit.State:GetAttributeChangedSignal("ArenaTransition"):Connect(sync)
    local function refresh()
        reset.Visible=allowed();hit.Active=allowed()
        fill.BackgroundColor3=allowed()and Color3.fromRGB(108,140,108)or Color3.fromRGB(166,174,154)
        if not allowed()and dragging then finish()end
    end
    player:GetAttributeChangedSignal("CanControlTikTok"):Connect(refresh)
    sync();refresh()
    return {StopDrag=finish}
end
return Options
