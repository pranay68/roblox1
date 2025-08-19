-- Zone2Content.lua
-- Implements reveal mechanic and shard spawning for Lensveil. Place in Workspace under Zone2 folder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zone2 = workspace:FindFirstChild("Zone2")
if not Zone2 then
    Zone2 = Instance.new("Folder") Zone2.Name = "Zone2" Zone2.Parent = workspace
end

-- Reveal ability (client-friendly): we provide a RemoteEvent to validate usage server-side if needed
local revealEvent = ReplicatedStorage:FindFirstChild("RevealEvent")
if not revealEvent then
    revealEvent = Instance.new("RemoteEvent") revealEvent.Name = "RevealEvent" revealEvent.Parent = ReplicatedStorage
end

-- Shard spawn positions (tweak in Studio)
local ShardPositions = {
    Vector3.new(10,3,132),
    Vector3.new(-8,3,136),
    Vector3.new(16,3,140),
}

local function spawnShards()
    for i,pos in ipairs(ShardPositions) do
        local shard = Instance.new("Part")
        shard.Name = "LightShard"
        shard.Size = Vector3.new(1,1,1)
        shard.Position = pos
        shard.Anchored = true
        shard.BrickColor = BrickColor.new("Bright yellow")
        shard.Parent = Zone2
        onShardTouched(shard)
    end
end

spawnShards()

-- server-side respond to reveal usage (we can extend validation here)
revealEvent.OnServerEvent:Connect(function(player)
    -- validation and metrics
    if not player or not player:IsA("Player") then return end
    pcall(function()
        local Metrics = require(game:GetService("ServerScriptService"):FindFirstChild("Metrics"))
        Metrics:Increment("reveal_used")
    end)
end)

-- wiring: when shard touched by player, award and destroy
local function onShardTouched(shard)
    shard.Touched:Connect(function(hit)
        local pl = Players:GetPlayerFromCharacter(hit.Parent)
        if pl then
            -- server-side verification: ensure the touch came from player's character Hrp within small distance
            local char = pl.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local dist = (char.HumanoidRootPart.Position - shard.Position).Magnitude
                if dist > 6 then return end
            end
            local prog = pl:FindFirstChild("Zone2Shards")
            if not prog then prog = Instance.new("IntValue") prog.Name = "Zone2Shards" prog.Value = 0 prog.Parent = pl end
            prog.Value = prog.Value + 1
            pcall(function() shard:Destroy() end)
            -- if collected all shards, spawn bridge
            if prog.Value >= #ShardPositions then
                if not Zone2:FindFirstChild("LightBridge") then
                    local bridge = Instance.new("Part") bridge.Name = "LightBridge" bridge.Size = Vector3.new(12,1,4) bridge.Position = Vector3.new(0,3,150) bridge.Anchored = true bridge.BrickColor = BrickColor.new("Institutional white") bridge.Parent = Zone2
                end
            end
        end
    end)
end

for _,p in ipairs(Zone2:GetChildren()) do
    if p.Name:sub(1,9) == "LightShard" then
        onShardTouched(p)
    end
end


