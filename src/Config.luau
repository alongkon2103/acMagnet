return {
    Gifts = {
        Rose = {GiftId = 5655, Name = "กุหลาบ", Coins = 1, Blocks = 10, Color = Color3.fromRGB(255, 88, 142)},
        Roses = {GiftId = 8913, Name = "โรซ่า", Coins = 10, Blocks = 100, Color = Color3.fromRGB(177, 112, 255)},
        Perfume = {GiftId = 5658, Name = "น้ำหอม", Coins = 20, Freeze = 10, Color = Color3.fromRGB(73, 219, 255)},
        Bear = {GiftId = 5566, Name = "อุ้มใจหมี", Coins = 100, Blocks = 1000, Color = Color3.fromRGB(255, 193, 94)},
    },
    Order = {"Rose", "Roses", "Perfume", "Bear"},
    MaxActive = 1600,
    MaxPending = 50000,
    SpawnPerSecond = 100,
    InitialBlocks = 500,
    ClearSeconds = 10,
    PlayerSpeed = 22,
    PullRadius = 9,
    CaptureSeconds = 0.6,
    CameraOffset = Vector3.new(0, 32, 25),
    CameraFOV = 55,
    CameraFollowSpeed = 12,
    -- Test controls are automatically enabled in Studio only.
    -- Add operator Roblox user IDs here to enable them in a private live game.
    OperatorUserIds = {},
}

