-- Zone1Installer.lua
-- One-file installer for Zone 1: Ignisia (Spark discovery + Reflection prompt)
-- Source: Drive 1 docs (Zone 1 script, Core Mechanics, Journal/Reflections, Sound Vision)

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then error("Zone1Installer must be run in Roblox Studio") end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
if not StarterPlayerScripts then
    StarterPlayerScripts = Instance.new("StarterPlayerScripts")
    StarterPlayerScripts.Parent = StarterPlayer
end

local function ensureRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then return r end
    r = Instance.new("RemoteEvent") r.Name = name r.Parent = ReplicatedStorage
    return r
end

local function ensureModuleScript(name, source)
    local existing = ReplicatedStorage:FindFirstChild(name)
    if existing and existing:IsA("ModuleScript") then return existing end
    local m = Instance.new("ModuleScript") m.Name = name m.Source = source m.Parent = ReplicatedStorage
    return m
end

local function ensureServerScript(name, source)
    local existing = ServerScriptService:FindFirstChild(name)
    if existing and existing:IsA("Script") then return existing end
    local s = Instance.new("Script") s.Name = name s.Source = source s.Parent = ServerScriptService
    return s
end

local function ensureLocalScript(name, source)
    local existing = StarterPlayerScripts:FindFirstChild(name)
    if existing and existing:IsA("LocalScript") then return existing end
    local s = Instance.new("LocalScript") s.Name = name s.Source = source s.Parent = StarterPlayerScripts
    return s
end

-- Remotes
ensureRemote("SparkEvent")
ensureRemote("DialogEvent")

-- Assets: tuned to Drive 1 sound design (warm, dawn tones, crackle)
local ASSETS = [[
local assets = {}
assets.sounds = {
    ambient = "rbxassetid://451776625", -- airy wind
    crackle = "rbxassetid://705787045", -- ember crackle
    dawn    = "rbxassetid://18435255",  -- gentle pad
    chime   = "rbxassetid://180204501", -- small chime
}
assets.ui = { vignetteImage = "rbxassetid://3570695787" }
assets.tuning = { NEAR_RADIUS = 8, STILL_VEL = 1.2, TARGET_SECONDS = 3.5 }
return assets
]]
ensureModuleScript("IgnisiaAssets", ASSETS)

-- SaveService (HasSpark + Reflection)
local SAVE = [[
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local STORE = DataStoreService:GetDataStore("Ignisia_Z1_v1")
local function keyFor(id) return "player_"..tostring(id) end
local function updateAsync(key, patch)
    local ok = pcall(function()
        STORE:UpdateAsync(key, function(old)
            local cur = old or {}
            for k,v in pairs(patch) do cur[k] = v end
            return cur
        end)
    end)
    return ok
end
local function load(id)
    local ok, data = pcall(function() return STORE:GetAsync(keyFor(id)) end)
    return ok and data or nil
end
Players.PlayerAdded:Connect(function(p)
    task.spawn(function()
        local d = load(p.UserId)
        if d then
            if d.HasSpark then local v = Instance.new("BoolValue") v.Name="HasSpark" v.Value=true v.Parent=p end
            if d.Reflection then local s = Instance.new("StringValue") s.Name="Reflection" s.Value=tostring(d.Reflection) s.Parent=p end
        end
    end)
end)
Players.PlayerRemoving:Connect(function(p)
    task.spawn(function()
        local payload = {}
        if p:FindFirstChild("HasSpark") and p.HasSpark.Value then payload.HasSpark = true end
        if p:FindFirstChild("Reflection") and p.Reflection.Value ~= "" then payload.Reflection = p.Reflection.Value end
        updateAsync(keyFor(p.UserId), payload)
    end)
end)
local S = {}
function S:SavePlayer(p)
    task.spawn(function()
        local payload = {}
        if p:FindFirstChild("HasSpark") and p.HasSpark.Value then payload.HasSpark = true end
        if p:FindFirstChild("Reflection") and p.Reflection.Value ~= "" then payload.Reflection = p.Reflection.Value end
        updateAsync(keyFor(p.UserId), payload)
    end)
end
return S
]]
ensureServerScript("SaveService", SAVE)

-- Server: SparkServer (validate proximity and set flags)
local SERVER = [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sparkEvent = ReplicatedStorage:FindFirstChild("SparkEvent")
local function attachAura(p)
    local char = p.Character if not char then return end
    if char:FindFirstChild("_IgnisiaAura") then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart") if not root then return end
    local f = Instance.new("Folder") f.Name = "_IgnisiaAura" f.Parent = char
    local att = Instance.new("Attachment") att.Name = "IgnisiaAuraAttachment" att.Parent = root
    local pe = Instance.new("ParticleEmitter") pe.Name = "IgnisiaAuraParticles" pe.Rate = 8 pe.Lifetime = NumberRange.new(1,1.8) pe.Speed = NumberRange.new(0.3,0.9) pe.Parent = att
end
sparkEvent.OnServerEvent:Connect(function(player, action, reflection)
    if action ~= "ignite" then return end
    if player:FindFirstChild("HasSpark") and player.HasSpark.Value then return end
    local has = Instance.new("BoolValue") has.Name = "HasSpark" has.Value = true has.Parent = player
    if reflection and reflection ~= "" then local s = Instance.new("StringValue") s.Name="Reflection" s.Value=tostring(reflection) s.Parent=player end
    attachAura(player)
    local ok, SS = pcall(function() return require(game:GetService("ServerScriptService"):FindFirstChild("SaveService")) end)
    if ok and SS and SS.SavePlayer then pcall(function() SS:SavePlayer(player) end) end
end)
]]
ensureServerScript("SparkServer", SERVER)

-- Client: Zone 1 experience
local CLIENT = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local sparkEvent = ReplicatedStorage:WaitForChild("SparkEvent")

local assets = {}
do local mod = ReplicatedStorage:FindFirstChild("IgnisiaAssets") if mod and mod:IsA("ModuleScript") then local ok,m=pcall(require,mod) if ok then assets=m end end end
local NEAR_RADIUS = (assets.tuning and assets.tuning.NEAR_RADIUS) or 8
local STILL_VEL = (assets.tuning and assets.tuning.STILL_VEL) or 1.2
local TARGET_SECONDS = (assets.tuning and assets.tuning.TARGET_SECONDS) or 3.5

-- Build minimal UI (dialog + patience + reflection)
local root = Instance.new("ScreenGui") root.Name = "IgnisiaUI" root.ResetOnSpawn=false root.Parent=gui
local dialog = Instance.new("TextLabel") dialog.Name="Dialog" dialog.Size=UDim2.new(0.7,0,0.12,0) dialog.Position=UDim2.new(0.15,0,0.08,0) dialog.BackgroundTransparency=0.4 dialog.TextColor3=Color3.new(1,1,1) dialog.TextScaled=true dialog.Visible=false dialog.Parent=root
local bar = Instance.new("Frame") bar.Name="PatienceBar" bar.Size=UDim2.new(0.4,0,0.035,0) bar.Position=UDim2.new(0.3,0,0.9,0) bar.BackgroundColor3=Color3.fromRGB(40,40,40) bar.Parent=root
local fill = Instance.new("Frame") fill.Name="Fill" fill.Size=UDim2.new(0,0,1,0) fill.BackgroundColor3=Color3.fromRGB(255,170,80) fill.Parent=bar
local refl = Instance.new("Frame") refl.Name="Reflection" refl.Size=UDim2.new(0.5,0,0.28,0) refl.Position=UDim2.new(0.25,0,0.6,0) refl.BackgroundColor3=Color3.fromRGB(20,20,20) refl.Visible=false refl.Parent=root
local c1 = Instance.new("TextButton") c1.Size=UDim2.new(0.9,0,0.25,0) c1.Position=UDim2.new(0.05,0,0.08,0) c1.Text="🔥 Like something inside me finally said: 'I'm here.'" c1.Parent=refl
local c2 = Instance.new("TextButton") c2.Size=UDim2.new(0.9,0,0.25,0) c2.Position=UDim2.new(0.05,0,0.4,0) c2.Text="🌱 Small, but brave. Like a candle lighting in the dark." c2.Parent=refl
local c3 = Instance.new("TextButton") c3.Size=UDim2.new(0.9,0,0.25,0) c3.Position=UDim2.new(0.05,0,0.72,0) c3.Text="💫 Honestly? I didn’t think I had one. But… maybe I do." c3.Parent=refl

-- Create Spark part if missing
local spark = workspace:FindFirstChild("Spark")
if not spark then
    spark = Instance.new("Part") spark.Name="Spark" spark.Size=Vector3.new(6,1,6) spark.Anchored=true spark.Position=Vector3.new(0,2,0) spark.Parent=workspace
    local pl = Instance.new("PointLight") pl.Color=Color3.fromRGB(255,150,80) pl.Range=12 pl.Parent=spark
    local pe = Instance.new("ParticleEmitter") pe.Rate=12 pe.Lifetime=NumberRange.new(1,2) pe.Speed=NumberRange.new(0.6,1.4) pe.Parent=spark
    local prompt = Instance.new("ProximityPrompt") prompt.ActionText="Touch the Spark?" prompt.HoldDuration=0 prompt.MaxActivationDistance=8 prompt.Parent=spark
end

-- Cinematic intro per Drive 1 script
local npcLines = {
    "Whoa. Look at this little guy—still glowing after all that? …Same.",
    "Hey! You made it! I wasn’t sure you’d show... You don’t feel like a myth.",
    "This is Ignisia. The place where the spark first wakes up.",
    "Follow the flicker. It knows you.",
}
local function playCinematic()
    local cam = workspace.CurrentCamera if not cam then return end
    cam.CameraType = Enum.CameraType.Scriptable
    local startCF = CFrame.new(spark.Position + Vector3.new(0, 30, -60), spark.Position)
    local endCF   = CFrame.new(spark.Position + Vector3.new(0, 8, -18), spark.Position)
    local t=0; local dur=4
    while t<dur do t += RunService.RenderStepped:Wait() cam.CFrame = startCF:Lerp(endCF, math.clamp(t/dur,0,1)) end
    for _,line in ipairs(npcLines) do dialog.Text = line dialog.Visible=true task.wait(2.2) end
    dialog.Visible=false cam.CameraType = Enum.CameraType.Custom
end
player.CharacterAdded:Connect(function() task.wait(0.5) playCinematic() end)

-- Patience mechanic near Spark
local function setFill(p) p = math.clamp(p,0,1) fill.Size = UDim2.new(p,0,1,0) end
task.spawn(function()
    local acc=0; local check=0.1
    while true do
        local char = player.Character local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and spark then
            local dist = (root.Position - spark.Position).Magnitude
            local near = dist <= NEAR_RADIUS
            local vel = root.Velocity.Magnitude
            if near and vel <= STILL_VEL then acc += check else acc = math.max(0, acc - check*1.5) end
            setFill(acc/TARGET_SECONDS)
            if acc >= TARGET_SECONDS then
                dialog.Text = "Do you feel it? That… pull?"
                dialog.Visible = true task.wait(1.2) dialog.Visible=false
                refl.Visible = true
                break
            end
        end
        task.wait(check)
    end
end)

local function choose(text)
    refl.Visible=false
    sparkEvent:FireServer("ignite", text)
    dialog.Text = "The first yes. The one you give yourself."
    dialog.Visible=true task.delay(1.6, function() dialog.Visible=false end)
end
c1.MouseButton1Click:Connect(function() choose(c1.Text) end)
c2.MouseButton1Click:Connect(function() choose(c2.Text) end)
c3.MouseButton1Click:Connect(function() choose(c3.Text) end)
]]
ensureLocalScript("Zone1Client", CLIENT)

print("Zone 1 (Ignisia) installed. Press Play to test.")

