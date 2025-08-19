-- IgnisiaPluginScript.lua
-- Paste this into a new PluginScript in Roblox Studio and Save as Local Plugin.
-- It provides a toolbar button "Install Ignisia" which injects the Ignisia assets and scripts into the current place.

local toolbar = plugin:CreateToolbar("Ignisia Tools")
local button = toolbar:CreateButton("Install Ignisia", "Install Ignisia Zone 1 into this place", "rbxassetid://0")

local function ensureFolder(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing then return existing end
    local f = Instance.new("Folder")
    f.Name = name
    f.Parent = parent
    return f
end

local function ensureModule(parent, name, source)
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA("ModuleScript") then
        existing.Source = source
        return existing
    end
    local m = Instance.new("ModuleScript")
    m.Name = name
    m.Source = source
    m.Parent = parent
    return m
end

local function ensureRemote(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA("RemoteEvent") then return existing end
    local r = Instance.new("RemoteEvent")
    r.Name = name
    r.Parent = parent
    return r
end

local function ensureScript(parent, name, source)
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA("Script") then
        existing.Source = source
        return existing
    end
    local s = Instance.new("Script")
    s.Name = name
    s.Source = source
    s.Parent = parent
    return s
end

local function ensureLocalScript(parent, name, source)
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA("LocalScript") then
        existing.Source = source
        return existing
    end
    local s = Instance.new("LocalScript")
    s.Name = name
    s.Source = source
    s.Parent = parent
    return s
end

local function createIgnisia()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ServerScriptService = game:GetService("ServerScriptService")
    local StarterPlayer = game:GetService("StarterPlayer")
    local StarterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts") or Instance.new("StarterPlayerScripts")
    StarterPlayerScripts.Parent = StarterPlayer

    -- Create IgnisiaAssets ModuleScript
    local assetsSource = [[
-- IgnisiaAssets (created by plugin)
local assets = {}
assets.sounds = { ambient = "rbxassetid://451776625", crackle = "rbxassetid://705787045", hum = "rbxassetid://171186876", chime = "rbxassetid://180204501" }
assets.kneelAnimation = "rbxassetid://71201518567477"
assets.auraParticleTexture = ""
assets.ui = { vignetteImage = "rbxassetid://3570695787", reflectionButtonIcon = "rbxassetid://3570695787" }
assets.tuning = { NEAR_RADIUS = 8, STILL_VEL_THRESHOLD = 1.2, TARGET_SECONDS = 3.5 }
return assets
]]
    ensureModule(ReplicatedStorage, "IgnisiaAssets", assetsSource)

    -- Remotes
    ensureRemote(ReplicatedStorage, "SparkEvent")
    ensureRemote(ReplicatedStorage, "IgnisiaEffectEvent")

    -- Create Spark part
    local spark = workspace:FindFirstChild("Spark")
    if not spark then
        spark = Instance.new("Part")
        spark.Name = "Spark"
        spark.Size = Vector3.new(6,1,6)
        spark.Anchored = true
        spark.Position = Vector3.new(0,2,0)
        spark.Parent = workspace
        local pl = Instance.new("PointLight") pl.Color = Color3.fromRGB(255,150,80); pl.Range = 12; pl.Parent = spark
        local pe = Instance.new("ParticleEmitter") pe.Rate = 12; pe.Lifetime = NumberRange.new(1,2); pe.Speed = NumberRange.new(0.6,1.4); pe.Parent = spark
        local prompt = Instance.new("ProximityPrompt") prompt.ActionText = "Touch the Spark?"; prompt.ObjectText = "Spark"; prompt.RequiresLineOfSight = false; prompt.MaxActivationDistance = 8; prompt.HoldDuration = 0; prompt.Parent = spark
    end

    -- Server script source (compact)
    local serverSrc = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local assets = {}
do local m = ReplicatedStorage:FindFirstChild("IgnisiaAssets") if m then pcall(function() assets = require(m) end) end end
local sparkEvent = ReplicatedStorage:FindFirstChild("SparkEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
sparkEvent.Name = "SparkEvent"
local effectEvent = ReplicatedStorage:FindFirstChild("IgnisiaEffectEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
effectEvent.Name = "IgnisiaEffectEvent"
local function attachAuraToCharacter(player)
    local character = player.Character if not character then return end
    if character:FindFirstChild("_IgnisiaAura") then return end
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart")
    if not root then return end
    local auraFolder = Instance.new("Folder") auraFolder.Name = "_IgnisiaAura" auraFolder.Parent = character
    local attachment = Instance.new("Attachment") attachment.Name = "IgnisiaAuraAttachment" attachment.Parent = root
    local p = Instance.new("ParticleEmitter") p.Name = "IgnisiaAuraParticles" p.Texture = assets.auraParticleTexture or "" p.Color = ColorSequence.new(Color3.fromRGB(255,170,80)) p.Rate = 8 p.Lifetime = NumberRange.new(1,1.8) p.Speed = NumberRange.new(0.3,0.9) p.Parent = attachment
end
sparkEvent.OnServerEvent:Connect(function(player, action, reflectionChoice)
    if action ~= "ignite" then return end
    if player:FindFirstChild("HasSpark") and player.HasSpark.Value == true then return end
    local has = Instance.new("BoolValue") has.Name = "HasSpark" has.Value = true has.Parent = player
    if reflectionChoice then local s = Instance.new("StringValue") s.Name = "ReflectionChoice" s.Value = tostring(reflectionChoice) s.Parent = player end
    attachAuraToCharacter(player)
    effectEvent:FireAllClients({type = "ignite", player = player, reflection = reflectionChoice})
    player.CharacterAdded:Connect(function() wait(0.5) attachAuraToCharacter(player) end)
end)
]]
    ensureScript(ServerScriptService, "SparkServer", serverSrc)

    -- Client script source (compact)
    local clientSrc = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer; local playerGui = player:WaitForChild("PlayerGui")
local assets = {}
do local m = ReplicatedStorage:FindFirstChild("IgnisiaAssets") if m then pcall(function() assets = require(m) end) end end
assets.tuning = assets.tuning or {}
local NEAR_RADIUS = assets.tuning.NEAR_RADIUS or 8
local STILL_VEL_THRESHOLD = assets.tuning.STILL_VEL_THRESHOLD or 1.2
local TARGET_SECONDS = assets.tuning.TARGET_SECONDS or 3.5
local spark = workspace:FindFirstChild("Spark")
-- simple UI+interaction will be created by installer if missing; rely on existing scripts in place
local sparkEvent = ReplicatedStorage:WaitForChild("SparkEvent")
local effectEvent = ReplicatedStorage:WaitForChild("IgnisiaEffectEvent")
effectEvent.OnClientEvent:Connect(function(data)
    if data.type == "ignite" then
        -- brief camera bloom
        local camera = workspace.CurrentCamera
        if camera then local bloom = Instance.new("BloomEffect") bloom.Intensity = 0.6 bloom.Size = 24 bloom.Threshold = 0.5 bloom.Parent = camera delay(1.2, function() pcall(function() bloom:Destroy() end) end) end
    end
end)
]]
    ensureLocalScript(StarterPlayerScripts, "SparkClient", clientSrc)

    -- Feedback
    print("Ignisia installed into place. Run Play to test.")
end

button.Click:Connect(function()
    local confirm = plugin:CreateDockWidgetPluginGui("IgnisiaInstallConfirm", DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 200, 80, 200, 80))
    local frame = Instance.new("Frame") frame.Size = UDim2.new(1,0,1,0) frame.BackgroundColor3 = Color3.fromRGB(30,30,30) frame.Parent = confirm
    local label = Instance.new("TextLabel") label.Size = UDim2.new(1,0,0.6,0) label.Position = UDim2.new(0,0,0,0) label.Text = "Install Ignisia into this place?" label.TextColor3 = Color3.new(1,1,1) label.BackgroundTransparency = 1 label.Parent = frame
    local btn = Instance.new("TextButton") btn.Size = UDim2.new(0.45,0,0.3,0) btn.Position = UDim2.new(0.05,0,0.65,0) btn.Text = "Install" btn.Parent = frame
    local cancel = Instance.new("TextButton") cancel.Size = UDim2.new(0.45,0,0.3,0) cancel.Position = UDim2.new(0.5,0,0.65,0) cancel.Text = "Cancel" cancel.Parent = frame
    confirm.Enabled = true
    btn.MouseButton1Click:Connect(function()
        createIgnisia()
        confirm:Destroy()
    end)
    cancel.MouseButton1Click:Connect(function()
        confirm:Destroy()
    end)
end)

print("Ignisia Plugin script loaded. Use the Ignisia Tools toolbar to install.")


