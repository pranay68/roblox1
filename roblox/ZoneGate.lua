-- ZoneGate.lua
-- Place in Workspace. Create a Part named 'Zone2Gate' and attach this Script to it.
-- Gate teleports players who have HasSpark to Zone2 spawn.

local TELEPORT_POS = Vector3.new(0, 5, 120) -- adjust to your Zone2 spawn position
local TELEPORT_CFRAME = CFrame.new(TELEPORT_POS)

local part = script.Parent
if not part or not part:IsA("BasePart") then
    warn("ZoneGate must be parented to a Part named Zone2Gate")
    return
end

local Players = game:GetService("Players")
local proximity = part:FindFirstChildOfClass("ProximityPrompt")
if not proximity then
    proximity = Instance.new("ProximityPrompt")
    proximity.Parent = part
    proximity.ActionText = "Enter Lensveil"
    proximity.ObjectText = "Zone Gate"
    proximity.HoldDuration = 0.5
    proximity.MaxActivationDistance = 8
end

proximity.Triggered:Connect(function(player)
    if player:FindFirstChild("HasSpark") and player.HasSpark.Value == true then
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char:SetPrimaryPartCFrame(TELEPORT_CFRAME)
        end
    else
        -- feedback
        local plgui = player:FindFirstChild("PlayerGui")
        if plgui then
            local msg = Instance.new("Message")
            msg.Text = "You need to carry your First Flame to enter Lensveil."
            msg.Parent = player.PlayerGui
            delay(2, function() pcall(function() msg:Destroy() end) end)
        end
    end
end)


