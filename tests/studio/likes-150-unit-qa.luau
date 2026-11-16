-- Read-only Studio MCP Edit/Server command: fresh counter instances, no real rewards.
local Counter=assert(loadstring(game.ServerScriptService.LikeRewardCounter.Source))()
local Config=assert(loadstring(game.ReplicatedStorage.BlackHole.Config.Source))()
local counter=Counter.new(Config.LikesPerReward)
local units=0
local function grant(n)units+=n;return true end
assert(counter:Process({id="a149",rawLikeCount=149},grant))
assert(units==0 and counter.remainder==149)
assert(counter:Process({id="b1",rawLikeCount=1},grant))
assert(units*Config.Gifts.Likes.Blocks==10,"149+1 likes must grant exactly10 blocks")
assert(counter:Process({id="b1",rawLikeCount=1},grant))
assert(units==1,"Replayed like packet granted again")
assert(counter:Process({id="burst",rawLikeCount=320},grant))
assert(units==3 and counter.remainder==20)
assert(counter:Process({id="carry",rawLikeCount=130},grant))
assert(units==4 and counter.remainder==0)
local retry=Counter.new(150)
local granted,blocked,ids=0,true,{}
local function limited(n,id)
 if blocked and id:sub(-2)==":2"then return false,"queue_full"end
 assert(not ids[id],"Accepted chunk was replayed")
 ids[id]=true;granted+=n;return true
end
local e={id="large",rawLikeCount=15150}
local ok,reason=retry:Process(e,limited)
assert(not ok and reason=="queue_full" and granted==100)
blocked=false;assert(retry:Process(e,limited));assert(granted==101)
local fresh=Counter.new(150)
local wrong=0;assert(fresh:Process({id="legacy",quantity=999},function(n)wrong+=n;return true end))
assert(wrong==0 and fresh.status=="RAW_COUNT_MISSING","Reward quantities must not be treated as raw likes")
return game.HttpService:JSONEncode({passed=true,threshold=Config.LikesPerReward,blocksPerReward=Config.Gifts.Likes.Blocks,remainder=counter.remainder,blocksGranted=units*Config.Gifts.Likes.Blocks,retryRewards=granted})
