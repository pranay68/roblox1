-- AnimationHooks.lua
-- Server-side animation helper: stores AnimationIds in ReplicatedStorage.IgnisiaAssets or uses marketplace defaults

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = ReplicatedStorage:FindFirstChild("IgnisiaAssets")
if not assets then
    -- nothing to do
    return
end

-- Provide default kneel animation id if none set
pcall(function()
    local ok, m = pcall(function() return require(assets) end)
    if ok and type(m) == "table" then
        if not m.kneelAnimation or m.kneelAnimation == "" then
            m.kneelAnimation = "rbxassetid://71201518567477" -- fallback
        end
    end
end)


