-- Zone3Content.lua
-- Pathforge (Forge Your Key): server content for Zone 3
-- Place this Script in ServerScriptService. It will create a `Zone3` folder and minimal gameplay objects in Workspace.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Zone3 = workspace:FindFirstChild("Zone3")
if not Zone3 then
	Zone3 = Instance.new("Folder") Zone3.Name = "Zone3" Zone3.Parent = workspace
end

-- Remotes
local dialogEvent = ReplicatedStorage:FindFirstChild("DialogEvent")
if not dialogEvent then dialogEvent = Instance.new("RemoteEvent") dialogEvent.Name = "DialogEvent" dialogEvent.Parent = ReplicatedStorage end
local npcAnimEvent = ReplicatedStorage:FindFirstChild("NPCAnimEvent")
if not npcAnimEvent then npcAnimEvent = Instance.new("RemoteEvent") npcAnimEvent.Name = "NPCAnimEvent" npcAnimEvent.Parent = ReplicatedStorage end

-- SaveService helper
local function savePlayer(player)
	pcall(function()
		local SS = require(ServerScriptService:FindFirstChild("SaveService"))
		if SS and SS.SavePlayer then SS:SavePlayer(player) end
	end)
end

-- Utility
local function groundAt(pos)
	local ray = Ray.new(pos + Vector3.new(0,50,0), Vector3.new(0,-200,0))
	local part, hit = workspace:FindPartOnRay(ray)
	if hit then return Vector3.new(pos.X, hit.Y + 1.5, pos.Z) end
	return pos
end

-- Anchor (teleport target for Zone 3)
local anchor = Vector3.new(0, 5, 220)

-- Forge platform and identity gates
local function ensureForge()
	if Zone3:FindFirstChild("Forge") then return end
	local forge = Instance.new("Part") forge.Name = "Forge" forge.Size = Vector3.new(10,1,10)
	forge.Position = groundAt(anchor + Vector3.new(0,0,0)) forge.Anchored = true forge.BrickColor = BrickColor.new("Dirt brown") forge.Parent = Zone3
	local prompt = Instance.new("ProximityPrompt") prompt.ActionText = "Begin Forge" prompt.ObjectText = "Pathforge" prompt.HoldDuration = 0.6 prompt.MaxActivationDistance = 10 prompt.Parent = forge
	prompt.Triggered:Connect(function(player)
		if not player or not player:IsA("Player") then return end
		if player:FindFirstChild("HasPathKey") and player.HasPathKey.Value == true then
			pcall(function() dialogEvent:FireClient(player, {speaker = "Solari", lines = {"Your key is already forged.", "Try the gates."}}) end)
			return
		end
		-- Mark forging session (server-authoritative)
		local session = Instance.new("BoolValue") session.Name = "_Forging" session.Value = true session.Parent = player
		pcall(function() dialogEvent:FireClient(player, {speaker = "Solari", lines = {"Breathe. Choose the path that feels true.", "Your key takes shape as you decide."}}) end)
		-- Offer three gentle choices as pads; actual selection is handled by contact below
	end)

	-- Choice pads
	local choices = {
		{ name = "Courage", offset = Vector3.new(-8,0,0), color = BrickColor.new("Bright orange") },
		{ name = "Wonder", offset = Vector3.new(0,0,8), color = BrickColor.new("Pastel blue-green") },
		{ name = "Intuition", offset = Vector3.new(8,0,0), color = BrickColor.new("Mint") },
	}
	for _,c in ipairs(choices) do
		local p = Instance.new("Part") p.Name = "Choice_"..c.name p.Size = Vector3.new(5,1,5)
		p.Position = groundAt(forge.Position + c.offset)
		p.Anchored = true p.BrickColor = c.color p.Parent = Zone3
		p.Touched:Connect(function(hit)
			local pl = Players:GetPlayerFromCharacter(hit.Parent)
			if not pl then return end
			local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
			if not root then return end
			if (root.Position - p.Position).Magnitude > 6 then return end
			-- Only accept if player recently initiated forge
			if not pl:FindFirstChild("_Forging") then return end
			-- Set Path Key and trait
			if not pl:FindFirstChild("HasPathKey") then local v = Instance.new("BoolValue", pl) v.Name = "HasPathKey" v.Value = true end
			local s = pl:FindFirstChild("PathKeyShape") or Instance.new("StringValue", pl) s.Name = "PathKeyShape" s.Value = c.name
			if c.name == "Courage" then
				if not pl:FindFirstChild("Trait_Courage") then local t = Instance.new("BoolValue", pl) t.Name = "Trait_Courage" t.Value = true end
			end
			pcall(function() pl._Forging:Destroy() end)
			savePlayer(pl)
			pcall(function() dialogEvent:FireClient(pl, {speaker = "Solari", lines = {"You forged your key: "..c.name..".", "Identity gates will answer now."}}) end)
		end)
	end

	-- Identity gates (open if PathKey matches)
	local gates = {
		{ name = "Gate_Courage", offset = Vector3.new(-16,0,-12), need = "Courage", color = BrickColor.new("Bright orange") },
		{ name = "Gate_Wonder", offset = Vector3.new(0,0,18), need = "Wonder", color = BrickColor.new("Pastel blue-green") },
		{ name = "Gate_Intuition", offset = Vector3.new(16,0,-12), need = "Intuition", color = BrickColor.new("Mint") },
	}
	for _,g in ipairs(gates) do
		local gate = Instance.new("Part") gate.Name = g.name gate.Size = Vector3.new(6,8,1)
		gate.Position = groundAt(forge.Position + g.offset)
		gate.Anchored = true gate.BrickColor = g.color gate.Parent = Zone3
		local pp = Instance.new("ProximityPrompt", gate) pp.ActionText = "Open" pp.ObjectText = g.name pp.HoldDuration = 0.3 pp.MaxActivationDistance = 8
		pp.Triggered:Connect(function(player)
			if not player or not player:IsA("Player") then return end
			local s = player:FindFirstChild("PathKeyShape")
			if s and tostring(s.Value) == g.need then
				gate.CanCollide = false gate.Transparency = 0.6
				pcall(function() dialogEvent:FireClient(player, {speaker = "Solari", lines = {"The gate recognizes your key.", "Go on."}}) end)
			else
				pcall(function() dialogEvent:FireClient(player, {speaker = "Solari", lines = {"It doesn’t resonate yet.", "Forge your key first."}}) end)
			end
		end)
	end
end

ensureForge()

-- NPCs (optional): clone from ReplicatedStorage/NPCModels
local function ensureNPCs()
	local npcFolder = ReplicatedStorage:FindFirstChild("NPCModels")
	local function spawnNPC(name, pos)
		if Zone3:FindFirstChild(name) then return end
		local template = npcFolder and npcFolder:FindFirstChild(name)
		local model = nil
		if template and template:IsA("Model") then
			model = template:Clone() model.Name = name model.Parent = Zone3
			pcall(function() model:PivotTo(CFrame.new(pos)) end)
		else
			local p = Instance.new("Part") p.Name = name p.Size = Vector3.new(2,5,2) p.Position = pos p.Anchored = true p.BrickColor = BrickColor.new("Bright orange") p.Parent = Zone3
			model = p
		end
		local promptParent = (model:IsA("Model") and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)) or model
		local prompt = Instance.new("ProximityPrompt", promptParent) prompt.ActionText = "Talk" prompt.ObjectText = name prompt.HoldDuration = 0.3 prompt.MaxActivationDistance = 10
		local lines = {
			Pathforge = {
				"Pathforge shapes what you choose.",
				"Three ways, none wrong: Courage, Wonder, Intuition.",
			},
		}
		prompt.Triggered:Connect(function(player)
			pcall(function() dialogEvent:FireClient(player, {speaker = name, lines = (lines[name] or {"Hey."}), npcName = name}) end)
		end)
	end
	local base = groundAt(anchor + Vector3.new(0,0,-6))
	spawnNPC("Pathforge", base + Vector3.new(0,0,-10))
end

ensureNPCs()