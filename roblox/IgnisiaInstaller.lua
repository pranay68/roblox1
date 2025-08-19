-- IgnisiaInstaller.lua
-- Run this script inside Roblox Studio (Command Bar or a Script) to auto-create the Ignisia setup.
-- It checks for Studio mode and will not run in Play mode.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
    error("IgnisiaInstaller must be run in Roblox Studio")
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts") or Instance.new("StarterPlayerScripts")

-- Helper to create ModuleScript in ReplicatedStorage
local function ensureModuleScript(name, source)
    local existing = ReplicatedStorage:FindFirstChild(name)
    if existing and existing:IsA("ModuleScript") then
        return existing
    end
    local m = Instance.new("ModuleScript")
    m.Name = name
    m.Source = source
    m.Parent = ReplicatedStorage
    return m
end

-- Create IgnisiaAssets ModuleScript (uses default assets in this repo)
local assetsSource = [[
-- IgnisiaAssets (auto-created)
local assets = {}
assets.sounds = {
    ambient = "rbxassetid://18435252",
    crackle = "rbxassetid://18435253",
    hum = "rbxassetid://18435254",
    chime = "rbxassetid://18435255",
}
assets.kneelAnimation = "rbxassetid://0"
assets.auraParticleTexture = ""
assets.tuning = { NEAR_RADIUS = 8, STILL_VEL_THRESHOLD = 1.2, TARGET_SECONDS = 3.5 }
return assets
]]

ensureModuleScript("IgnisiaAssets", assetsSource)

-- Ensure RemoteEvents
local function ensureRemote(name)
    local existing = ReplicatedStorage:FindFirstChild(name)
    if existing and existing:IsA("RemoteEvent") then return existing end
    local r = Instance.new("RemoteEvent")
    r.Name = name
    r.Parent = ReplicatedStorage
    return r
end

ensureRemote("SparkEvent")
ensureRemote("IgnisiaEffectEvent")
ensureRemote("PlayerPrefsEvent")
-- ensure profiler remote
local prof = ReplicatedStorage:FindFirstChild("ProfilerEvent")
if not prof then
    local p = Instance.new("RemoteEvent") p.Name = "ProfilerEvent" p.Parent = ReplicatedStorage
end

-- Create Spark part in Workspace if missing
local spark = workspace:FindFirstChild("Spark")
if not spark then
    spark = Instance.new("Part")
    spark.Name = "Spark"
    spark.Size = Vector3.new(6,1,6)
    spark.Anchored = true
    spark.Position = Vector3.new(0,2,0)
    spark.Parent = workspace

    local pl = Instance.new("PointLight")
    pl.Color = Color3.fromRGB(255,150,80)
    pl.Range = 12
    pl.Parent = spark

    local pe = Instance.new("ParticleEmitter")
    pe.Rate = 12
    pe.Lifetime = NumberRange.new(1,2)
    pe.Speed = NumberRange.new(0.6,1.4)
    pe.Parent = spark

    -- add a ProximityPrompt for kneeling/interaction
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Touch the Spark?"
    prompt.ObjectText = "Spark"
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 8
    prompt.HoldDuration = 0
    prompt.Parent = spark
end

-- Helper to create a Script in ServerScriptService if missing
local function ensureServerScript(name, source)
    local existing = ServerScriptService:FindFirstChild(name)
    if existing and existing:IsA("Script") then return existing end
    local s = Instance.new("Script")
    s.Name = name
    s.Source = source
    s.Parent = ServerScriptService
    return s
end

-- SparkServer script source (basic)
local serverSource = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local assets = {}
do
    local assetsModule = ReplicatedStorage:FindFirstChild("IgnisiaAssets")
    if assetsModule and assetsModule:IsA("ModuleScript") then
        local ok, m = pcall(require, assetsModule)
        if ok and type(m) == "table" then assets = m end
    end
end
local sparkEvent = ReplicatedStorage:FindFirstChild("SparkEvent")
local effectEvent = ReplicatedStorage:FindFirstChild("IgnisiaEffectEvent")
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
    p.Texture = assets.auraParticleTexture or ""
    p.Color = ColorSequence.new(Color3.fromRGB(255,170,80))
    p.Rate = 8
    p.Lifetime = NumberRange.new(1,1.8)
    p.Speed = NumberRange.new(0.3,0.9)
    p.Parent = attachment
end
sparkEvent.OnServerEvent:Connect(function(player, action, reflectionChoice)
    if action ~= "ignite" then return end
    if player:FindFirstChild("HasSpark") and player.HasSpark.Value == true then return end
    local has = Instance.new("BoolValue")
    has.Name = "HasSpark"
    has.Value = true
    has.Parent = player
    if reflectionChoice then
        local s = Instance.new("StringValue")
        s.Name = "ReflectionChoice"
        s.Value = tostring(reflectionChoice)
        s.Parent = player
    end
    attachAuraToCharacter(player)
    effectEvent:FireAllClients({type = "ignite", player = player})
    player.CharacterAdded:Connect(function()
        wait(0.5)
        attachAuraToCharacter(player)
    end)
end)
]]

ensureServerScript("SparkServer", serverSource)
-- Ensure SaveService and ZoneGate exist
local saveSrc = [[
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local STORE = DataStoreService:GetDataStore("IgnisiaPlayerData_v1")
local function getKey(userId) return "player_"..tostring(userId) end
Players.PlayerAdded:Connect(function(player)
    local ok, data = pcall(function() return STORE:GetAsync(getKey(player.UserId)) end)
    if ok and data then
        if data.HasSpark then local v = Instance.new("BoolValue") v.Name = "HasSpark" v.Value = true v.Parent = player end
        if data.ReflectionChoice then local s = Instance.new("StringValue") s.Name = "ReflectionChoice" s.Value = tostring(data.ReflectionChoice) s.Parent = player end
    end
end)
Players.PlayerRemoving:Connect(function(player)
    local payload = {}
    if player:FindFirstChild("HasSpark") and player.HasSpark.Value then payload.HasSpark = true end
    if player:FindFirstChild("ReflectionChoice") and player.ReflectionChoice.Value then payload.ReflectionChoice = player.ReflectionChoice.Value end
    pcall(function() STORE:SetAsync(getKey(player.UserId), payload) end)
end)
]]
ensureServerScript("SaveService", saveSrc)

-- Create Zone2 gate part and script
local zoneGatePart = workspace:FindFirstChild("Zone2Gate")
if not zoneGatePart then
    zoneGatePart = Instance.new("Part")
    zoneGatePart.Name = "Zone2Gate"
    zoneGatePart.Size = Vector3.new(8,3,1)
    zoneGatePart.Position = Vector3.new(0,3,40)
    zoneGatePart.Anchored = true
    zoneGatePart.Parent = workspace
end
-- attach ZoneGate script
local zoneGateSrc = [[
local TELEPORT_POS = Vector3.new(0,5,120)
local part = script.Parent
local Players = game:GetService("Players")
local proximity = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt", part)
proximity.ActionText = "Enter Lensveil"; proximity.ObjectText = "Zone Gate"; proximity.HoldDuration = 0.5; proximity.MaxActivationDistance = 8
proximity.Triggered:Connect(function(player)
    if player:FindFirstChild("HasSpark") and player.HasSpark.Value == true then
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char:SetPrimaryPartCFrame(CFrame.new(0,5,120))
        end
    else
        local msg = Instance.new("Message") msg.Text = "You need the First Flame to enter." msg.Parent = player.PlayerGui delay(2, function() pcall(function() msg:Destroy() end) end)
    end
end)
]]
ensureServerScript("ZoneGate", zoneGateSrc)

-- Create StarterPlayerScripts LocalScript
local function ensureLocalScript(name, source)
    local existing = StarterPlayerScripts:FindFirstChild(name)
    if existing and existing:IsA("LocalScript") then return existing end
    local s = Instance.new("LocalScript")
    s.Name = name
    s.Source = source
    s.Parent = StarterPlayerScripts
    return s
end

local clientSource = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sparkEvent = ReplicatedStorage:WaitForChild("SparkEvent")
local effectEvent = ReplicatedStorage:WaitForChild("IgnisiaEffectEvent")
local assets = {}
do
    local assetsModule = ReplicatedStorage:FindFirstChild("IgnisiaAssets")
    if assetsModule and assetsModule:IsA("ModuleScript") then
        local ok, m = pcall(require, assetsModule)
        if ok and type(m) == "table" then assets = m end
    end
end
assets.tuning = assets.tuning or {}
local NEAR_RADIUS = assets.tuning.NEAR_RADIUS or 8
local STILL_VEL_THRESHOLD = assets.tuning.STILL_VEL_THRESHOLD or 1.2
local TARGET_SECONDS = assets.tuning.TARGET_SECONDS or 3.5
local gui = playerGui:FindFirstChild("IgnisiaUI")
if not gui then
    gui = Instance.new("ScreenGui")
    gui.Name = "IgnisiaUI"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui
    local dialog = Instance.new("TextLabel")
    dialog.Name = "DialogLabel"
    dialog.Size = UDim2.new(0.6,0,0.12,0)
    dialog.Position = UDim2.new(0.2,0,0.08,0)
    dialog.BackgroundTransparency = 0.5
    dialog.TextColor3 = Color3.new(1,1,1)
    dialog.TextScaled = true
    dialog.Visible = false
    dialog.Parent = gui
    local bar = Instance.new("Frame")
    bar.Name = "PatienceBar"
    bar.Size = UDim2.new(0.4,0,0.035,0)
    bar.Position = UDim2.new(0.3,0,0.9,0)
    bar.BackgroundColor3 = Color3.fromRGB(40,40,40)
    bar.Parent = gui
    local fill = Instance.new("Frame")
    fill.Name = "PatienceFill"
    fill.Size = UDim2.new(0,0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(255,170,80)
    fill.Parent = bar
    local reflection = Instance.new("Frame")
    reflection.Name = "ReflectionGui"
    reflection.Size = UDim2.new(0.4,0,0.25,0)
    reflection.Position = UDim2.new(0.3,0,0.4,0)
    reflection.BackgroundColor3 = Color3.fromRGB(20,20,20)
    reflection.Visible = false
    reflection.Parent = gui
    local btn1 = Instance.new("TextButton")
    btn1.Name = "Choice1"
    btn1.Size = UDim2.new(0.9,0,0.25,0)
    btn1.Position = UDim2.new(0.05,0,0.05,0)
    btn1.Text = "🧡 Like something I’d been waiting for"
    btn1.BackgroundColor3 = Color3.fromRGB(40,20,10)
    btn1.TextColor3 = Color3.fromRGB(255,220,200)
    btn1.Parent = reflection
    local uic1 = Instance.new("UICorner")
    uic1.CornerRadius = UDim.new(0,8)
    uic1.Parent = btn1
    local grad1 = Instance.new("UIGradient")
    grad1.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(255,140,80)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255,200,140))}
    grad1.Parent = btn1

    local btn2 = Instance.new("TextButton")
    btn2.Name = "Choice2"
    btn2.Size = UDim2.new(0.9,0,0.25,0)
    btn2.Position = UDim2.new(0.05,0,0.37,0)
    btn2.Text = "🔥 Like I’m not afraid of my fire"
    btn2.BackgroundColor3 = Color3.fromRGB(50,10,10)
    btn2.TextColor3 = Color3.fromRGB(255,200,180)
    btn2.Parent = reflection
    local uic2 = Instance.new("UICorner")
    uic2.CornerRadius = UDim.new(0,8)
    uic2.Parent = btn2
    local grad2 = Instance.new("UIGradient")
    grad2.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(220,80,20)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255,160,60))}
    grad2.Parent = btn2

    local btn3 = Instance.new("TextButton")
    btn3.Name = "Choice3"
    btn3.Size = UDim2.new(0.9,0,0.25,0)
    btn3.Position = UDim2.new(0.05,0,0.69,0)
    btn3.Text = "🌱 Like maybe I’m not broken"
    btn3.BackgroundColor3 = Color3.fromRGB(20,40,20)
    btn3.TextColor3 = Color3.fromRGB(220,255,220)
    btn3.Parent = reflection
    local uic3 = Instance.new("UICorner")
    uic3.CornerRadius = UDim.new(0,8)
    uic3.Parent = btn3
    local grad3 = Instance.new("UIGradient")
    grad3.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(120,200,120)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200,255,200))}
    grad3.Parent = btn3
end
local dialogLabel = gui:WaitForChild("DialogLabel")
local patienceBar = gui:WaitForChild("PatienceBar")
local patienceFill = patienceBar:WaitForChild("PatienceFill")
local reflectionGui = gui:WaitForChild("ReflectionGui")
local spark = workspace:FindFirstChild("Spark")
if not spark then
    spark = Instance.new("Part")
    spark.Name = "Spark"
    spark.Size = Vector3.new(6,1,6)
    spark.Anchored = true
    spark.Position = Vector3.new(0,2,0)
    spark.Parent = workspace
    local pl = Instance.new("PointLight")
    pl.Color = Color3.fromRGB(255,150,80)
    pl.Range = 12
    pl.Parent = spark
    local pe = Instance.new("ParticleEmitter")
    pe.Rate = 12
    pe.Lifetime = NumberRange.new(1,2)
    pe.Speed = NumberRange.new(0.6,1.4)
    pe.Parent = spark
end
-- ensure a ProximityPrompt exists (for kneel/interaction)
local prompt = spark:FindFirstChildOfClass("ProximityPrompt")
if not prompt then
    prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Touch the Spark?"
    prompt.ObjectText = "Spark"
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 8
    prompt.HoldDuration = 0
    prompt.Parent = spark
end

-- kneel/interaction state: player must trigger the prompt to begin patient interaction
local interactionActive = false
local function onPromptTriggered()
    -- play kneel animation if available
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid and assets.kneelAnimation and assets.kneelAnimation ~= "" then
            local anim = Instance.new("Animation")
            anim.AnimationId = assets.kneelAnimation
            local track = humanoid:LoadAnimation(anim)
            track:Play()
            -- optional: stop after 2 seconds
            delay(2, function()
                pcall(function() track:Stop() end)
            end)
        end
    end
    interactionActive = true
    -- small grace period so players can't spam-trigger repeatedly
    delay(6, function() interactionActive = false end)
end
prompt.Triggered:Connect(onPromptTriggered)
local npcLines = {
    {name="Alex", text="I notice it first."},
    {name="Alexis", text="Heh, it's glowing — dramatic, right?"},
    {name="Solari", text="It's been here, waiting."},
    {name="Tripp", text="Ooo, can we make it explode?"},
    {name="Trace", text="Do you think it already knows you?"},
    {name="Emerson", text="... (shows a glowing drawing of a flame)"},
    {name="Donna", text="Sparks show when you're ready."},
}
local function playCinematicOnce()
    local camera = workspace.CurrentCamera
    if not camera then return end
    camera.CameraType = Enum.CameraType.Scriptable
    local startCF = CFrame.new(spark.Position + Vector3.new(0, 30, -60), spark.Position)
    local endCF = CFrame.new(spark.Position + Vector3.new(0, 8, -18), spark.Position)
    local t = 0
    local dur = 4
    while t < dur do
        t = t + RunService.RenderStepped:Wait()
        local alpha = math.clamp(t/dur, 0, 1)
        camera.CFrame = startCF:Lerp(endCF, alpha)
        RunService.RenderStepped:Wait()
    end
    for _,entry in ipairs(npcLines) do
        dialogLabel.Text = entry.name..": "..entry.text
        dialogLabel.Visible = true
        wait(2.2)
    end
    dialogLabel.Visible = false
    camera.CameraType = Enum.CameraType.Custom
end
local checkInterval = 0.1
local function setPatienceFill(progress)
    progress = math.clamp(progress, 0, 1)
    local newSize = UDim2.new(progress, 0, 1, 0)
    patienceFill.Size = newSize
end
local function monitorSpark()
    local accumulated = 0
    while true do
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - spark.Position).Magnitude
                local near = dist <= NEAR_RADIUS
                local vel = root.Velocity.Magnitude
                -- only accumulate patience when the player has triggered the prompt (kneel) or is already interacting
                if interactionActive and near and vel <= STILL_VEL_THRESHOLD then
                    accumulated = accumulated + checkInterval
                    setPatienceFill(accumulated / TARGET_SECONDS)
                else
                    if near then
                        accumulated = math.max(0, accumulated - checkInterval*1.5)
                        setPatienceFill(accumulated / TARGET_SECONDS)
                    else
                        accumulated = math.max(0, accumulated - checkInterval*2)
                        setPatienceFill(accumulated / TARGET_SECONDS)
                    end
                end
                if accumulated >= TARGET_SECONDS then
                    dialogLabel.Text = "You feel a warm whoosh as the spark responds..."
                    dialogLabel.Visible = true
                    wait(1.4)
                    dialogLabel.Visible = false
                    reflectionGui.Visible = true
                    while reflectionGui.Visible do
                        RunService.RenderStepped:Wait()
                    end
                    local chosen = reflectionGui:GetAttribute("ChosenReflection") or ""
                    sparkEvent:FireServer("ignite", chosen)
                    accumulated = 0
                    setPatienceFill(0)
                end
            end
        end
        wait(checkInterval)
    end
end
local function wireReflectionButtons()
    local c1 = reflectionGui:WaitForChild("Choice1")
    local c2 = reflectionGui:WaitForChild("Choice2")
    local c3 = reflectionGui:WaitForChild("Choice3")
    local function choose(text)
        reflectionGui:SetAttribute("ChosenReflection", text)
        reflectionGui.Visible = false
        dialogLabel.Text = "You chose: "..text
        dialogLabel.Visible = true
        delay(1.4, function() dialogLabel.Visible = false end)
    end
    -- button tweens for polish when hovered/clicked
    local TweenService = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local function wireButton(btn, text)
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, tweenInfo, {Size = btn.Size + UDim2.new(0,6,0,6)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, tweenInfo, {Size = btn.Size - UDim2.new(0,6,0,6)}):Play()
        end)
        btn.MouseButton1Click:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.06), {BackgroundTransparency = 0.4}):Play()
            choose(text)
        end)
    end

    wireButton(c1, "🧡 Like something I’d been waiting for")
    wireButton(c2, "🔥 Like I’m not afraid of my fire")
    wireButton(c3, "🌱 Like maybe I’m not broken")
end
effectEvent.OnClientEvent:Connect(function(data)
    if data.type == "ignite" then
        local pe = Instance.new("ParticleEmitter")
        pe.Rate = 150
        pe.Lifetime = NumberRange.new(0.6,1)
        pe.Speed = NumberRange.new(4,9)
        pe.Parent = spark
        delay(0.8, function() pe.Enabled = false; wait(1); pcall(function() pe:Destroy() end) end)
        local s = Instance.new("Sound")
        s.SoundId = assets.sounds and assets.sounds.chime or ""
        s.Volume = 1
        s.Parent = workspace
        s:Play()
        game:GetService("Debris"):AddItem(s, 3)
    end
end)
player.CharacterAdded:Connect(function()
    wait(0.5)
    if not player:GetAttribute("CinematicPlayed") then
        player:SetAttribute("CinematicPlayed", true)
        pcall(playCinematicOnce)
    end
end)
wireReflectionButtons()
spawn(monitorSpark)
]]

ensureLocalScript("SparkClient", clientSource)

-- Create a simple plugin file for one-click installation (LocalPlugin). Save as a local plugin via Studio.
local pluginSource = [[
local toolbar = plugin:CreateToolbar("Ignisia")
local button = toolbar:CreateButton("Install Ignisia", "Install Ignisia Zone 1 into the place", "rbxassetid://0")
button.Click:Connect(function()
    -- run the installer code (simply call the script in ServerStorage if present)
    local installer = script -- assumes this plugin's script contains the installer; real workflow requires packaging
    print("Ignisia plugin run: please run IgnisiaInstaller in the Command Bar to create objects.")
end)
]]

-- Write plugin stub to ServerStorage for developer convenience (not an actual installed plugin)
local ServerStorage = game:GetService("ServerStorage")
if not ServerStorage:FindFirstChild("IgnisiaPluginStub") then
    local s = Instance.new("ModuleScript")
    s.Name = "IgnisiaPluginStub"
    s.Source = pluginSource
    s.Parent = ServerStorage
end

print("Ignisia installer completed. Check ReplicatedStorage, ServerScriptService, StarterPlayerScripts, and Workspace for new objects.")


