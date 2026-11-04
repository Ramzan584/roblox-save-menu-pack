-- Server ModuleScript. CC0-1.0 | timura032
local Schema = {}
Schema.VERSION = 1
local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function integer(value, default, maximum)
    if not finite(value) then return default end
    return math.max(0, math.min(maximum, math.floor(value)))
end
function Schema.defaults()
    return {Checkpoint = 0, Coins = 0, PlaySeconds = 0, Settings = {MusicVolume = 0.5, ReducedMotion = false}}
end
function Schema.copy(data)
    local settings = type(data.Settings) == "table" and data.Settings or {}
    return {
        Checkpoint = integer(data.Checkpoint, 0, 100000),
        Coins = integer(data.Coins, 0, 1000000000),
        PlaySeconds = integer(data.PlaySeconds, 0, 10000000000),
        Settings = {
            MusicVolume = finite(settings.MusicVolume) and math.max(0, math.min(1, settings.MusicVolume)) or 0.5,
            ReducedMotion = settings.ReducedMotion == true,
        },
    }
end
function Schema.decode(record)
    if record == nil then return Schema.defaults() end
    if type(record) ~= "table" or record.SchemaVersion ~= Schema.VERSION or type(record.Data) ~= "table" then
        return nil, "UNSUPPORTED_DATA" -- Never replace unreadable/newer records with defaults.
    end
    if record.Session ~= nil then
        if type(record.Session) ~= "table" or type(record.Session.Id) ~= "string" or not finite(record.Session.Expires) then
            return nil, "INVALID_SESSION"
        end
    end
    if record.Revision ~= nil and (not finite(record.Revision) or record.Revision < 0) then return nil, "INVALID_REVISION" end
    return Schema.copy(record.Data)
end
return Schema
