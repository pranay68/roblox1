-- MVPInstaller.lua
-- One-file installer to set up Ignisia (Zone 1) + Lensveil (Zone 2 MVP)
-- Usage: Paste this script in Roblox Studio (Command Bar or a Script) and run once.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then error("MVPInstaller must be run in Roblox Studio") end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts") or Instance.new("StarterPlayerScripts")

-- helpers
local function ensureRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then return r end
    r = Instance.new("RemoteEvent")
    r.Name = name
    r.Parent = ReplicatedStorage
    return r
end

local function ensureModuleScript(name, source)
    local existing = ReplicatedStorage:FindFirstChild(name)
    if existing and existing:IsA("ModuleScript") then return existing end
    local m = Instance.new("ModuleScript")
    m.Name = name
    m.Source = source
    m.Parent = ReplicatedStorage
    return m
end

local function ensureServerScript(name, source)
    local existing = ServerScriptService:FindFirstChild(name)
    if existing and existing:IsA("Script") then return existing end
    local s = Instance.new("Script")
    s.Name = name
    s.Source = source
    s.Parent = ServerScriptService
    return s
end

local function ensureLocalScript(name, source)
    local existing = StarterPlayerScripts:FindFirstChild(name)
    if existing and existing:IsA("LocalScript") then return existing end
    local s = Instance.new("LocalScript")
    s.Name = name
    s.Source = source
    s.Parent = StarterPlayerScripts
    return s
end

-- Remotes
ensureRemote("SparkEvent")
ensureRemote("IgnisiaEffectEvent")
ensureRemote("RevealEvent")
ensureRemote("DialogEvent")
ensureRemote("ProfilerEvent")
ensureRemote("NPCAnimEvent")

-- Assets module (placeholders OK)
local ASSETS_SOURCE = [[
local assets = {}
assets.sounds = {
    ambient = "rbxassetid://451776625",
    crackle = "rbxassetid://705787045",
    hum = "rbxassetid://171186876",
    chime = "rbxassetid://180204501",
}
assets.kneelAnimation = "rbxassetid://71201518567477"
assets.auraParticleTexture = ""
assets.ui = {
    vignetteImage = "rbxassetid://3570695787",
}
assets.ui.reflectionButtonIcons = {"", "", ""}
assets.npcDecals = {
    Solari = "",
}
assets.graphics = { particleMultiplier = 1.0, enableBloom = true, enableVignette = true }
assets.tuning = { NEAR_RADIUS = 8, STILL_VEL_THRESHOLD = 1.2, TARGET_SECONDS = 3.5 }
return assets
]]
ensureModuleScript("IgnisiaAssets", ASSETS_SOURCE)

-- Simple GameConfig for tunables and positions
local GAMECONFIG_SOURCE = [[
local cfg = {}
cfg.positions = {
    zone2GateTeleport = Vector3.new(0,5,120),
    -- If shard positions are nil, they will be auto-placed around the teleport anchor
    zone2ShardPositions = nil,
    zone2BridgePos = nil, -- if nil, placed ahead of teleport anchor
    solariPos = nil,      -- if nil, placed near teleport anchor
}
cfg.tuning = {
    revealCooldown = 3.5,
    patience = { nearRadius = 8, stillVel = 1.2, targetSeconds = 3.5 },
}
-- Optional asset overrides so you can swap placeholders without code edits
cfg.assets = {
    vignetteImage = "", -- e.g., "rbxassetid://YOUR_VIGNETTE_ID"
    reflectionButtonIcons = {"", "", ""},
    npcDecals = { Solari = "" },
}
return cfg
]]
ensureModuleScript("GameConfig", GAMECONFIG_SOURCE)

-- Zone 1 Dialog (official lines)
local ZONE1_DIALOG_SOURCE = [[
local Zone1Dialog = {}
Zone1Dialog.openingCinematic = {
	{name = "Solari", text = "Whoa. Look at this little guy—still glowing after all that? …Same."},
	{name = "Solari", text = "Hey! You made it! I wasn’t sure you’d show... You don’t feel like a myth."},
	{name = "Donna", text = "The light inside you… it remembers. Even if you forgot."},
	{name = "Shauna", text = "BOOM! Did I scare you? No? Okay well, pretend I did. I have a reputation to uphold."},
	{name = "Solari", text = "Shauna thinks she’s mysterious. Really she just likes dramatic entrances."},
	{name = "Shauna", text = "Excuse you. This place needs drama... You pose."},
	{name = "Heidi", text = "Or… you breathe. Sometimes light needs quiet to be heard."},
	{name = "Donna", text = "This is Ignisia. The place where the spark first wakes up. Yours is here somewhere—waiting."},
	{name = "Solari", text = "Let’s find it. Before Shauna tries to name it something like “Sir Sizzlepuff.”"},
	{name = "Shauna", text = "Wow. That’s actually kind of amazing. I claim full naming rights."},
	{name = "Donna", text = "Follow the flicker. It knows you."},
	{name = "Solari", text = "Let’s go spark-searching. You ready?"},
}
Zone1Dialog.reflectionChoices = {
	"🔥 Like something inside me finally said: \"I'm here.\"",
	"🌱 Small, but brave. Like a candle lighting in the dark.",
	"💫 Honestly? I didn’t think I had one. But… maybe I do.",
}
return Zone1Dialog
]]
ensureModuleScript("Zone1Dialog", ZONE1_DIALOG_SOURCE)

-- Spark part + prompt
local spark = workspace:FindFirstChild("Spark")
if not spark then
    spark = Instance.new("Part")
    spark.Name = "Spark"
    spark.Size = Vector3.new(6,1,6)
    spark.Anchored = true
    spark.Position = Vector3.new(0,2,0)
    spark.Parent = workspace
    local pl = Instance.new("PointLight") pl.Color = Color3.fromRGB(255,150,80) pl.Range = 12 pl.Parent = spark
    local pe = Instance.new("ParticleEmitter") pe.Rate = 12 pe.Lifetime = NumberRange.new(1,2) pe.Speed = NumberRange.new(0.6,1.4) pe.Parent = spark
    local prompt = Instance.new("ProximityPrompt") prompt.ActionText = "Touch the Spark?" prompt.ObjectText = "Spark" prompt.RequiresLineOfSight = false prompt.MaxActivationDistance = 8 prompt.HoldDuration = 0 prompt.Parent = spark
end

-- Server: SaveService (MVP)
local SAVE_SOURCE = [[
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local STORE = DataStoreService:GetDataStore("IgnisiaPlayerData_v1")
local function keyFor(id) return "player_"..tostring(id) end

local function updateAsync(key, patch)
    local ok, res = pcall(function()
        return STORE:UpdateAsync(key, function(old)
            local current = old or {}
            for k,v in pairs(patch) do current[k] = v end
            return current
        end)
    end)
    return ok, res
end

local function load(id)
    local ok, data = pcall(function() return STORE:GetAsync(keyFor(id)) end)
    return ok and data or nil
end

local function capturePlayerSnapshot(player)
    local payload = {}
    if player:FindFirstChild("HasSpark") and player.HasSpark.Value then payload.HasSpark = true end
    if player:FindFirstChild("ReflectionChoice") and player.ReflectionChoice.Value ~= "" then payload.ReflectionChoice = tostring(player.ReflectionChoice.Value) end
    local shards = player:FindFirstChild("Zone2Shards")
    if shards then payload.Zone2Shards = tonumber(shards.Value) or 0 end
    if player:FindFirstChild("MirrorSolved") and player.MirrorSolved.Value then payload.MirrorSolved = true end
    return payload
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        local data = load(player.UserId)
        if data then
            if data.HasSpark then local v = Instance.new("BoolValue") v.Name = "HasSpark" v.Value = true v.Parent = player end
            if data.ReflectionChoice then local s = Instance.new("StringValue") s.Name = "ReflectionChoice" s.Value = tostring(data.ReflectionChoice) s.Parent = player end
            if data.Zone2Shards then local iv = Instance.new("IntValue") iv.Name = "Zone2Shards" iv.Value = tonumber(data.Zone2Shards) or 0 iv.Parent = player end
            if data.MirrorSolved then local bv = Instance.new("BoolValue") bv.Name = "MirrorSolved" bv.Value = true bv.Parent = player end
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    task.spawn(function()
        updateAsync(keyFor(player.UserId), capturePlayerSnapshot(player))
    end)
end)

local SaveService = {}
function SaveService:SavePlayer(player)
    task.spawn(function()
        updateAsync(keyFor(player.UserId), capturePlayerSnapshot(player))
    end)
end
return SaveService
]]
ensureServerScript("SaveService", SAVE_SOURCE)

-- Server: SparkServer (MVP)
local SPARK_SERVER_SOURCE = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sparkEvent = ReplicatedStorage:FindFirstChild("SparkEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
sparkEvent.Name = "SparkEvent"
local effectEvent = ReplicatedStorage:FindFirstChild("IgnisiaEffectEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
effectEvent.Name = "IgnisiaEffectEvent"
local npcAnimEvent = ReplicatedStorage:FindFirstChild("NPCAnimEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
npcAnimEvent.Name = "NPCAnimEvent"

local function attachAura(player)
    local char = player.Character if not char then return end
    if char:FindFirstChild("_IgnisiaAura") then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart") if not root then return end
    local folder = Instance.new("Folder") folder.Name = "_IgnisiaAura" folder.Parent = char
    local att = Instance.new("Attachment") att.Name = "IgnisiaAuraAttachment" att.Parent = root
    local p = Instance.new("ParticleEmitter") p.Name = "IgnisiaAuraParticles" p.Texture = "" p.Color = ColorSequence.new(Color3.fromRGB(255,170,80)) p.Rate = 8 p.Lifetime = NumberRange.new(1,1.8) p.Speed = NumberRange.new(0.3,0.9) p.Parent = att
end

sparkEvent.OnServerEvent:Connect(function(player, action, reflectionChoice)
    if action ~= "ignite" then return end
    if player:FindFirstChild("HasSpark") and player.HasSpark.Value == true then return end
    local has = Instance.new("BoolValue") has.Name = "HasSpark" has.Value = true has.Parent = player
    if reflectionChoice and reflectionChoice ~= "" then local s = Instance.new("StringValue") s.Name = "ReflectionChoice" s.Value = tostring(reflectionChoice) s.Parent = player end
    attachAura(player)
    effectEvent:FireAllClients({type = "ignite", player = player})
    player.CharacterAdded:Connect(function() task.wait(0.5) attachAura(player) end)
    -- save
    local ok, SaveService = pcall(function() return require(game:GetService("ServerScriptService"):FindFirstChild("SaveService")) end)
    if ok and SaveService and SaveService.SavePlayer then pcall(function() SaveService:SavePlayer(player) end) end
end)

-- Allow clients to request playing an animation on a named NPC model in Workspace (server-authoritative)
npcAnimEvent.OnServerEvent:Connect(function(player, payload)
    if type(payload) ~= "table" then return end
    local name = tostring(payload.name or "")
    local animId = tostring(payload.animId or "")
    if name == "" or animId == "" then return end
    local npc = workspace:FindFirstChild(name)
    if not npc or not npc:IsA("Model") then return end
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    -- simple throttle per player
    player:SetAttribute("_lastNpcAnim", tick())
    local animation = Instance.new("Animation") animation.AnimationId = animId
    local track = hum:LoadAnimation(animation)
    track:Play()
end)
]]
ensureServerScript("SparkServer", SPARK_SERVER_SOURCE)

-- Server: Zone2Content (MVP)
local ZONE2_SOURCE = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local okCfg, GameConfig = pcall(function() return require(ReplicatedStorage:WaitForChild("GameConfig")) end)
local Zone2 = workspace:FindFirstChild("Zone2") or Instance.new("Folder")
Zone2.Name = "Zone2" Zone2.Parent = workspace

local revealEvent = ReplicatedStorage:FindFirstChild("RevealEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
revealEvent.Name = "RevealEvent"
local dialogEvent = ReplicatedStorage:FindFirstChild("DialogEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
dialogEvent.Name = "DialogEvent"
local npcAnimEvent = ReplicatedStorage:FindFirstChild("NPCAnimEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
npcAnimEvent.Name = "NPCAnimEvent"

local revealCooldowns = {} local REVEAL_COOLDOWN = (okCfg and GameConfig.tuning and GameConfig.tuning.revealCooldown) or 3.0
revealEvent.OnServerEvent:Connect(function(player)
    if not player then return end
    local now = tick() local last = revealCooldowns[player.UserId] or -100
    if (now - last) < REVEAL_COOLDOWN then return end
    revealCooldowns[player.UserId] = now
end)

local function groundAt(pos)
    local ray = Ray.new(pos + Vector3.new(0,50,0), Vector3.new(0,-200,0))
    local part, hit = workspace:FindPartOnRay(ray)
    if hit then return Vector3.new(pos.X, hit.Y + 1.5, pos.Z) end
    return pos
end

local anchor = (okCfg and GameConfig.positions and GameConfig.positions.zone2GateTeleport) or Vector3.new(0,5,120)
local ShardPositions = (okCfg and GameConfig.positions and GameConfig.positions.zone2ShardPositions)
if not ShardPositions then
    ShardPositions = {
        groundAt(anchor + Vector3.new(10,0,12)),
        groundAt(anchor + Vector3.new(-8,0,16)),
        groundAt(anchor + Vector3.new(14,0,18)),
    }
end

local function onShardTouched(shard)
    shard.Touched:Connect(function(hit)
        local pl = Players:GetPlayerFromCharacter(hit.Parent)
        if not pl then return end
        local char = pl.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local dist = (char.HumanoidRootPart.Position - shard.Position).Magnitude
            if dist > 6 then return end
        end
        local prog = pl:FindFirstChild("Zone2Shards") or Instance.new("IntValue", pl)
        prog.Name = "Zone2Shards" prog.Value = (prog.Value or 0) + 1
        pcall(function() shard:Destroy() end)
        -- persist
        pcall(function() local SS = require(game:GetService("ServerScriptService"):FindFirstChild("SaveService")) if SS and SS.SavePlayer then SS:SavePlayer(pl) end end)
        if prog.Value >= #ShardPositions and not Zone2:FindFirstChild("LightBridge") then
            local defaultPos = anchor + Vector3.new(0,0,30)
            local pos = (okCfg and GameConfig.positions and GameConfig.positions.zone2BridgePos) or groundAt(defaultPos)
            local bridge = Instance.new("Part") bridge.Name = "LightBridge" bridge.Size = Vector3.new(12,1,4) bridge.Position = pos bridge.Anchored = true bridge.BrickColor = BrickColor.new("Institutional white") bridge.Parent = Zone2
        end
    end)
end

for i,pos in ipairs(ShardPositions) do
    local s = Instance.new("Part") s.Name = "LightShard" s.Size = Vector3.new(1,1,1) s.Position = pos s.Anchored = true s.BrickColor = BrickColor.new("Bright yellow") s.Parent = Zone2
    onShardTouched(s)
end

-- Illusions (simple): invisible steps/path tagged for client reveal
local function illusion(name, size, cf)
    local p = Instance.new("Part") p.Name = name p.Size = size p.CFrame = cf p.Anchored = true p.CanCollide = false p.Transparency = 1 p.Parent = Zone2 pcall(function() CollectionService:AddTag(p, "Illusion") end) return p
end
illusion("IllusionPath1", Vector3.new(4,1,16), CFrame.new(4,3,146))
illusion("IllusionPath2", Vector3.new(4,1,16), CFrame.new(-4,3,146))

-- Mirror Grove (one real mirror)
local grove = Instance.new("Folder") grove.Name = "MirrorGrove" grove.Parent = Zone2
local positions = { CFrame.new(-12,3,126), CFrame.new(-8,3,126), CFrame.new(-4,3,126), CFrame.new(0,3,126) }
local realIndex = 3
for i,cf in ipairs(positions) do
    local m = Instance.new("Part") m.Name = "Mirror"..i m.Size = Vector3.new(3,5,1) m.CFrame = cf m.Anchored = true m.BrickColor = BrickColor.new("Really black") m.Reflectance = 0.4 m.Parent = grove
    if i == realIndex then pcall(function() CollectionService:AddTag(m, "IllusionHint") end) end
    local prompt = Instance.new("ProximityPrompt") prompt.ActionText = "Inspect" prompt.ObjectText = "Mirror" prompt.HoldDuration = 0.3 prompt.MaxActivationDistance = 8 prompt.Parent = m
    prompt.Triggered:Connect(function(player)
        if i == realIndex then
            if not player:FindFirstChild("MirrorSolved") then local b = Instance.new("BoolValue", player) b.Name = "MirrorSolved" b.Value = true pcall(function() local SS = require(game:GetService("ServerScriptService"):FindFirstChild("SaveService")) if SS and SS.SavePlayer then SS:SavePlayer(player) end end) end
        else
            local plgui = player:FindFirstChild("PlayerGui") if plgui then local msg = Instance.new("Message", plgui) msg.Text = "It looks real… but something feels off." task.delay(1.5, function() pcall(function() msg:Destroy() end) end) end
        end
    end)
end

-- Solari NPC
local defaultSol = groundAt(anchor + Vector3.new(6,0,4))
local sol = Instance.new("Part") sol.Name = "SolariNPC" sol.Size = Vector3.new(2,5,2) sol.Position = ((okCfg and GameConfig.positions and GameConfig.positions.solariPos) or defaultSol) sol.Anchored = true sol.BrickColor = BrickColor.new("Bright orange") sol.Parent = Zone2
local sp = Instance.new("ProximityPrompt") sp.ActionText = "Talk" sp.ObjectText = "Solari" sp.HoldDuration = 0.3 sp.MaxActivationDistance = 10 sp.Parent = sol
sp.Triggered:Connect(function(player)
    local refl = "" local rv = player:FindFirstChild("ReflectionChoice") if rv and rv.Value then refl = tostring(rv.Value) end
    local greeting = "Welcome to Lensveil. Your inner light will reveal what is hidden."
    if string.find(refl, "🔥") then greeting = "Your fire runs strong. Use it to see through illusions."
    elseif string.find(refl, "🌱") then greeting = "Gentle growth still shines. Let it guide your path."
    elseif string.find(refl, "🧡") then greeting = "That warmth you felt? Hold onto it. It shows the way." end
    local lines = { greeting, "Collect three Light Shards to form the lightbridge ahead.", "Press R or tap Reveal to glimpse the unseen." }
    pcall(function() dialogEvent:FireClient(player, {speaker = "Solari", lines = lines, npcName = "SolariNPC", perLine = {
        {animId = "", cameraPath = nil},
        {animId = "", cameraPath = nil},
        {animId = "", cameraPath = nil},
    }}) end)
end)
]]
ensureServerScript("Zone2Content", ZONE2_SOURCE)

-- Server: ZoneGate
local ZONE_GATE_SOURCE = [[
local TELEPORT_POS = Vector3.new(0,5,120)
local part = script.Parent
if not part or not part:IsA("BasePart") then
    part = workspace:FindFirstChild("Zone2Gate") or Instance.new("Part", workspace)
    part.Name = "Zone2Gate" part.Size = Vector3.new(8,3,1) part.Position = Vector3.new(0,3,40) part.Anchored = true
end
local okCfg, GameConfig = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig")) end)
local tp = (okCfg and GameConfig.positions and GameConfig.positions.zone2GateTeleport) or TELEPORT_POS
local Players = game:GetService("Players")
local proximity = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt", part)
proximity.ActionText = "Enter Lensveil" proximity.ObjectText = "Zone Gate" proximity.HoldDuration = 0.5 proximity.MaxActivationDistance = 8
proximity.Triggered:Connect(function(player)
    if player:FindFirstChild("HasSpark") and player.HasSpark.Value == true then
        local char = player.Character if char and char:FindFirstChild("HumanoidRootPart") then char:SetPrimaryPartCFrame(CFrame.new(tp)) end
    else
        local plgui = player:FindFirstChild("PlayerGui") if plgui then local msg = Instance.new("Message", plgui) msg.Text = "You need the First Flame to enter." task.delay(2, function() pcall(function() msg:Destroy() end) end) end
    end
end)
]]
ensureServerScript("ZoneGate", ZONE_GATE_SOURCE)

-- Client: SparkClient (MVP, trimmed but feature-complete)
local SPARK_CLIENT_SOURCE = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local okCfg, GameConfig = pcall(function() return require(ReplicatedStorage:WaitForChild("GameConfig")) end)
local sparkEvent = ReplicatedStorage:FindFirstChild("SparkEvent") or Instance.new("RemoteEvent", ReplicatedStorage) sparkEvent.Name = "SparkEvent"
local effectEvent = ReplicatedStorage:FindFirstChild("IgnisiaEffectEvent") or Instance.new("RemoteEvent", ReplicatedStorage) effectEvent.Name = "IgnisiaEffectEvent"
local revealEvent = ReplicatedStorage:FindFirstChild("RevealEvent") or Instance.new("RemoteEvent", ReplicatedStorage) revealEvent.Name = "RevealEvent"
local dialogEvent = ReplicatedStorage:FindFirstChild("DialogEvent") or Instance.new("RemoteEvent", ReplicatedStorage) dialogEvent.Name = "DialogEvent"
local npcAnimEvent = ReplicatedStorage:FindFirstChild("NPCAnimEvent") or Instance.new("RemoteEvent", ReplicatedStorage) npcAnimEvent.Name = "NPCAnimEvent"

local assets = {}
do local mod = ReplicatedStorage:FindFirstChild("IgnisiaAssets") if mod and mod:IsA("ModuleScript") then local ok, m = pcall(require, mod) if ok and type(m) == "table" then assets = m end end end
-- merge asset overrides from GameConfig if present
pcall(function()
    if okCfg and GameConfig.assets then
        assets.ui = assets.ui or {}
        if GameConfig.assets.vignetteImage and GameConfig.assets.vignetteImage ~= "" then assets.ui.vignetteImage = GameConfig.assets.vignetteImage end
        if GameConfig.assets.reflectionButtonIcons then assets.ui.reflectionButtonIcons = GameConfig.assets.reflectionButtonIcons end
        assets.npcDecals = assets.npcDecals or {}
        if GameConfig.assets.npcDecals then for k,v in pairs(GameConfig.assets.npcDecals) do assets.npcDecals[k] = v end end
    end
end)
assets.tuning = assets.tuning or {}
local NEAR_RADIUS = (okCfg and GameConfig.tuning and GameConfig.tuning.patience and GameConfig.tuning.patience.nearRadius) or assets.tuning.NEAR_RADIUS or 8
local STILL_VEL_THRESHOLD = (okCfg and GameConfig.tuning and GameConfig.tuning.patience and GameConfig.tuning.patience.stillVel) or assets.tuning.STILL_VEL_THRESHOLD or 1.2
local TARGET_SECONDS = (okCfg and GameConfig.tuning and GameConfig.tuning.patience and GameConfig.tuning.patience.targetSeconds) or assets.tuning.TARGET_SECONDS or 3.5

-- GUI
local gui = playerGui:FindFirstChild("IgnisiaUI")
if not gui then gui = Instance.new("ScreenGui") gui.Name = "IgnisiaUI" gui.ResetOnSpawn = false gui.Parent = playerGui end
local dialog = gui:FindFirstChild("DialogLabel") or Instance.new("TextLabel")
dialog.Name = "DialogLabel" dialog.Size = UDim2.new(0.6,0,0.12,0) dialog.Position = UDim2.new(0.2,0,0.08,0) dialog.BackgroundTransparency = 0.5 dialog.TextColor3 = Color3.new(1,1,1) dialog.TextScaled = true dialog.Visible = false dialog.Parent = gui
local portrait = gui:FindFirstChild("DialogPortrait") or Instance.new("ImageLabel")
portrait.Name = "DialogPortrait" portrait.Size = UDim2.new(0,120,0,120) portrait.Position = UDim2.new(0.05,0,0.02,0) portrait.BackgroundTransparency = 1 portrait.Visible = false portrait.Parent = gui
local bar = gui:FindFirstChild("PatienceBar") or Instance.new("Frame")
bar.Name = "PatienceBar" bar.Size = UDim2.new(0.4,0,0.035,0) bar.Position = UDim2.new(0.3,0,0.9,0) bar.BackgroundColor3 = Color3.fromRGB(40,40,40) bar.Parent = gui
local fill = bar:FindFirstChild("PatienceFill") or Instance.new("Frame")
fill.Name = "PatienceFill" fill.Size = UDim2.new(0,0,1,0) fill.BackgroundColor3 = Color3.fromRGB(255,170,80) fill.Parent = bar
local reflection = gui:FindFirstChild("ReflectionGui") or Instance.new("Frame")
reflection.Name = "ReflectionGui" reflection.Size = UDim2.new(0.4,0,0.25,0) reflection.Position = UDim2.new(0.3,0,0.4,0) reflection.BackgroundColor3 = Color3.fromRGB(20,20,20) reflection.Visible = false reflection.Parent = gui
local function ensureChoice(ref, name, pos, text)
    local b = ref:FindFirstChild(name) or Instance.new("TextButton")
    b.Name = name b.Size = UDim2.new(0.9,0,0.25,0) b.Position = pos b.Text = text b.BackgroundColor3 = Color3.fromRGB(40,20,10) b.TextColor3 = Color3.new(1,1,1) b.Parent = ref
    return b
end
local c1 = ensureChoice(reflection, "Choice1", UDim2.new(0.05,0,0.05,0), "🧡 Like something I’d been waiting for")
local c2 = ensureChoice(reflection, "Choice2", UDim2.new(0.05,0,0.37,0), "🔥 Like I’m not afraid of my fire")
local c3 = ensureChoice(reflection, "Choice3", UDim2.new(0.05,0,0.69,0), "🌱 Like maybe I’m not broken")

local spark = workspace:FindFirstChild("Spark")
if not spark then spark = Instance.new("Part") spark.Name = "Spark" spark.Size = Vector3.new(6,1,6) spark.Anchored = true spark.Position = Vector3.new(0,2,0) spark.Parent = workspace end
local sparkLight = spark:FindFirstChildOfClass("PointLight")
local sparkEmitter = spark:FindFirstChildOfClass("ParticleEmitter")

local function setPatienceFill(p) p = math.clamp(p,0,1) fill.Size = UDim2.new(p,0,1,0) end

-- Reflection wiring
local function choose(text)
    reflection:SetAttribute("ChosenReflection", text)
    reflection.Visible = false
    dialog.Text = "You chose: "..text
    dialog.Visible = true
    task.delay(1.4, function() dialog.Visible = false end)
end
c1.MouseButton1Click:Connect(function() choose("🧡 Like something I’d been waiting for") end)
c2.MouseButton1Click:Connect(function() choose("🔥 Like I’m not afraid of my fire") end)
c3.MouseButton1Click:Connect(function() choose("🌱 Like maybe I’m not broken") end)

-- Cinematic once
local playedCinematic = false
local function playCinematicOnce()
    if playedCinematic then return end
    playedCinematic = true
    local camera = workspace.CurrentCamera if not camera then return end
    camera.CameraType = Enum.CameraType.Scriptable
    local startCF = CFrame.new(spark.Position + Vector3.new(0, 30, -60), spark.Position)
    local endCF = CFrame.new(spark.Position + Vector3.new(0, 8, -18), spark.Position)
    local t,d=0,4
    while t<d do t = t + RunService.RenderStepped:Wait() camera.CFrame = startCF:Lerp(endCF, math.clamp(t/d,0,1)) end
    local lines = {
        {name="Alex", text="I notice it first."},
        {name="Alexis", text="Heh, it's glowing — dramatic, right?"},
        {name="Solari", text="It's been here, waiting."},
    }
    for _,e in ipairs(lines) do dialog.Text = e.name..": "..e.text dialog.Visible = true task.wait(2.0) end
    dialog.Visible = false camera.CameraType = Enum.CameraType.Custom
end
player.CharacterAdded:Connect(function() task.wait(0.5) playCinematicOnce() end)

-- Patience loop
local accumulated = 0
local function monitorSpark()
    while true do
        local char = player.Character local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local dist = (root.Position - spark.Position).Magnitude
            local near = dist <= NEAR_RADIUS
            local vel = root.Velocity.Magnitude
            if near and vel <= STILL_VEL_THRESHOLD then
                accumulated += 0.1 setPatienceFill(accumulated/TARGET_SECONDS)
                if sparkEmitter then sparkEmitter.Rate = 12 + math.floor(math.clamp(accumulated/TARGET_SECONDS,0,1)*80) end
                if sparkLight then sparkLight.Brightness = 2 + math.clamp(accumulated/TARGET_SECONDS,0,1) * 6 end
            else
                accumulated = math.max(0, accumulated - (near and 0.15 or 0.2)) setPatienceFill(accumulated/TARGET_SECONDS)
            end
            if accumulated >= TARGET_SECONDS then
                dialog.Text = "You feel a warm whoosh as the spark responds..." dialog.Visible = true task.wait(1.2) dialog.Visible = false
                reflection.Visible = true
                while reflection.Visible do RunService.RenderStepped:Wait() end
                local chosen = reflection:GetAttribute("ChosenReflection") or ""
                sparkEvent:FireServer("ignite", chosen)
                accumulated = 0 setPatienceFill(0)
            end
        end
        task.wait(0.1)
    end
end
task.spawn(monitorSpark)

-- Reveal ability (R key + button)
local lastRevealTime = -100
local function pulseReveal()
    local now = tick() if now - lastRevealTime < 3.5 then return end lastRevealTime = now
    pcall(function() revealEvent:FireServer() end)
    -- bloom
    local lighting = game:GetService("Lighting")
    local bloom = lighting:FindFirstChild("IgnisiaRevealBloom") or Instance.new("BloomEffect", lighting)
    bloom.Name = "IgnisiaRevealBloom" bloom.Threshold = 1 bloom.Intensity = 0.1 bloom.Size = 24
    TweenService:Create(bloom, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Intensity = 1.1, Size = 56}):Play()
    task.delay(1.25, function() TweenService:Create(bloom, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Intensity = 0.1, Size = 24}):Play() end)
    -- highlight illusions
    local function hi(inst)
        if inst:IsA("BasePart") then
            local orig = inst.LocalTransparencyModifier inst.LocalTransparencyModifier = 0.2
            local sel = Instance.new("SelectionBox") sel.LineThickness = 0.03 sel.Color3 = Color3.fromRGB(255,220,140) sel.Adornee = inst sel.Parent = inst
            task.delay(1.25, function() pcall(function() inst.LocalTransparencyModifier = orig end) pcall(function() sel:Destroy() end) end)
        end
    end
    for _,i in ipairs(CollectionService:GetTagged("Illusion")) do hi(i) end
    for _,i in ipairs(CollectionService:GetTagged("IllusionHint")) do hi(i) end
end
UserInputService.InputBegan:Connect(function(input, processed) if processed then return end if input.KeyCode == Enum.KeyCode.R then pulseReveal() end end)
local rb = gui:FindFirstChild("RevealButton") or Instance.new("TextButton")
rb.Name = "RevealButton"
rb.Size = UDim2.new(0,140,0,44)
rb.Position = UDim2.new(0.02,0,0.82,0)
rb.AnchorPoint = Vector2.new(0,0)
rb.Text = "Reveal"
rb.TextScaled = true
rb.BackgroundColor3 = Color3.fromRGB(40,20,10)
rb.TextColor3 = Color3.new(1,1,1)
rb.Parent = gui
-- Simple mobile-friendly adjustment
pcall(function()
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        rb.Size = UDim2.new(0,170,0,56)
        rb.Position = UDim2.new(0.03,0,0.82,0)
    end
end)
rb.MouseButton1Click:Connect(pulseReveal)

-- Reflection button mobile scaling
pcall(function()
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        for _,btnName in ipairs({"Choice1","Choice2","Choice3"}) do
            local b = reflection:FindFirstChild(btnName)
            if b then b.TextScaled = true end
        end
    end
end)

-- Dialog listener
dialogEvent.OnClientEvent:Connect(function(data)
    if not data then return end
    local lines = data.lines or {}
    local speaker = data.speaker or ""
    -- Try cinematic dialog first
    local ctrl = gui:FindFirstChild("_DialogController")
    if ctrl and ctrl:IsA("BindableFunction") then
        local npcModel = nil
        if data.npcName and workspace:FindFirstChild(data.npcName) then
            local candidate = workspace:FindFirstChild(data.npcName)
            if candidate:IsA("Model") then npcModel = candidate end
        end
        ctrl:Invoke({speaker = speaker, lines = lines, npcModel = npcModel, cameraPath = nil, perLine = data.perLine})
        return
    end
    -- Fallback to simple label
    local portraitImg = nil
    pcall(function() local mod = ReplicatedStorage:FindFirstChild("IgnisiaAssets") if mod then local ok,m = pcall(require, mod) if ok and type(m)=="table" and m.npcDecals and m.npcDecals[speaker] and m.npcDecals[speaker]~="" then portraitImg = m.npcDecals[speaker] end end end)
    if portraitImg then portrait.Image = portraitImg portrait.Visible = true end
    for _,t in ipairs(lines) do dialog.Text = (speaker ~= "" and (speaker..": ") or "")..t dialog.Visible = true task.wait(2.2) end
    dialog.Visible = false portrait.Visible = false
end)

-- Ignite effect feedback
effectEvent.OnClientEvent:Connect(function(data)
    if data.type ~= "ignite" then return end
    local pe = Instance.new("ParticleEmitter") pe.Rate = 150 pe.Lifetime = NumberRange.new(0.6,1) pe.Speed = NumberRange.new(4,9) pe.Parent = spark task.delay(0.8, function() pe.Enabled=false task.wait(1) pcall(function() pe:Destroy() end) end)
    local s = Instance.new("Sound") s.SoundId = assets.sounds and assets.sounds.chime or "" s.Volume = 1 s.Parent = workspace s:Play() game:GetService("Debris"):AddItem(s,3)
end)
]]
ensureLocalScript("SparkClient", SPARK_CLIENT_SOURCE)

-- Optional small UI wire-up (vignette)
local UI_WIREUP_SOURCE = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):FindFirstChild("IgnisiaUI")
if not gui then return end
local ok, assets = pcall(function() return require(ReplicatedStorage:WaitForChild("IgnisiaAssets")) end)
assets = ok and assets or {}
local vignId = assets.ui and assets.ui.vignetteImage or ""
if vignId ~= "" then
    local vign = gui:FindFirstChild("IgnisiaVignette") or Instance.new("ImageLabel")
    vign.Name = "IgnisiaVignette" vign.Size = UDim2.new(1,0,1,0) vign.Position = UDim2.new(0,0,0,0) vign.BackgroundTransparency = 1 vign.Image = vignId vign.ImageTransparency = 1 vign.ZIndex = 50 vign.Parent = gui
end

-- Cinematic Dialog UI (viewport portrait + typewriter + next button)
local DialogRoot = gui:FindFirstChild("CinematicDialog") or Instance.new("Frame")
DialogRoot.Name = "CinematicDialog"
DialogRoot.Size = UDim2.new(0.6,0,0.28,0)
DialogRoot.Position = UDim2.new(0.2,0,0.68,0)
DialogRoot.BackgroundColor3 = Color3.fromRGB(10,10,10)
DialogRoot.BackgroundTransparency = 0.2
DialogRoot.Visible = false
DialogRoot.Parent = gui

-- letterbox bars for cinematic look
local TopBar = Instance.new("Frame") TopBar.Name = "TopLetterbox" TopBar.Size = UDim2.new(1,0,0,0) TopBar.Position = UDim2.new(0,0,0,0) TopBar.BackgroundColor3 = Color3.new(0,0,0) TopBar.ZIndex = 100 TopBar.Parent = gui
local BottomBar = Instance.new("Frame") BottomBar.Name = "BottomLetterbox" BottomBar.Size = UDim2.new(1,0,0,0) BottomBar.Position = UDim2.new(0,0,1,0) BottomBar.AnchorPoint = Vector2.new(0,1) BottomBar.BackgroundColor3 = Color3.new(0,0,0) BottomBar.ZIndex = 100 BottomBar.Parent = gui

local uic = Instance.new("UICorner") uic.CornerRadius = UDim.new(0,12) uic.Parent = DialogRoot

local Viewport = Instance.new("ViewportFrame")
Viewport.Name = "NPCViewport"
Viewport.Size = UDim2.new(0.28,0,1,0)
Viewport.Position = UDim2.new(0,0,0,0)
Viewport.BackgroundTransparency = 1
Viewport.Parent = DialogRoot
local vpCam = Instance.new("Camera") vpCam.CFrame = CFrame.new(Vector3.new(0,2,6), Vector3.new(0,2,0)) vpCam.Parent = Viewport Viewport.CurrentCamera = vpCam

local TextHolder = Instance.new("TextLabel")
TextHolder.Name = "DialogText"
TextHolder.RichText = true
TextHolder.TextWrapped = true
TextHolder.TextXAlignment = Enum.TextXAlignment.Left
TextHolder.TextYAlignment = Enum.TextYAlignment.Top
TextHolder.Size = UDim2.new(0.62,0,0.7,0)
TextHolder.Position = UDim2.new(0.32,0,0.12,0)
TextHolder.BackgroundTransparency = 1
TextHolder.TextColor3 = Color3.new(1,1,1)
TextHolder.TextScaled = true
TextHolder.Parent = DialogRoot

local NextBtn = Instance.new("TextButton")
NextBtn.Name = "NextButton"
NextBtn.Size = UDim2.new(0.18,0,0.22,0)
NextBtn.Position = UDim2.new(0.8,0,0.74,0)
NextBtn.Text = ">>"
NextBtn.TextScaled = true
NextBtn.BackgroundColor3 = Color3.fromRGB(40,20,10)
NextBtn.TextColor3 = Color3.fromRGB(255,255,255)
NextBtn.Parent = DialogRoot
local uic2 = Instance.new("UICorner") uic2.CornerRadius = UDim.new(0,8) uic2.Parent = NextBtn

local function typewriterSet(text)
    -- RichText typewriter with active letter scaling
    local full = text
    local i = 0
    while i < #full do
        i += 1
        local shown = string.sub(full, 1, i)
        local nextChar = string.sub(full, i+1, i+1)
        if nextChar and nextChar ~= "" then
            TextHolder.Text = shown .. string.format("<font size=42>%s</font>", nextChar)
        else
            TextHolder.Text = shown
        end
        task.wait(0.025)
    end
end

-- Expose a function on the ScreenGui to drive cinematic dialog
if not gui:FindFirstChild("_DialogController") then
    local ctrl = Instance.new("BindableFunction")
    ctrl.Name = "_DialogController"
    ctrl.Parent = gui
end

-- Animate camera helper (basic path of 2 points)
local function cinematicPan(startCF, endCF, dur)
    local camera = workspace.CurrentCamera if not camera then return end
    camera.CameraType = Enum.CameraType.Scriptable
    local t = 0
    while t < dur do
        t += game:GetService("RunService").RenderStepped:Wait()
        local a = math.clamp(t/dur, 0, 1)
        camera.CFrame = startCF:Lerp(endCF, a)
    end
end

-- open/close animation for dialog and letterbox
local TweenService = game:GetService("TweenService")
local function openCinematic()
    DialogRoot.Visible = true
    TopBar:TweenSize(UDim2.new(1,0,0.07,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.25, true)
    BottomBar:TweenSize(UDim2.new(1,0,0.07,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.25, true)
end
local function closeCinematic()
    TopBar:TweenSize(UDim2.new(1,0,0,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.25, true)
    BottomBar:TweenSize(UDim2.new(1,0,0,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.25, true)
    task.delay(0.26, function() DialogRoot.Visible = false end)
end

gui._DialogController.OnInvoke = function(payload)
    -- payload: { speaker, lines = {"...","..."}, npcModel, cameraPath = {startCF,endCF,dur} }
    openCinematic()
    -- viewport: clone npcModel if present
    Viewport:ClearAllChildren() Viewport.CurrentCamera = vpCam vpCam.Parent = Viewport
    if payload and payload.npcModel and payload.npcModel:IsA("Model") then
        local clone = payload.npcModel:Clone() clone.Parent = Viewport
        local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
        if primary then
            local c = primary.CFrame
            vpCam.CFrame = CFrame.new(c.Position + Vector3.new(0,1.8,6), c.Position + Vector3.new(0,1.5,0))
        end
    end
    if payload and payload.cameraPath and typeof(payload.cameraPath[1]) == "CFrame" then
        task.spawn(function() cinematicPan(payload.cameraPath[1], payload.cameraPath[2], payload.cameraPath[3] or 3) end)
    end
    local idx = 1
    local function showLine()
        local line = payload.lines[idx]
        if not line then closeCinematic() return end
        -- play per-line npc animation if provided (server can drive real NPC via NPCAnimEvent)
        local per = payload.perLine and payload.perLine[idx]
        if per and per.animId and per.animId ~= "" and payload.npcModel and payload.npcModel:FindFirstChildOfClass("Humanoid") then
            local hum = payload.npcModel:FindFirstChildOfClass("Humanoid")
            local anim = Instance.new("Animation") anim.AnimationId = per.animId
            local track = hum:LoadAnimation(anim) track:Play()
        end
        typewriterSet(line)
        -- optional: trigger server to animate real NPC
        if per and per.animId and per.animId ~= "" and payload.npcModel and payload.npcModel.Name then
            pcall(function() ReplicatedStorage:WaitForChild("NPCAnimEvent"):FireServer({name = payload.npcModel.Name, animId = per.animId}) end)
        end
    end
    NextBtn.MouseButton1Click:Connect(function()
        idx += 1
        showLine()
    end)
    showLine()
end
]]
ensureLocalScript("UIWireUp", UI_WIREUP_SOURCE)

print("MVPInstaller completed: ReplicatedStorage, ServerScriptService, StarterPlayerScripts, and Workspace are set up.")

