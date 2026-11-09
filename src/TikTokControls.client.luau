local Players=game:GetService("Players")
local player=Players.LocalPlayer
local kit=game:GetService("ReplicatedStorage"):WaitForChild("BlackHole")
local state=kit:WaitForChild("LiveState")
local control=kit:WaitForChild("LiveControl")
local gui=Instance.new("ScreenGui");gui.Name="TikTokConnect";gui.ResetOnSpawn=false;gui.Parent=player:WaitForChild("PlayerGui")
local panel=Instance.new("Frame");panel.BackgroundColor3=Color3.fromRGB(242,237,225);panel.Position=UDim2.fromOffset(16,16);panel.Size=UDim2.fromOffset(280,138);panel.Parent=gui
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=panel
local function label(text,y)
    local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=text;l.Font=Enum.Font.Gotham;l.TextSize=13;l.TextColor3=Color3.fromRGB(54,62,51);l.TextXAlignment=Enum.TextXAlignment.Left;l.Position=UDim2.fromOffset(12,y);l.Size=UDim2.fromOffset(256,24);l.Parent=panel;return l
end
label("TikTok LIVE",4)
label("กดใจครบ 50 ครั้ง = 10 บล็อก",102)
local input=Instance.new("TextBox");input.PlaceholderText="@ชื่อช่อง TikTok";input.Text="";input.ClearTextOnFocus=false;input.Font=Enum.Font.Gotham;input.TextSize=14;input.TextColor3=Color3.fromRGB(54,62,51);input.BackgroundColor3=Color3.fromRGB(225,226,213);input.Position=UDim2.fromOffset(12,34);input.Size=UDim2.fromOffset(160,30);input.Parent=panel
local button=Instance.new("TextButton");button.Text="Connect";button.Font=Enum.Font.GothamMedium;button.TextSize=12;button.BackgroundColor3=Color3.fromRGB(111,144,113);button.Position=UDim2.fromOffset(180,34);button.Size=UDim2.fromOffset(88,30);button.Parent=panel
local current=label("ยังไม่เชื่อมต่อ",72)
local names={DISCONNECTED="ยังไม่เชื่อมต่อ",CONNECTING="กำลังเชื่อมต่อ…",LIVE="เชื่อมต่อ LIVE แล้ว",DRAINING="กำลังรับของขวัญท้ายไลฟ์…",RETRYING="กำลังเชื่อมต่อใหม่…",OFFLINE="ช่องจบ LIVE แล้ว",ERROR="เชื่อมต่อไม่ได้ กรุณาลองใหม่",SETUP_REQUIRED="ยังไม่ได้ตั้งค่า Backend",INVALID_USERNAME="ชื่อช่องไม่ถูกต้อง",BACKPRESSURE="คิวบล็อกเต็ม กำลังรอ"}
local function refresh()
    local allowed=player:GetAttribute("CanControlTikTok")==true
    input.Visible=allowed;button.Visible=allowed
    local s=state:GetAttribute("Status") or "DISCONNECTED"
    local active=s=="LIVE" or s=="CONNECTING" or s=="RETRYING" or s=="BACKPRESSURE" or s=="DRAINING"
    button.Text=active and "Disconnect" or "Connect"
    current.Text=s=="SIGNING_REQUIRED" and "ต้องตั้งค่า TikTok signing provider" or names[s] or s
    local dropped=state:GetAttribute("Dropped") or 0
    if dropped>0 then current.Text..=" • สูญหาย "..dropped end
end
button.Activated:Connect(function()
    control:FireServer(button.Text=="Disconnect" and "disconnect" or "connect",input.Text)
end)
state.AttributeChanged:Connect(refresh);player:GetAttributeChangedSignal("CanControlTikTok"):Connect(refresh);refresh()
