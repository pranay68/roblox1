-- Zone2Content.lua
-- Implements reveal mechanic and shard spawning for Lensveil. Place in Workspace under Zone2 folder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Zone2 = workspace:FindFirstChild("Zone2")
if not Zone2 then
    Zone2 = Instance.new("Folder") Zone2.Name = "Zone2" Zone2.Parent = workspace
end

-- Reveal ability (client-friendly): we provide a RemoteEvent to validate usage server-side if needed
local revealEvent = ReplicatedStorage:FindFirstChild("RevealEvent")
if not revealEvent then
    revealEvent = Instance.new("RemoteEvent") revealEvent.Name = "RevealEvent" revealEvent.Parent = ReplicatedStorage
end
local dialogEvent = ReplicatedStorage:FindFirstChild("DialogEvent")
if not dialogEvent then
    dialogEvent = Instance.new("RemoteEvent") dialogEvent.Name = "DialogEvent" dialogEvent.Parent = ReplicatedStorage
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
local revealCooldowns = {}
local REVEAL_COOLDOWN = 3.0

revealEvent.OnServerEvent:Connect(function(player)
    -- validation and metrics
    if not player or not player:IsA("Player") then return end
    local now = tick()
    local last = revealCooldowns[player.UserId] or -100
    if (now - last) < REVEAL_COOLDOWN then
        pcall(function()
            local Metrics = require(game:GetService("ServerScriptService"):FindFirstChild("Metrics"))
            Metrics:Increment("reveal_rate_limited")
        end)
        return
    end
    revealCooldowns[player.UserId] = now
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
            -- persist
            pcall(function()
                local SaveService = require(game:GetService("ServerScriptService"):FindFirstChild("SaveService"))
                if SaveService and SaveService.SavePlayer then SaveService:SavePlayer(pl) end
            end)
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

-- Illusions and Mirror Grove (simple implementation)
-- We spawn a few invisible path pieces and add a Mirror puzzle with one correct mirror.

local function createIllusion(name, size, cframe)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1 -- invisible by default; client reveal can show via LocalTransparencyModifier
    part.Color = Color3.fromRGB(255, 255, 255)
    part.Parent = Zone2
    pcall(function() CollectionService:AddTag(part, "Illusion") end)
    return part
end

local function ensureIllusions()
    if Zone2:FindFirstChild("IllusionPath1") then return end
    createIllusion("IllusionPath1", Vector3.new(4,1,16), CFrame.new(4, 3, 146))
    createIllusion("IllusionPath2", Vector3.new(4,1,16), CFrame.new(-4, 3, 146))
    createIllusion("IllusionStep", Vector3.new(2,1,2), CFrame.new(0, 4, 142))
end

local function ensureMirrorGrove()
    local grove = Zone2:FindFirstChild("MirrorGrove")
    if grove then return end
    grove = Instance.new("Folder")
    grove.Name = "MirrorGrove"
    grove.Parent = Zone2

    local positions = {
        CFrame.new(-12, 3, 126),
        CFrame.new(-8, 3, 126),
        CFrame.new(-4, 3, 126),
        CFrame.new(0, 3, 126),
    }
    local realIndex = 3 -- choose the third mirror as the real one
    for i,cf in ipairs(positions) do
        local mirror = Instance.new("Part")
        mirror.Name = "Mirror"..tostring(i)
        mirror.Size = Vector3.new(3,5,1)
        mirror.CFrame = cf
        mirror.Anchored = true
        mirror.BrickColor = BrickColor.new("Really black")
        mirror.Reflectance = 0.4
        mirror.Parent = grove

        -- tag illusions so reveal glow can hint which is real: add tag only to real mirror frame
        if i == realIndex then pcall(function() CollectionService:AddTag(mirror, "IllusionHint") end) end

        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = "Inspect"
        prompt.ObjectText = "Mirror"
        prompt.HoldDuration = 0.4
        prompt.MaxActivationDistance = 8
        prompt.Parent = mirror

        prompt.Triggered:Connect(function(player)
            if not player or not player:IsA("Player") then return end
            if i == realIndex then
                -- reward small heal + message once; mark completion on player
                local flag = player:FindFirstChild("MirrorSolved")
                if not flag then
                    flag = Instance.new("BoolValue")
                    flag.Name = "MirrorSolved"
                    flag.Value = true
                    flag.Parent = player
                    pcall(function()
                        local SaveService = require(game:GetService("ServerScriptService"):FindFirstChild("SaveService"))
                        if SaveService and SaveService.SavePlayer then SaveService:SavePlayer(player) end
                    end)
                    local char = player.Character
                    if char then
                        local h = char:FindFirstChildOfClass("Humanoid")
                        if h then h.Health = math.min(h.MaxHealth, h.Health + 15) end
                    end
                    -- optional: increment metrics
                    pcall(function()
                        local Metrics = require(game:GetService("ServerScriptService"):FindFirstChild("Metrics"))
                        Metrics:Increment("mirror_solved")
                    end)
                end
            else
                -- incorrect mirror: soft feedback via message
                local plgui = player:FindFirstChild("PlayerGui")
                if plgui then
                    local msg = Instance.new("Message")
                    msg.Text = "It looks real… but something feels off."
                    msg.Parent = plgui
                    delay(1.5, function() pcall(function() msg:Destroy() end) end)
                end
            end
        end)
    end
end

ensureIllusions()
ensureMirrorGrove()

-- Solari NPC hub
local function ensureSolari()
    if Zone2:FindFirstChild("SolariNPC") then return end
    local sol = Instance.new("Part")
    sol.Name = "SolariNPC"
    sol.Size = Vector3.new(2,5,2)
    sol.Position = Vector3.new(0, 3, 120)
    sol.Anchored = true
    sol.BrickColor = BrickColor.new("Bright orange")
    sol.Parent = Zone2

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Talk"
    prompt.ObjectText = "Solari"
    prompt.HoldDuration = 0.3
    prompt.MaxActivationDistance = 10
    prompt.Parent = sol

    prompt.Triggered:Connect(function(player)
        if not player or not player:IsA("Player") then return end
        local refl = ""
        local rv = player:FindFirstChild("ReflectionChoice")
        if rv and rv.Value then refl = tostring(rv.Value) end
        local greeting = "Welcome to Lensveil. Your inner light will reveal what is hidden."
        if string.find(refl, "🔥") then
            greeting = "Your fire runs strong. Use it to see through illusions."
        elseif string.find(refl, "🌱") then
            greeting = "Gentle growth still shines. Let it guide your path."
        elseif string.find(refl, "🧡") then
            greeting = "That warmth you felt? Hold onto it. It shows the way."
        end
        local lines = {
            greeting,
            "Collect three Light Shards to form the lightbridge ahead.",
            "Press R or tap Reveal to glimpse the unseen."
        }
        pcall(function() dialogEvent:FireClient(player, {speaker = "Solari", lines = lines}) end)
    end)
end

ensureSolari()


