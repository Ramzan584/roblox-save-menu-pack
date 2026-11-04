-- One autosave worker per player, staggered to avoid synchronized requests. CC0-1.0
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("SaveMenuPack").Config)
local Service = require(script.Parent.ProfileService)
local workers = {}
local function start(player)
    if workers[player] then return end
    workers[player] = true
    task.spawn(function()
        task.wait(5 + player.UserId % 20)
        while player.Parent == Players and not Service.Closing do
            Service.Save(player, false, os.clock() + 15) -- Also renews session lease while in menu.
            task.wait(Config.AUTOSAVE_SECONDS)
        end
        workers[player] = nil
    end)
end
Players.PlayerAdded:Connect(start)
for _, player in ipairs(Players:GetPlayers()) do start(player) end
