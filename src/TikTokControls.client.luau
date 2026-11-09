local Players=game:GetService("Players")
local player=Players.LocalPlayer
local kit=game:GetService("ReplicatedStorage"):WaitForChild("BlackHole")
local state=kit:WaitForChild("LiveState")
local control=kit:WaitForChild("LiveControl")
local Art=require(kit:WaitForChild("HUDArt"))
local gui=Instance.new("ScreenGui");gui.Name="TikTokConnect";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.Parent=player:WaitForChild("PlayerGui")
local toggle=Art.New("ImageButton","menu",{Name="LiveMenu",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-16),Size=UDim2.fromOffset(44,46),Visible=false,AutoButtonColor=true},gui)
local dot=Instance.new("Frame");dot.Name="LiveDot";dot.BorderSizePixel=0;dot.Size=UDim2.fromOffset(7,7);dot.Position=UDim2.new(1,-9,0,3);dot.Parent=toggle
local dotCorner=Instance.new("UICorner");dotCorner.CornerRadius=UDim.new(1,0);dotCorner.Parent=dot
local panel=Instance.new("Frame");panel.Name="Frame";panel.Visible=false;panel.BackgroundColor3=Color3.fromRGB(242,237,225);panel.BorderSizePixel=0
panel.AnchorPoint=Vector2.new(1,1);panel.Position=UDim2.new(1,-16,1,-76);panel.Size=UDim2.fromOffset(280,134);panel.Parent=gui
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,12);corner.Parent=panel
local function label(text,y,size)
    local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=text;l.Font=Enum.Font.GothamMedium;l.TextSize=size or 12
    l.TextColor3=Color3.fromRGB(54,62,51);l.TextXAlignment=Enum.TextXAlignment.Left;l.Position=UDim2.fromOffset(12,y);l.Size=UDim2.fromOffset(256,24);l.Parent=panel;return l
end
label("TikTok LIVE",8,14)
local close=Instance.new("TextButton");close.Name="Close";close.Text="×";close.TextSize=20;close.BackgroundTransparency=1;close.Size=UDim2.fromOffset(28,28);close.Position=UDim2.new(1,-34,0,6);close.Parent=panel
local input=Instance.new("TextBox");input.Name="TextBox";input.PlaceholderText="@ชื่อช่อง";input.Text="";input.ClearTextOnFocus=false
input.Font=Enum.Font.Gotham;input.TextSize=14;input.TextColor3=Color3.fromRGB(54,62,51);input.BackgroundColor3=Color3.fromRGB(225,226,213);input.BorderSizePixel=0
input.Position=UDim2.fromOffset(12,42);input.Size=UDim2.fromOffset(160,32);input.Parent=panel
local inputCorner=Instance.new("UICorner");inputCorner.CornerRadius=UDim.new(0,6);inputCorner.Parent=input
local button=Instance.new("TextButton");button.Name="TextButton";button.Text="เชื่อมต่อ";button.Font=Enum.Font.GothamMedium;button.TextSize=12;button.BorderSizePixel=0
button.BackgroundColor3=Color3.fromRGB(111,144,113);button.TextColor3=Color3.fromRGB(255,253,241);button.Position=UDim2.fromOffset(180,42);button.Size=UDim2.fromOffset(88,32);button.Parent=panel
local buttonCorner=Instance.new("UICorner");buttonCorner.CornerRadius=UDim.new(0,6);buttonCorner.Parent=button
local current=label("ยังไม่เชื่อมต่อ",88)
local names={DISCONNECTED="ยังไม่เชื่อมต่อ",CONNECTING="กำลังเชื่อมต่อ…",LIVE="เชื่อมต่อแล้ว",DRAINING="กำลังรับรายการท้ายไลฟ์…",RETRYING="กำลังเชื่อมต่อใหม่…",OFFLINE="จบ LIVE แล้ว",ERROR="เชื่อมต่อไม่ได้",SETUP_REQUIRED="ยังไม่ได้ตั้งค่า Backend",INVALID_USERNAME="ชื่อช่องไม่ถูกต้อง",BACKPRESSURE="กำลังรอคิว"}
local active=false
local function refresh()
    local allowed=player:GetAttribute("CanControlTikTok")==true
    toggle.Visible=allowed
    panel.Visible=allowed and player:GetAttribute("MagnetPopup")=="live"
    local s=state:GetAttribute("Status") or "DISCONNECTED"
    active=s=="LIVE" or s=="CONNECTING" or s=="RETRYING" or s=="BACKPRESSURE" or s=="DRAINING"
    button.Text=active and "หยุดเชื่อม" or "เชื่อมต่อ"
    dot.BackgroundColor3=s=="LIVE" and Color3.fromRGB(73,132,87) or (s=="ERROR" and Color3.fromRGB(168,90,65) or Color3.fromRGB(173,174,154))
    current.Text=s=="SIGNING_REQUIRED" and "ตรวจการตั้งค่า signing provider" or names[s] or s
    local dropped=state:GetAttribute("Dropped") or 0
    if dropped>0 then current.Text..=" • สูญหาย "..dropped end
end
toggle.Activated:Connect(function()player:SetAttribute("MagnetPopup",panel.Visible and "" or "live")end)
close.Activated:Connect(function()player:SetAttribute("MagnetPopup","")end)
button.Activated:Connect(function()
    control:FireServer(active and "disconnect" or "connect",input.Text)
    player:SetAttribute("MagnetPopup","")
end)
state.AttributeChanged:Connect(refresh)
player:GetAttributeChangedSignal("CanControlTikTok"):Connect(refresh)
player:GetAttributeChangedSignal("MagnetPopup"):Connect(refresh)
local scale=Instance.new("UIScale");scale.Parent=panel
local camera=workspace.CurrentCamera
local function resize()scale.Scale=math.min(1,(camera.ViewportSize.X-32)/280)end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize);resize();refresh()
