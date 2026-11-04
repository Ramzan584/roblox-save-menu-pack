-- Server ModuleScript. Ready state gates gameplay; failed loads never create playable defaults.
-- CC0-1.0 | timura032
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("SaveMenuPack"):WaitForChild("Config"))
assert(Config.AUTOSAVE_SECONDS >= 10 and Config.LEASE_SECONDS >= Config.AUTOSAVE_SECONDS * 3, "Keep lease >= 3x autosave interval")
local Schema = require(script.Parent.Schema)
local Repository = require(script.Parent.SaveRepository)
local memoryMode = RunService:IsStudio() and Config.STUDIO_MEMORY_PREVIEW
local store
if memoryMode then
    local records = {}
    store = {UpdateAsync = function(_, key, callback)
        local result = callback(records[key])
        if result ~= nil then records[key] = result end
        return result
    end}
else store = DataStoreService:GetDataStore(Config.STORE_NAME) end
local repo = Repository.new(store, Config, os.time, task.wait, function() return HttpService:GenerateGUID(false) end)
local Service = {Closing = false, MemoryMode = memoryMode}
local profiles = {}
local function status(player, profile, state)
    profile.status = state
    if player.Parent == Players then player:SetAttribute("SaveMenuStatus", state) end
end
local function dataNow(profile)
    local data = Schema.copy(profile.data)
    if profile.startedAt then data.PlaySeconds = profile.baseSeconds + math.floor(os.clock() - profile.startedAt) end
    return data
end
function Service.Snapshot(player)
    local p = profiles[player]
    local out = {Status = p and p.status or "LOADING", MemoryMode = memoryMode, Started = p and p.started or false}
    if p and p.ready then
        local data = dataNow(p)
        out.Data = data; out.HasProgress = data.Checkpoint > 0 or data.PlaySeconds > 0 or data.Coins > 0
        out.LastSavedAt = p.lastSavedAt; out.Dirty = p.dirty
    end
    return out
end
function Service.Load(player)
    if Service.Closing or player.Parent ~= Players then return end
    local previous = profiles[player]
    if previous and (previous.loading or previous.ready or previous.closing) then return end
    local p = {loading = true, ready = false, started = false, dirty = false, version = 0}
    profiles[player] = p
    status(player, p, "LOADING")
    p.token = previous and previous.token or HttpService:GenerateGUID(false)
    p.key = "Player_" .. player.UserId
    local record, reason = repo:acquire(p.key, p.token, os.clock() + 18)
    if not record then
        p.loading = false
        if p.closing or player.Parent ~= Players then profiles[player] = nil
        else status(player, p, reason or "LOAD_FAILED") end
        return
    end
    p.data = Schema.copy(record.Data); p.baseSeconds = p.data.PlaySeconds
    if p.closing or Service.Closing or player.Parent ~= Players then
        repo:save(p.key, p.token, p.data, true, os.clock() + 8)
        p.loading = false
        profiles[player] = nil
        return
    end
    p.loading = false
    p.ready = true
    player:SetAttribute("SaveMenuCheckpoint", p.data.Checkpoint)
    player:SetAttribute("SaveMenuCoins", p.data.Coins)
    status(player, p, "READY")
end
function Service.Start(player)
    local p = profiles[player]
    if not p or not p.ready or p.closing or Service.Closing then return false end
    if p.started then return true end
    p.started = true; p.startedAt = os.clock()
    player:SetAttribute("SaveMenuStarted", true)
    status(player, p, "PLAYING")
    return true
end
function Service.IsPlaying(player)
    local p = profiles[player]
    return p and p.ready and p.started and not p.closing and not Service.Closing
end
function Service.AdvanceCheckpoint(player, number)
    local p = profiles[player]
    if not Service.IsPlaying(player) or type(number) ~= "number" or number ~= p.data.Checkpoint + 1 or number > Config.MAX_CHECKPOINT then return false end
    p.data.Checkpoint = number; p.version = p.version + 1; p.dirty = true
    player:SetAttribute("SaveMenuCheckpoint", number)
    return true
end
function Service.AddCoins(player, amount)
    local p = profiles[player]
    if not Service.IsPlaying(player) or type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount % 1 ~= 0 then return false end
    p.data.Coins = math.min(Config.MAX_COINS, p.data.Coins + amount)
    p.version = p.version + 1; p.dirty = true
    player:SetAttribute("SaveMenuCoins", p.data.Coins)
    return true
end
function Service.SetSetting(player, name, value)
    local p = profiles[player]
    if not p or not p.ready or p.closing or Service.Closing then return false end
    if name == "MusicVolume" and type(value) == "number" and value == value and value >= 0 and value <= 1 then
        p.data.Settings.MusicVolume = value
    elseif name == "ReducedMotion" and type(value) == "boolean" then p.data.Settings.ReducedMotion = value
    else return false end
    p.version = p.version + 1; p.dirty = true
    return true
end
function Service.Save(player, release, deadline)
    local p = profiles[player]
    if not p or not p.ready then return false end
    if release then p.closing = true; status(player, p, "SAVING") end
    while p.busy do
        if deadline and os.clock() >= deadline then return false end
        task.wait(0.05)
    end
    if profiles[player] ~= p or not p.ready then return false end
    if p.closing and not release then return false end
    p.busy = true
    local version, snapshot = p.version, dataNow(p)
    local record, reason = repo:save(p.key, p.token, snapshot, release, deadline)
    p.busy = false
    if record then
        p.lastSavedAt = os.time()
        if version == p.version then p.dirty = false end
        if release then p.ready = false; profiles[player] = nil
        else status(player, p, p.started and "PLAYING" or "READY") end
        return true
    end
    if reason == "SESSION_LOST" or reason == "UNSUPPORTED_DATA" or reason == "INVALID_SESSION" then
        p.ready = false; p.started = false
        player:SetAttribute("SaveMenuStarted", false)
        status(player, p, "SESSION_LOST")
        if player.Parent == Players then player:Kick("Save session lost. Please rejoin / Сессия сохранения потеряна. Перезайди.") end
    else status(player, p, "SAVE_FAILED") end
    warn("SaveMenuPack save failed: " .. tostring(reason))
    return false
end
function Service.Remove(player)
    local p = profiles[player]
    if not p then return end
    p.closing = true
    if p.ready then Service.Save(player, true, os.clock() + 20)
    elseif not p.loading then profiles[player] = nil end
end
function Service.Shutdown()
    Service.Closing = true
    local deadline = os.clock() + 25
    local pending = 0
    for player, p in pairs(profiles) do
        p.closing = true
        if p.ready then
            pending = pending + 1
            task.spawn(function() Service.Save(player, true, deadline); pending = pending - 1 end)
        elseif p.loading then
            pending = pending + 1
            task.spawn(function()
                while p.loading and os.clock() < deadline do task.wait(0.05) end
                pending = pending - 1
            end)
        end
    end
    while pending > 0 and os.clock() < deadline do task.wait(0.05) end
end
return Service
