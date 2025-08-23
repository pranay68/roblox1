-- UIWireUp.lua
-- LocalScript to run on client that converts the reflection TextButtons to ImageButtons
-- and applies the vignette decal when IgnisiaAssets contains real asset ids.
-- Place in StarterPlayerScripts (installer already creates IgnisiaUI if missing).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function safeRequire(name)
    local ok, mod = pcall(function() return require(ReplicatedStorage:WaitForChild(name)) end)
    if ok and type(mod) == "table" then return mod end
    return nil
end

local function replaceButtons(gui, assets)
    if not gui then return end
    local reflection = gui:FindFirstChild("ReflectionGui")
    if not reflection then return end

    local icons = assets.ui and assets.ui.reflectionButtonIcons or nil
    local btns = {reflection:FindFirstChild("Choice1"), reflection:FindFirstChild("Choice2"), reflection:FindFirstChild("Choice3")}
    for i,btn in ipairs(btns) do
        if btn and icons and icons[i] and icons[i] ~= "" then
            -- create ImageButton to replace
            local ib = Instance.new("ImageButton")
            ib.Name = btn.Name
            ib.Size = btn.Size
            ib.Position = btn.Position
            ib.AnchorPoint = btn.AnchorPoint
            ib.BackgroundTransparency = btn.BackgroundTransparency
            ib.Image = icons[i]
            ib.Parent = reflection
            -- wire click: forward to original handler by invoking MouseButton1Click listeners if any
            ib.MouseButton1Click:Connect(function()
                -- set chosen attribute for reflection and hide
                reflection:SetAttribute("ChosenReflection", btn.Text)
                reflection.Visible = false
            end)
            btn:Destroy()
        end
    end
end

local function applyVignette(gui, assets)
    if not gui then return end
    local vignId = assets.ui and assets.ui.vignetteImage or ""
    if vignId and vignId ~= "" and assets.graphics and assets.graphics.enableVignette then
        local vign = gui:FindFirstChild("IgnisiaVignette")
        if not vign then
            vign = Instance.new("ImageLabel")
            vign.Name = "IgnisiaVignette"
            vign.Size = UDim2.new(1,0,1,0)
            vign.Position = UDim2.new(0,0,0,0)
            vign.BackgroundTransparency = 1
            vign.Image = vignId
            vign.ImageTransparency = 1
            vign.ZIndex = 50
            vign.Parent = gui
        else
            vign.Image = vignId
        end
    end
end

local function init()
    local assets = safeRequire("IgnisiaAssets")
    local gui = playerGui:FindFirstChild("IgnisiaUI")
    if not gui then return end
    replaceButtons(gui, assets or {})
    applyVignette(gui, assets or {})
end

-- Try immediately and also when assets load/replicated storage changes
init()
ReplicatedStorage.ChildAdded:Connect(function(child)
    if child.Name == "IgnisiaAssets" then
        wait(0.2)
        init()
    end
end)







