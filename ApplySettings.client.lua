-- Put your own permitted music Sounds in SoundGroup SaveMenuMusic. No assets included.
-- CC0-1.0 | timura032
local SoundService = game:GetService("SoundService")
local player = game:GetService("Players").LocalPlayer
local changed = player:WaitForChild("PlayerGui"):WaitForChild("SaveMenuSnapshot", 30)
if not changed then warn("SaveMenuPack: MainMenu client missing"); return end
local group = SoundService:FindFirstChild("SaveMenuMusic")
if not group then group = Instance.new("SoundGroup"); group.Name = "SaveMenuMusic"; group.Parent = SoundService end
assert(group:IsA("SoundGroup"), "SoundService.SaveMenuMusic must be SoundGroup")
changed.Event:Connect(function(snapshot)
    if snapshot.Data then
        group.Volume = snapshot.Data.Settings.MusicVolume
        player:SetAttribute("SaveMenuReducedMotion", snapshot.Data.Settings.ReducedMotion)
    end
end)
