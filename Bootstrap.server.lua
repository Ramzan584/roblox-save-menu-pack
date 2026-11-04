-- Script -> ServerScriptService.SaveMenuPack. CC0-1.0 | timura032
local Players = game:GetService("Players")
local Service = require(script.Parent.ProfileService)
local function added(player)
    player:SetAttribute("SaveMenuStarted", false)
    task.spawn(Service.Load, player)
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(Service.Remove)
for _, player in ipairs(Players:GetPlayers()) do added(player) end
game:BindToClose(Service.Shutdown)
