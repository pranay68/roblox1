-- SparkServer.lua
-- Place this script in ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- try to load assets module from ReplicatedStorage (optional)
local assets = {}
do
    local assetsModule = ReplicatedStorage:FindFirstChild("IgnisiaAssets")
    if assetsModule and assetsModule:IsA("ModuleScript") then
        local ok, m = pcall(require, assetsModule)
        if ok and type(m) == "table" then
            assets = m
        end
    end
end

local RunService = game:GetService("RunService")

-- Metrics (optional)
local Metrics = nil
pcall(function()
    Metrics = require(game:GetService("ServerScriptService"):FindFirstChild("Metrics") or nil)
end)

-- simple ignite cooldowns per player to avoid spam/exploit
local igniteCooldown = {}
local IGNITE_COOLDOWN_SECONDS = 4


local sparkEvent = ReplicatedStorage:FindFirstChild("SparkEvent")
local effectEvent = ReplicatedStorage:FindFirstChild("IgnisiaEffectEvent")

-- Ensure remote events exist
if not sparkEvent then
    sparkEvent = Instance.new("RemoteEvent")
    sparkEvent.Name = "SparkEvent"
    sparkEvent.Parent = ReplicatedStorage
end
if not effectEvent then
    effectEvent = Instance.new("RemoteEvent")
    effectEvent.Name = "IgnisiaEffectEvent"
    effectEvent.Parent = ReplicatedStorage
end

local function attachAuraToCharacter(player)
    local character = player.Character
    if not character then return end
    if character:FindFirstChild("_IgnisiaAura") then return end

    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart")
    if not root then return end

    local auraFolder = Instance.new("Folder")
    auraFolder.Name = "_IgnisiaAura"
    auraFolder.Parent = character

    local attachment = Instance.new("Attachment")
    attachment.Name = "IgnisiaAuraAttachment"
    attachment.Parent = root

    local p = Instance.new("ParticleEmitter")
    p.Name = "IgnisiaAuraParticles"
    p.Texture = assets.auraParticleTexture or "" -- add texture id if desired

    -- Choose aura color based on player's reflection choice (if present)
    local auraColor = Color3.fromRGB(255, 170, 80) -- default warm
    local refl = nil
    local rsv = player:FindFirstChild("ReflectionChoice")
    if rsv and rsv.Value then
        refl = tostring(rsv.Value)
    end
    if refl then
        if string.find(refl, "🔥") then
            auraColor = Color3.fromRGB(255, 110, 40)
        elseif string.find(refl, "🌱") then
            auraColor = Color3.fromRGB(120, 200, 120)
        elseif string.find(refl, "💫") then
            auraColor = Color3.fromRGB(180, 200, 255)
        elseif string.find(refl, "🧡") then
            auraColor = Color3.fromRGB(255, 180, 90)
        end
    end
    p.Color = ColorSequence.new(auraColor)
    p.Rate = 8
    p.Lifetime = NumberRange.new(1,1.8)
    p.Speed = NumberRange.new(0.3,0.9)
    p.Parent = attachment
end

-- Listen for players igniting the spark
sparkEvent.OnServerEvent:Connect(function(player, action, reflectionChoice)
    if action ~= "ignite" then return end

    -- sanitize reflectionChoice
    if reflectionChoice and type(reflectionChoice) == "string" then
        if #reflectionChoice > 200 then reflectionChoice = string.sub(reflectionChoice,1,200) end
    else
        reflectionChoice = tostring(reflectionChoice or "")
    end

    -- throttle repeated ignite attempts
    local last = igniteCooldown[player.UserId]
    if last and (tick() - last) < IGNITE_COOLDOWN_SECONDS then
        if Metrics then pcall(function() Metrics:Increment("ignite_spam") end) end
        warn("SparkServer: player trying to ignite too quickly", player.Name)
        return
    end
    igniteCooldown[player.UserId] = tick()

    -- SERVER VALIDATION: ensure player is actually near the Spark part
    local sparkPart = workspace:FindFirstChild("Spark")
    if not sparkPart then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local dist = (root.Position - sparkPart.Position).Magnitude
    if dist > (assets.tuning and assets.tuning.NEAR_RADIUS or 8) + 2 then
        warn("SparkServer: ignite attempt from too far away by", player.Name, "dist=", dist)
        if Metrics then pcall(function() Metrics:Increment("ignite_far_attempts") end) end
        return
    end

    -- prevent duplicate marking
    if player:FindFirstChild("HasSpark") and player.HasSpark.Value == true then
        if Metrics then pcall(function() Metrics:Increment("ignite_duplicate") end) end
        return
    end

    -- create HasSpark and store reflection choice (validate emoji choices)
    local has = Instance.new("BoolValue")
    has.Name = "HasSpark"
    has.Value = true
    has.Parent = player

    if reflectionChoice and reflectionChoice ~= "" then
        local allowed = false
        if string.find(reflectionChoice, "🧡") or string.find(reflectionChoice, "🔥") or string.find(reflectionChoice, "🌱") or string.find(reflectionChoice, "💫") then
            allowed = true
        end
        if not allowed then reflectionChoice = "🧡" end
        local s = Instance.new("StringValue")
        s.Name = "ReflectionChoice"
        s.Value = tostring(reflectionChoice)
        s.Parent = player
    end

    -- attach aura immediately if character loaded
    attachAuraToCharacter(player)

    -- broadcast ignite effect to all clients, include the reflection choice for client-side VFX
    pcall(function() effectEvent:FireAllClients({type = "ignite", player = player, reflection = reflectionChoice}) end)

    -- ensure aura attaches on respawn
    player.CharacterAdded:Connect(function()
        wait(0.5)
        attachAuraToCharacter(player)
    end)

    -- Save player progress via SaveService if available
    local ok, SaveService = pcall(function() return require(game:GetService("ServerScriptService"):FindFirstChild("SaveService")) end)
    if ok and type(SaveService) == "table" and SaveService.SavePlayer then
        pcall(function() SaveService:SavePlayer(player) end)
    end

    -- log success
    if Metrics then pcall(function() Metrics:Increment("ignite_success") end) end
end)


