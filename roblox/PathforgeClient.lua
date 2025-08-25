-- PathforgeClient.lua
-- Optional client helpers for Zone 3 (UI hints, gentle FX)
-- Place in StarterPlayer > StarterPlayerScripts. Safe if missing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local dialogEvent = ReplicatedStorage:FindFirstChild("DialogEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
dialogEvent.Name = "DialogEvent"

-- Use existing IgnisiaUI if present
local gui = player:WaitForChild("PlayerGui"):FindFirstChild("IgnisiaUI")
if gui then
	-- Provide a soft hint label for forge when near
	local hint = gui:FindFirstChild("_ForgeHint") or Instance.new("TextLabel")
	hint.Name = "_ForgeHint"
	hint.Size = UDim2.new(0.3,0,0.05,0)
	hint.Position = UDim2.new(0.35,0,0.85,0)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.new(1,1,1)
	hint.TextScaled = true
	hint.Visible = false
	hint.Parent = gui

	local function update()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local forge = workspace:FindFirstChild("Zone3") and workspace.Zone3:FindFirstChild("Forge")
		if root and forge then
			local near = (root.Position - forge.Position).Magnitude <= 12
			hint.Visible = near and not (player:FindFirstChild("HasPathKey") and player.HasPathKey.Value)
			hint.Text = near and "Stand on a choice pad to forge your key" or ""
		end
	end
	RunService.RenderStepped:Connect(update)
end

-- Hook DialogEvent to cinematic controller if present
if gui and gui:FindFirstChild("_DialogController") then
	dialogEvent.OnClientEvent:Connect(function(payload)
		local ctrl = gui:FindFirstChild("_DialogController")
		if ctrl and ctrl:IsA("BindableFunction") and payload and payload.lines then
			ctrl:Invoke({ speaker = payload.speaker or "", lines = payload.lines, npcModel = nil, cameraPath = nil, perLine = payload.perLine })
			return
		end
	end)
end