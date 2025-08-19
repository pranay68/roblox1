-- Zone2Quest.lua
-- Small quest: collect 3 Light Shards in Zone2. Place this in Workspace under Zone2 folder.

local Zone2 = workspace:FindFirstChild("Zone2")
if not Zone2 then
    Zone2 = Instance.new("Folder") Zone2.Name = "Zone2" Zone2.Parent = workspace
end

local ShardPositions = {
    Vector3.new(8,3,128),
    Vector3.new(-6,3,132),
    Vector3.new(14,3,136),
}

local shards = {}
for i,pos in ipairs(ShardPositions) do
    local p = Instance.new("Part") p.Name = "LightShard"..i p.Size = Vector3.new(1,1,1) p.Position = pos p.Anchored = true p.BrickColor = BrickColor.new("Bright yellow") p.Parent = Zone2
    shards[i] = p
end

local Players = game:GetService("Players")

local function giveShard(player, shard)
    local inv = player:FindFirstChild("PlayerGui")
    -- mark progress on player as IntValue
    local prog = player:FindFirstChild("Zone2Shards")
    if not prog then prog = Instance.new("IntValue") prog.Name = "Zone2Shards" prog.Value = 0 prog.Parent = player end
    prog.Value = prog.Value + 1
    shard:Destroy()
    if prog.Value >= #ShardPositions then
        -- quest complete - reward: small heal or particle
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid").Health = math.min(char:FindFirstChildOfClass("Humanoid").MaxHealth, char:FindFirstChildOfClass("Humanoid").Health + 20)
        end
    end
end

-- detect touch
for _,shard in ipairs(shards) do
    shard.Touched:Connect(function(hit)
        local pl = game.Players:GetPlayerFromCharacter(hit.Parent)
        if pl then
            giveShard(pl, shard)
        end
    end)
end


