-- Optional server example. Workspace.SaveMenuDemo.Coins holds BaseParts. CC0-1.0
local Players = game:GetService("Players")
local Service = require(script.Parent.ProfileService)
local demo = workspace:WaitForChild("SaveMenuDemo", 15)
local coins = demo and demo:WaitForChild("Coins", 15)
assert(coins, "Create SaveMenuDemo.Coins or remove this optional example Script")
local connected = setmetatable({}, {__mode = "k"})
local function install(coin)
    if connected[coin] or not coin:IsA("BasePart") then return end
    connected[coin] = true
    local busy, transparency = false, coin.Transparency
    coin.CanCollide = false
    coin.Touched:Connect(function(hit)
        if busy then return end
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not player or not root or not humanoid or humanoid.Health <= 0 then return end
        if (root.Position - coin.Position).Magnitude > coin.Size.Magnitude / 2 + 8 then return end
        if not Service.AddCoins(player, 1) then return end
        busy = true; coin.Transparency = 1
        task.wait(10)
        if coin.Parent then coin.Transparency = transparency end
        busy = false
    end)
end
for _, coin in ipairs(coins:GetChildren()) do install(coin) end
coins.ChildAdded:Connect(install)
