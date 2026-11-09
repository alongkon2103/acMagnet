local SoundService=game:GetService("SoundService")
local Config=require(game.ReplicatedStorage.BlackHole.Config)
local Audio={}
local voices={}
for i=1,4 do
    local sound=Instance.new("Sound");sound.Name="MagnetCapture"..i
    sound.SoundId=Config.CaptureSoundId;sound.Volume=Config.CaptureSoundVolume;sound.Parent=SoundService
    table.insert(voices,sound)
end
local last,index,step=-1,0,0
function Audio.Play()
    if game.Players.LocalPlayer:GetAttribute("MagnetSoundEnabled")==false then return end
    local now=os.clock()
    if now-last<.075 then return end
    if now-last>.45 then step=0 else step=(step+1)%5 end
    last=now;index=index%#voices+1
    local voice=voices[index]
    voice:Stop();voice.PlaybackSpeed=({.92,1,1.06,1.12,1.19})[step+1]
    voice.Volume=Config.CaptureSoundVolume;voice:Play()
end
return Audio
