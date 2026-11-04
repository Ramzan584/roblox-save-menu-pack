-- Remote API: clients cannot set checkpoint, coins, playtime, datastore key or session token.
-- CC0-1.0 | timura032
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("SaveMenuPack")
local Config = require(shared.Config)
local Service = require(script.Parent.ProfileService)
assert(not shared:FindFirstChild("Request"), "Install only one RemoteBridge")
local request = Instance.new("RemoteFunction")
request.Name = "Request"; request.Parent = shared
local gates = {}
request.OnServerInvoke = function(player, action, name, value)
    local gate = gates[player]
    if not gate then gate = {nextRequest = 0, nextSave = 0, nextLoad = 0}; gates[player] = gate end
    local now = os.clock()
    if type(action) ~= "string" or #action > 20 or now < gate.nextRequest then
        local result = Service.Snapshot(player); result.Message = "RATE_LIMIT"; return result
    end
    gate.nextRequest = now + 0.2
    if action == "Status" then return Service.Snapshot(player) end
    if gate.busy then local result = Service.Snapshot(player); result.Message = "BUSY"; return result end
    gate.busy = true
    local message
    local ok = pcall(function()
        if action == "Play" then
            if not Service.Start(player) then message = "NOT_READY" end
        elseif action == "RetryLoad" then
            if now < gate.nextLoad then message = "RATE_LIMIT"; return end
            gate.nextLoad = now + 8
            Service.Load(player)
        elseif action == "Save" then
            if now < gate.nextSave then message = "SAVE_COOLDOWN"; return end
            gate.nextSave = now + Config.MANUAL_SAVE_COOLDOWN
            if not Service.Save(player, false, os.clock() + 15) then message = "SAVE_FAILED" end
        elseif action == "Setting" then
            if type(name) ~= "string" or #name > 30 or not Service.SetSetting(player, name, value) then message = "INVALID_SETTING" end
        else message = "UNKNOWN_ACTION" end
    end)
    gate.busy = false
    if not ok then message = "SERVER_ERROR"; warn("SaveMenuPack request failed") end
    local result = Service.Snapshot(player)
    result.Message = message
    return result
end
Players.PlayerRemoving:Connect(function(player) gates[player] = nil end)
