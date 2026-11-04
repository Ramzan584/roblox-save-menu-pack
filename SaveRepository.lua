-- Server ModuleScript. Atomic lease + idempotent saves. CC0-1.0 | timura032
local Schema = require(script.Parent.Schema)
local Repository = {}
Repository.__index = Repository
-- Dependencies are injected so the same logic can be tested without real DataStores.
function Repository.new(store, config, clock, pause, guid)
    return setmetatable({store = store, config = config, clock = clock, pause = pause, guid = guid}, Repository)
end
function Repository:update(key, transform, deadline)
    for attempt = 1, self.config.RETRY_COUNT do
        if deadline and os.clock() >= deadline then return nil, "DEADLINE" end
        local reason
        local ok, record = pcall(function()
            return self.store:UpdateAsync(key, function(current)
                -- Roblox may invoke this callback multiple times. No yields or side effects here.
                local nextRecord, rejected = transform(current)
                reason = rejected
                return nextRecord
            end)
        end)
        if ok then
            if record == nil then return nil, reason or "CANCELLED" end
            return record
        end
        if attempt < self.config.RETRY_COUNT then
            local delay = math.min(2 ^ (attempt - 1), 4)
            if deadline and os.clock() + delay >= deadline then return nil, "DEADLINE" end
            self.pause(delay)
        end
    end
    return nil, "DATASTORE_UNAVAILABLE"
end
function Repository:acquire(key, token, deadline)
    return self:update(key, function(current)
        local data, invalid = Schema.decode(current)
        if not data then return nil, invalid end
        local now = self.clock()
        local lock = current and current.Session
        if lock and lock.Id ~= token and lock.Expires > now then return nil, "SESSION_LOCKED" end
        return {
            SchemaVersion = Schema.VERSION,
            Revision = current and current.Revision or 0,
            Data = data,
            Session = {Id = token, Expires = now + self.config.LEASE_SECONDS},
            WriteId = current and current.WriteId or nil,
        }
    end, deadline)
end
function Repository:save(key, token, data, release, deadline)
    local operation = self.guid() -- One ID across all retries of this logical write.
    local frozen = Schema.copy(data)
    return self:update(key, function(current)
        local decoded, invalid = Schema.decode(current)
        if not decoded or current == nil then return nil, invalid or "SESSION_LOST" end
        -- A write may have committed even if its network response failed.
        if current.WriteId == operation then return current end
        if not current.Session or current.Session.Id ~= token then return nil, "SESSION_LOST" end
        return {
            SchemaVersion = Schema.VERSION,
            Revision = (current.Revision or 0) + 1,
            Data = frozen,
            Session = not release and {Id = token, Expires = self.clock() + self.config.LEASE_SECONDS} or nil,
            WriteId = operation,
        }
    end, deadline)
end
return Repository
