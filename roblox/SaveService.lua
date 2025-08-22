-- SaveService.lua
-- Place in ServerScriptService. Saves and loads player progression (HasSpark, ReflectionChoice)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local STORE = DataStoreService:GetDataStore("IgnisiaPlayerData_v1")
local SAVE_KEY_PREFIX = "player_"

-- Metrics and failure tracking
local Metrics = nil
pcall(function()
    Metrics = require(game:GetService("ServerScriptService"):FindFirstChild("Metrics") or nil)
end)

local failureCounts = {}
local pendingWrites = {}

local function getKey(userId)
    return SAVE_KEY_PREFIX .. tostring(userId)
end

local function retryAsync(func, key, maxRetries)
    maxRetries = maxRetries or 5
    local baseDelay = 0.15
    for attempt = 1, maxRetries do
        local ok, result = pcall(func)
        if ok then
            return true, result
        else
            local waitTime = baseDelay * (2 ^ (attempt - 1))
            waitTime = waitTime + (math.random() * 0.1)
            warn(string.format("SaveService: attempt %d failed for %s, retrying in %.2fs", attempt, tostring(key), waitTime))
            -- use task.wait for more accurate scheduling where available
            if task and task.wait then
                task.wait(waitTime)
            else
                wait(waitTime)
            end
        end
    end
    return false, "max retries exceeded"
end

local function getAsyncWithRetry(key)
    local ok, res = retryAsync(function() return STORE:GetAsync(key) end, key)
    if ok then return res end
    return nil
end

local function setAsyncWithRetry(key, value)
    -- use UpdateAsync to merge payload atomically with existing data
    local ok, res = retryAsync(function()
        return STORE:UpdateAsync(key, function(old)
            local merged = old or {}
            -- copy values from value into merged
            for k,v in pairs(value or {}) do merged[k] = v end
            return merged
        end)
    end, key)
    return ok, res
end

local function loadPlayerData(player)
    local key = getKey(player.UserId)
    local data = getAsyncWithRetry(key)
    return data
end

local function savePlayerData(player)
    local key = getKey(player.UserId)
    local payload = {}
    local has = player:FindFirstChild("HasSpark")
    if has and has.Value then payload.HasSpark = true end
    local refl = player:FindFirstChild("ReflectionChoice")
    if refl and refl.Value and tostring(refl.Value) ~= "" then payload.ReflectionChoice = tostring(refl.Value) end
    local shards = player:FindFirstChild("Zone2Shards")
    if shards and type(shards.Value) == "number" and shards.Value > 0 then
        payload.Zone2Shards = shards.Value
    end
    local mirror = player:FindFirstChild("MirrorSolved")
    if mirror and mirror.Value == true then
        payload.MirrorSolved = true
    end
    local tv = player:FindFirstChild("Trait_Vision")
    if tv and tv.Value == true then
        payload.Trait_Vision = true
    end
    -- Queue saves to avoid bursty writes: add to pending and let flush loop handle retries
    pendingWrites[key] = payload
end

-- pending write queue and flush loop
local FLUSH_INTERVAL = 4 -- seconds
local function flushPendingWrites()
    for key, payload in pairs(pendingWrites) do
        local ok, err = setAsyncWithRetry(key, payload)
        if ok then
            pendingWrites[key] = nil
            failureCounts[key] = 0
        else
            warn("SaveService: failed to flush", key, err)
            failureCounts[key] = (failureCounts[key] or 0) + 1
            if failureCounts[key] >= 3 and Metrics then
                pcall(function() Metrics:Increment("save_failures") end)
                warn("SaveService: repeated failures for", key)
            end
        end
        -- throttle between writes a little to be safe
        if task and task.wait then task.wait(0.15) else wait(0.15) end
    end
end

spawn(function()
    while true do
        if next(pendingWrites) then
            flushPendingWrites()
        end
        if task and task.wait then task.wait(FLUSH_INTERVAL) else wait(FLUSH_INTERVAL) end
    end
end)


Players.PlayerAdded:Connect(function(player)
    spawn(function()
        local data = loadPlayerData(player)
        if data then
            if data.HasSpark then
                local v = Instance.new("BoolValue") v.Name = "HasSpark" v.Value = true v.Parent = player
            end
            if data.ReflectionChoice then
                local s = Instance.new("StringValue") s.Name = "ReflectionChoice" s.Value = tostring(data.ReflectionChoice) s.Parent = player
            end
            if data.Zone2Shards and tonumber(data.Zone2Shards) then
                local iv = Instance.new("IntValue") iv.Name = "Zone2Shards" iv.Value = tonumber(data.Zone2Shards) or 0 iv.Parent = player
            end
            if data.MirrorSolved then
                local bv = Instance.new("BoolValue") bv.Name = "MirrorSolved" bv.Value = true bv.Parent = player
            end
            if data.Trait_Vision then
                local tv = Instance.new("BoolValue") tv.Name = "Trait_Vision" tv.Value = true tv.Parent = player
            end
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    spawn(function()
        savePlayerData(player)
    end)
end)

-- Expose manual save function for other server scripts
local SaveService = {}
function SaveService:SavePlayer(player)
    savePlayerData(player)
end

return SaveService


