-- SparkClient.lua
-- Place this LocalScript in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

-- try to load assets from ReplicatedStorage (optional)
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
assets.tuning = assets.tuning or {}

local NEAR_RADIUS = assets.tuning.NEAR_RADIUS or 8
local STILL_VEL_THRESHOLD = assets.tuning.STILL_VEL_THRESHOLD or 1.2
local TARGET_SECONDS = assets.tuning.TARGET_SECONDS or 3.5

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Ensure remote exists
local sparkEvent = ReplicatedStorage:FindFirstChild("SparkEvent")
local effectEvent = ReplicatedStorage:FindFirstChild("IgnisiaEffectEvent")
local revealEvent = ReplicatedStorage:FindFirstChild("RevealEvent")
local dialogEvent = ReplicatedStorage:FindFirstChild("DialogEvent")
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
if not revealEvent then
    revealEvent = Instance.new("RemoteEvent")
    revealEvent.Name = "RevealEvent"
    revealEvent.Parent = ReplicatedStorage
end
if not dialogEvent then
    dialogEvent = Instance.new("RemoteEvent")
    dialogEvent.Name = "DialogEvent"
    dialogEvent.Parent = ReplicatedStorage
end

-- Auto-create simple GUI if not present
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

    -- Portrait image for NPC dialogue (will be set if decal exists in ReplicatedStorage.NPCDecals)
    local portrait = Instance.new("ImageLabel")
    portrait.Name = "DialogPortrait"
    portrait.Size = UDim2.new(0,120,0,120)
    portrait.Position = UDim2.new(0.05,0,0.02,0)
    portrait.BackgroundTransparency = 1
    portrait.Visible = false
    portrait.Parent = gui

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
    btn1.Parent = reflection

    local btn2 = Instance.new("TextButton")
    btn2.Name = "Choice2"
    btn2.Size = UDim2.new(0.9,0,0.25,0)
    btn2.Position = UDim2.new(0.05,0,0.37,0)
    btn2.Text = "🔥 Like I’m not afraid of my fire"
    btn2.Parent = reflection

    local btn3 = Instance.new("TextButton")
    btn3.Name = "Choice3"
    btn3.Size = UDim2.new(0.9,0,0.25,0)
    btn3.Position = UDim2.new(0.05,0,0.69,0)
    btn3.Text = "🌱 Like maybe I’m not broken"
    btn3.Parent = reflection
end

local dialogLabel = gui:WaitForChild("DialogLabel")
local patienceBar = gui:WaitForChild("PatienceBar")
local patienceFill = patienceBar:WaitForChild("PatienceFill")
local reflectionGui = gui:WaitForChild("ReflectionGui")
local portrait = gui:FindFirstChild("DialogPortrait")

-- Find spark part in workspace
local spark = workspace:FindFirstChild("Spark")
if not spark then
    -- create a placeholder spark at origin if missing
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

-- find spark components
local sparkLight = spark:FindFirstChildOfClass("PointLight")
local sparkEmitter = spark:FindFirstChildOfClass("ParticleEmitter")

-- helper to play local sound once or loop
local function playLocalSound(soundId, loop)
    if not soundId or soundId == "" then return nil end
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.Volume = 0.9
    s.Looped = loop and true or false
    s.Parent = workspace.CurrentCamera or workspace
    s:Play()
    if not loop then
        game:GetService("Debris"):AddItem(s, 6)
    end
    return s
end

-- Cinematic NPC lines
local npcLines = {
    {name="Alex", text="I notice it first."},
    {name="Alexis", text="Heh, it's glowing — dramatic, right?"},
    {name="Solari", text="It's been here, waiting."},
    {name="Tripp", text="Ooo, can we make it explode?"},
    {name="Trace", text="Do you think it already knows you?"},
    {name="Emerson", text="... (shows a glowing drawing of a flame)"},
    {name="Donna", text="Sparks show when you're ready."},
}

-- Reveal ability (client): press R to toggle a reveal pulse that shows illusions briefly
local REVEAL_COOLDOWN = 3.5
local lastRevealTime = -100

local function pulseReveal()
    local now = tick()
    if now - lastRevealTime < REVEAL_COOLDOWN then return end
    lastRevealTime = now
    -- tell server for validation/metrics
    pcall(function() revealEvent:FireServer() end)

    -- client-side effect: temporarily show tagged illusions and hint mirrors
    local duration = 1.25
    local endTime = now + duration

    -- Camera bloom pulse
    local lighting = game:GetService("Lighting")
    local bloom = lighting:FindFirstChild("IgnisiaRevealBloom")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "IgnisiaRevealBloom"
        bloom.Threshold = 1
        bloom.Intensity = 0.1
        bloom.Size = 24
        bloom.Parent = lighting
    end
    TweenService:Create(bloom, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Intensity = 1.1, Size = 56}):Play()
    delay(duration, function()
        TweenService:Create(bloom, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Intensity = 0.1, Size = 24}):Play()
    end)

    -- vignette flash if present
    local vign = nil
    pcall(function()
        vign = gui and gui:FindFirstChild("IgnisiaVignette")
    end)
    if vign then
        pcall(function()
            vign.ImageTransparency = 1
        end)
        TweenService:Create(vign, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {ImageTransparency = 0.25}):Play()
        delay(duration, function()
            TweenService:Create(vign, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {ImageTransparency = 1}):Play()
        end)
    end

    -- soft shimmer sound
    pcall(function()
        local sid = assets.sounds and assets.sounds.chime or ""
        if sid and sid ~= "" then
            local s = Instance.new("Sound")
            s.SoundId = sid
            s.Volume = 0.4
            s.Parent = workspace
            s:Play()
            game:GetService("Debris"):AddItem(s, 3)
        end
    end)

    -- temporarily make illusions visible
    local function highlightInstance(inst)
        if inst:IsA("BasePart") then
            local original = inst.LocalTransparencyModifier
            inst.LocalTransparencyModifier = 0.2
            -- add a selection box for stronger hint
            local sel = Instance.new("SelectionBox")
            sel.LineThickness = 0.03
            sel.Color3 = Color3.fromRGB(255, 220, 140)
            sel.Adornee = inst
            sel.Parent = inst
            delay(duration, function()
                pcall(function()
                    inst.LocalTransparencyModifier = original
                end)
                pcall(function() sel:Destroy() end)
            end)
        end
    end

    for _,inst in ipairs(CollectionService:GetTagged("Illusion")) do
        highlightInstance(inst)
    end
    for _,inst in ipairs(CollectionService:GetTagged("IllusionHint")) do
        highlightInstance(inst)
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.R then
        pulseReveal()
    end
end)

-- Dialog listener (e.g., Solari NPC)
dialogEvent.OnClientEvent:Connect(function(data)
    if not data then return end
    local lines = data.lines or {}
    local speaker = data.speaker or ""
    if #lines == 0 then return end
    -- optional portrait
    local portraitImg = nil
    pcall(function()
        local a = ReplicatedStorage:FindFirstChild("IgnisiaAssets")
        if a then
            local ok, m = pcall(require, a)
            if ok and type(m) == "table" and m.npcDecals and m.npcDecals[speaker] and m.npcDecals[speaker] ~= "" then
                portraitImg = m.npcDecals[speaker]
            end
        end
    end)
    if portraitImg and portrait then
        portrait.Image = portraitImg
        portrait.Visible = true
    end
    for _,text in ipairs(lines) do
        dialogLabel.Text = (speaker ~= "" and (speaker..": ") or "") .. tostring(text)
        dialogLabel.Visible = true
        wait(2.2)
    end
    dialogLabel.Visible = false
    if portrait then portrait.Visible = false end
end)

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
        -- set portrait if available from assets
        local portraitImg = nil
        pcall(function()
            local a = ReplicatedStorage:FindFirstChild("IgnisiaAssets")
            if a then
                local ok, m = pcall(require, a)
                if ok and type(m) == "table" and m.npcDecals and m.npcDecals[entry.name] and m.npcDecals[entry.name] ~= "" then
                    portraitImg = m.npcDecals[entry.name]
                end
            end
        end)
        if portraitImg and portrait then
            portrait.Image = portraitImg
            portrait.Visible = true
        else
            if portrait then portrait.Visible = false end
        end
        dialogLabel.Text = entry.name..": "..entry.text
        dialogLabel.Visible = true
        wait(2.2)
    end
    dialogLabel.Visible = false
    if portrait then portrait.Visible = false end
    camera.CameraType = Enum.CameraType.Custom
end

-- Apply color correction and sunrays if graphics enabled
local function applyPostProcessing()
    local camera = workspace.CurrentCamera
    if not camera then return end
    -- ColorCorrection
    if assets.graphics and assets.graphics.enableBloom then
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Saturation = 0.05
        cc.Contrast = 0.06
        cc.Parent = camera
        delay(6, function() pcall(function() cc:Destroy() end) end)
    end
end

applyPostProcessing()

-- Apply graphics quality based on player attribute (Low, Medium, High)
local function applyGraphicsQuality()
    local q = player:GetAttribute("GraphicsQuality") or "high"
    if q == "low" then
        if sparkEmitter then sparkEmitter.Rate = (sparkEmitter.Rate or 12) * 0.45 end
    elseif q == "medium" then
        if sparkEmitter then sparkEmitter.Rate = (sparkEmitter.Rate or 12) * 0.8 end
    else
        if sparkEmitter then sparkEmitter.Rate = (sparkEmitter.Rate or 12) * 1.0 end
    end
end

applyGraphicsQuality()

player:GetAttributeChangedSignal("GraphicsQuality"):Connect(applyGraphicsQuality)

-- Reveal ability UI and logic
local revealButton = nil
local revealCooldown = 6
local lastReveal = 0
local revealRemote = ReplicatedStorage:WaitForChild("RevealEvent")

local function createRevealButton()
    if gui:FindFirstChild("RevealButton") then return end
    revealButton = Instance.new("TextButton")
    revealButton.Name = "RevealButton"
    revealButton.Size = UDim2.new(0,140,0,44)
    revealButton.Position = UDim2.new(0.02,0,0.82,0)
    revealButton.Text = "Reveal"
    revealButton.TextScaled = true
    revealButton.BackgroundColor3 = Color3.fromRGB(40,20,10)
    revealButton.TextColor3 = Color3.new(1,1,1)
    revealButton.Parent = gui

    revealButton.MouseButton1Click:Connect(function()
        pulseReveal()
    end)
end

createRevealButton()

-- Patience mechanic
local checkInterval = 0.1
local function setPatienceFill(progress)
    progress = math.clamp(progress, 0, 1)
    local newSize = UDim2.new(progress, 0, 1, 0)
    patienceFill.Size = newSize
end

local function monitorSpark()
    local accumulated = 0
    local humSound = nil
    while true do
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - spark.Position).Magnitude
                local near = dist <= NEAR_RADIUS
                local vel = root.Velocity.Magnitude

                if near and vel <= STILL_VEL_THRESHOLD then
                    accumulated = accumulated + checkInterval
                    setPatienceFill(accumulated / TARGET_SECONDS)
                    -- visual feedback: pulse particles and light based on progress
                    local progress = math.clamp(accumulated / TARGET_SECONDS, 0, 1)
                    if sparkEmitter then
                        sparkEmitter.Rate = 12 + math.floor(progress * 80)
                        sparkEmitter.Size = NumberSequence.new(0.4 + progress*0.8)
                    end
                    if sparkLight then
                        sparkLight.Brightness = 2 + progress * 6
                        sparkLight.Range = 8 + progress * 12
                    end
                    if progress > 0.02 and not humSound then
                        humSound = playLocalSound(assets.sounds and assets.sounds.hum or "", true)
                    end
                    if humSound and progress < 0.02 then
                        pcall(function() humSound:Stop() end)
                        humSound = nil
                    end
                else
                    if near then
                        accumulated = math.max(0, accumulated - checkInterval*1.5)
                        setPatienceFill(accumulated / TARGET_SECONDS)
                        if sparkEmitter then sparkEmitter.Rate = math.max(6, sparkEmitter.Rate - 6) end
                        if sparkLight then sparkLight.Brightness = math.max(1, (sparkLight.Brightness or 1) - 0.6) end
                        if humSound then pcall(function() humSound.Volume = math.max(0, humSound.Volume - 0.06) end) end
                    else
                        accumulated = math.max(0, accumulated - checkInterval*2)
                        setPatienceFill(accumulated / TARGET_SECONDS)
                        if humSound then pcall(function() humSound:Stop() end); humSound = nil end
                    end
                end

                if accumulated >= TARGET_SECONDS then
                    dialogLabel.Text = "You feel a warm whoosh as the spark responds..."
                    dialogLabel.Visible = true
                    wait(1.4)
                    dialogLabel.Visible = false

                    reflectionGui.Visible = true

                    -- wait for player to pick
                    while reflectionGui.Visible do
                        RunService.RenderStepped:Wait()
                    end

                    local chosen = reflectionGui:GetAttribute("ChosenReflection") or ""
                    -- play ignition local feedback (burst + camera shake)
                    if sparkEmitter then
                        local burst = Instance.new("ParticleEmitter")
                        burst.Rate = 300
                        burst.Lifetime = NumberRange.new(0.5,1)
                        burst.Speed = NumberRange.new(6,12)
                        burst.Parent = spark
                        delay(0.9, function() burst.Enabled = false; wait(1); pcall(function() burst:Destroy() end) end)
                    end
                    -- short camera shake
                    spawn(function()
                        local cam = workspace.CurrentCamera
                        if cam then
                            local original = cam.CFrame
                            for i=1,10 do
                                local offset = CFrame.new(math.random()-0.5, math.random()-0.5, math.random()-0.5) * 0.06
                                cam.CFrame = original * offset
                                wait(0.02)
                            end
                            cam.CFrame = original
                        end
                    end)

                    sparkEvent:FireServer("ignite", chosen)

                    accumulated = 0
                    setPatienceFill(0)
                    if humSound then pcall(function() humSound:Stop() end); humSound = nil end
                end
            end
        end
        wait(checkInterval)
    end
end

-- Wire reflection buttons
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

    c1.MouseButton1Click:Connect(function() choose("🧡 Like something I’d been waiting for") end)
    c2.MouseButton1Click:Connect(function() choose("🔥 Like I’m not afraid of my fire") end)
    c3.MouseButton1Click:Connect(function() choose("🌱 Like maybe I’m not broken") end)
end

-- Effect listener (server broadcast)
effectEvent.OnClientEvent:Connect(function(data)
    if data.type == "ignite" then
        -- small world effect: burst particles and chime
        local pe = Instance.new("ParticleEmitter")
        pe.Rate = 150
        pe.Lifetime = NumberRange.new(0.6,1)
        pe.Speed = NumberRange.new(4,9)
        pe.Parent = spark
        delay(0.8, function() pe.Enabled = false; wait(1); pcall(function() pe:Destroy() end) end)

        -- play chime
        local s = Instance.new("Sound")
        s.SoundId = assets.sounds and assets.sounds.chime or ""
        s.Volume = 1
        s.Parent = workspace
        s:Play()
        game:GetService("Debris"):AddItem(s, 3)

        -- Advanced VFX: light pulsing, bloom, vignette
        -- Light pulse on the spark' PointLight
        local pl = spark:FindFirstChildOfClass("PointLight")
        if pl then
            spawn(function()
                local initial = pl.Brightness or 1
                for i=1,6 do
                    pl.Brightness = initial + math.sin(i/6*math.pi)*6
                    wait(0.06)
                end
                pl.Brightness = initial
            end)
        end

        -- Bloom effect on camera
        local camera = workspace.CurrentCamera
        if camera then
            local bloom = Instance.new("BloomEffect")
            bloom.Intensity = 0.6
            bloom.Size = 24
            bloom.Threshold = 0.5
            bloom.Parent = camera
            delay(1.4, function()
                for t=1,10 do
                    bloom.Intensity = bloom.Intensity * 0.85
                    wait(0.06)
                end
                pcall(function() bloom:Destroy() end)
            end)
        end

        -- Screen-space vignette via ImageLabel overlay
        local vign = Instance.new("ImageLabel")
        vign.Name = "IgnisiaVignette"
        vign.Size = UDim2.new(1,0,1,0)
        vign.Position = UDim2.new(0,0,0,0)
        vign.BackgroundTransparency = 1
        vign.Image = assets.ui and assets.ui.vignetteImage or ""
        vign.ImageTransparency = 0.9
        vign.Parent = playerGui:FindFirstChild("IgnisiaUI") or playerGui
        -- fade in then out
        for i=1,8 do
            vign.ImageTransparency = vign.ImageTransparency - 0.09
            wait(0.03)
        end
        delay(1.2, function()
            for i=1,18 do
                vign.ImageTransparency = vign.ImageTransparency + 0.055
                wait(0.03)
            end
            pcall(function() vign:Destroy() end)
        end)
    end
end)

-- Play cinematic when character added first time
player.CharacterAdded:Connect(function()
    wait(0.5)
    if not player:GetAttribute("CinematicPlayed") then
        player:SetAttribute("CinematicPlayed", true)
        pcall(playCinematicOnce)
    end
end)

wireReflectionButtons()
spawn(monitorSpark)


