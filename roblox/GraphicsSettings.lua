-- GraphicsSettings.lua
-- LocalScript to show a small Graphics Settings UI (Low / Medium / High) and persist choice via Player attributes.
-- Place this in StarterPlayerScripts as a LocalScript or ensure installer creates it.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "IgnisiaGraphicsUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,240,0,120)
frame.Position = UDim2.new(0.02,0,0.7,0)
frame.BackgroundColor3 = Color3.fromRGB(22,22,24)
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,30)
title.BackgroundTransparency = 1
title.Text = "Graphics"
title.TextColor3 = Color3.new(1,1,1)
title.Parent = frame

local function makeButton(y, text, level)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.9,0,0,28)
    b.Position = UDim2.new(0.05,0,y,0)
    b.Text = text
    b.Parent = frame
    b.MouseButton1Click:Connect(function()
        player:SetAttribute("GraphicsQuality", level)
        -- Apply settings locally
        if level == "low" then
            game:GetService("ReplicatedStorage"):WaitForChild("IgnisiaAssets"):WaitForChild("graphics").particleMultiplier = 0.45
        elseif level == "medium" then
            game:GetService("ReplicatedStorage"):WaitForChild("IgnisiaAssets"):WaitForChild("graphics").particleMultiplier = 0.8
        else
            game:GetService("ReplicatedStorage"):WaitForChild("IgnisiaAssets"):WaitForChild("graphics").particleMultiplier = 1.0
        end
    end)
    return b
end

makeButton(0.22, "Low", "low")
makeButton(0.54, "Medium", "medium")
makeButton(0.86, "High", "high")

-- load saved attribute (if any)
local cur = player:GetAttribute("GraphicsQuality") or "high"
player:SetAttribute("GraphicsQuality", cur)

return gui



