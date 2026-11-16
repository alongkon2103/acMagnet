-- Studio Server command in a fresh Play. Verify credits, active-cap behavior and quick control events.
local kit=game.ReplicatedStorage.BlackHole
local state=kit.State
local gateway=game.ServerScriptService.BlackHoleServer:WaitForChild("SubmitGift")
local function credits()return (state:GetAttribute("Active")or 0)+(state:GetAttribute("Pending")or 0)+(state:GetAttribute("Consumed")or 0)end
local before=credits()
local owner=game.Players:GetPlayers()[1]
local id="p"..string.rep("a",32)
local value=Instance.new("StringValue");value.Name=id;value.Value=game.HttpService:JSONEncode(table.create(1024,0x6688aa));value.Parent=kit.LivePortraits
local sender={name="Burst QA",seed=888,avatarId=id}
local prefix="burst-"..os.clock()
local started=os.clock()
assert(gateway:Invoke("Rose",sender,100,prefix.."rose",owner.UserId))
assert(gateway:Invoke("Bear",sender,2,prefix.."bear",owner.UserId))
local control=os.clock()
assert(gateway:Invoke("Friendship",sender,1,prefix.."freeze",owner.UserId))
local controlMs=(os.clock()-control)*1000
assert(credits()-before==4000,"Accepted gift block credits were truncated")
local count=credits()
local ok,reason=gateway:Invoke("Bear",sender,2,prefix.."bear",owner.UserId)
assert(not ok and reason=="duplicate" and credits()==count)
assert(state:GetAttribute("FreezeUntil")>workspace:GetServerTimeNow())
return game.HttpService:JSONEncode({passed=true,acceptedBlocks=4000,intakeMs=(os.clock()-started)*1000,controlMs=controlMs,credits=credits(),active=state:GetAttribute("Active"),pending=state:GetAttribute("Pending")})
