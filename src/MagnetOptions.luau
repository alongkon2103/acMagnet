local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local Options={}
local function make(class,props,parent)
    local v=Instance.new(class);for k,value in props do v[k]=value end;v.Parent=parent;return v
end
local function round(v,r)make("UICorner",{CornerRadius=UDim.new(0,r)},v)end
function Options.Create(panel)
    local root=make("Frame",{Name="MagnetOptions",BackgroundTransparency=1,Position=UDim2.fromOffset(12,80),Size=UDim2.fromOffset(256,68)},panel)
    local function text(str,x,y,w)
        return make("TextLabel",{Text=str,BackgroundTransparency=1,TextSize=12,Font=Enum.Font.GothamMedium,TextColor3=Color3.fromRGB(54,62,51),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,24)},root)
    end
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
    switch("RingToggle","แสดงวงระยะ","MagnetRingEnabled",0,false)
    switch("SoundToggle","เสียงเก็บบล็อก","MagnetSoundEnabled",36,true)
    return {Root=root}
end
return Options
