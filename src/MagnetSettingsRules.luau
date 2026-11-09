local Rules={}
function Rules.Normalize(value,minimum,maximum)
    if type(value)~="number" or value~=value or math.abs(value)==math.huge then return nil end
    return math.clamp(math.floor(value+.5),minimum,maximum)
end
function Rules.CanChange(isStudio,isCreator,isPrivateOwner,isListed)
    return isStudio or isCreator or isPrivateOwner or isListed
end
return Rules
