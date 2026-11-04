-- Workspace.SaveMenuDemo.Checkpoints: BaseParts named 0,1,2,..., each with CanTouch=true.
-- Server validates stage order and proximity. CC0-1.0 | timura032
local Players = game:GetService("Players")
local Service = require(script.Parent.ProfileService)
local demo = workspace:WaitForChild("SaveMenuDemo", 15)
assert(demo, "Install demo objects or create Workspace.SaveMenuDemo")
local checkpoints = demo:WaitForChild("Checkpoints", 15)
assert(checkpoints, "Create SaveMenuDemo.Checkpoints with numbered Parts")
local roots, installedPlayers = {}, {}
local function moveToCheckpoint(player, root)
    local number = player:GetAttribute("SaveMenuCheckpoint") or 0
    local pad = checkpoints:FindFirstChild(tostring(number)) or checkpoints:FindFirstChild("0")
    if pad and pad:IsA("BasePart") then
        player.Character:PivotTo(pad.CFrame + Vector3.new(0, pad.Size.Y / 2 + 4, 0))
        root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
    end
end
local function setup(player)
    if installedPlayers[player] then return end
    installedPlayers[player] = true
    local function characterAdded(character)
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if not root or player.Character ~= character then return end
        roots[player] = {root = root, anchored = root.Anchored}
        if Service.IsPlaying(player) then moveToCheckpoint(player, root)
        else root.Anchored = true end
    end
    player.CharacterAdded:Connect(characterAdded)
    player:GetAttributeChangedSignal("SaveMenuStarted"):Connect(function()
        local entry = roots[player]
        if not entry or not entry.root.Parent then return end
        if Service.IsPlaying(player) then
            moveToCheckpoint(player, entry.root)
            entry.root.Anchored = entry.anchored
        else entry.root.Anchored = true end
    end)
    if player.Character then task.spawn(characterAdded, player.Character) end
end
local connected = setmetatable({}, {__mode = "k"})
local function install(pad)
    if connected[pad] or not pad:IsA("BasePart") then return end
    local number = tonumber(pad.Name)
    if not number or number < 1 or number % 1 ~= 0 then return end
    connected[pad] = true
    pad.Touched:Connect(function(hit)
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not player or not root or not humanoid or humanoid.Health <= 0 then return end
        if (root.Position - pad.Position).Magnitude > pad.Size.Magnitude / 2 + 8 then return end
        Service.AdvanceCheckpoint(player, number)
    end)
end
for _, pad in ipairs(checkpoints:GetChildren()) do install(pad) end
checkpoints.ChildAdded:Connect(install)
Players.PlayerAdded:Connect(setup)
Players.PlayerRemoving:Connect(function(player) roots[player] = nil; installedPlayers[player] = nil end)
for _, player in ipairs(Players:GetPlayers()) do setup(player) end
