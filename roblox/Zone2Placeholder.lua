-- Zone2Placeholder.lua
-- Simple placeholder for Zone 2 (Lensveil) content: NPC dialog and a small interaction.
-- Place this script in Workspace under a Folder named 'Zone2' with a Model 'NPC_Solari'.

local npcFolder = workspace:FindFirstChild("Zone2")
if not npcFolder then
    npcFolder = Instance.new("Folder") npcFolder.Name = "Zone2" npcFolder.Parent = workspace
end

-- Create a simple NPC model if missing
local npc = npcFolder:FindFirstChild("NPC_Solari")
if not npc then
    npc = Instance.new("Model") npc.Name = "NPC_Solari" npc.Parent = npcFolder
    local head = Instance.new("Part") head.Name = "Head" head.Size = Vector3.new(2,1,1) head.Position = Vector3.new(0,3,130) head.Anchored = true head.Parent = npc
end

-- Dialogue lines
local lines = {
    "Welcome to Lensveil. The world is not what it seems.",
    "Keep your spark close — it gives you sight beyond sight.",
    "Trust gentle patience; light bends to those who listen."
}

local Players = game:GetService("Players")

-- When player approaches NPC within 10 studs, show dialog in their PlayerGui
local function showDialog(player)
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return end
    local screen = Instance.new("ScreenGui")
    screen.Name = "LensveilDialog"
    screen.ResetOnSpawn = false
    screen.Parent = player.PlayerGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.6,0,0.2,0)
    frame.Position = UDim2.new(0.2,0,0.7,0)
    frame.BackgroundTransparency = 0.25
    frame.BackgroundColor3 = Color3.fromRGB(8,8,12)
    frame.Parent = screen
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, -10)
    label.Position = UDim2.new(0,5,0,5)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.TextWrapped = true
    label.Parent = frame
    for _,t in ipairs(lines) do
        label.Text = "Solari: "..t
        wait(3.2)
    end
    screen:Destroy()
end

-- Monitor players entering NPC range
spawn(function()
    while true do
        for _,player in pairs(Players:GetPlayers()) do
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local d = (char.HumanoidRootPart.Position - npc.Head.Position).Magnitude
                if d <= 10 then
                    -- show dialog once per approach
                    showDialog(player)
                    wait(6)
                end
            end
        end
        wait(1)
    end
end)


