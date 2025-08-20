-- NPCUtils.lua
-- Standalone helper functions for NPC pathfinding and look-at behavior
-- Usage (server):
--   local NPCUtils = require(path.to.NPCUtils)
--   NPCUtils:assignNPCNoCollide(npcModel)
--   NPCUtils:pathfindTo(npcModel, goalPosition, {repathSeconds = 2, timeoutSeconds = 15})
--   NPCUtils:makeLookAt(npcModel, Vector3.new(...))

local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")

local NPC_COLLISION_GROUP = "NPC"

local NPCUtils = {}

local function ensureNPCGroup()
    -- Create NPC collision group and disable self-collisions
    local ok, groups = pcall(function() return PhysicsService:GetCollisionGroups() end)
    if ok then
        local exists = false
        for _,g in ipairs(groups) do
            if g.name == NPC_COLLISION_GROUP then exists = true break end
        end
        if not exists then
            pcall(function() PhysicsService:CreateCollisionGroup(NPC_COLLISION_GROUP) end)
            -- ignore collisions among NPCs
            pcall(function() PhysicsService:CollisionGroupSetCollidable(NPC_COLLISION_GROUP, NPC_COLLISION_GROUP, false) end)
        end
    end
end

local function setModelCollisionGroup(model: Model, groupName: string)
    for _,desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            pcall(function() PhysicsService:SetPartCollisionGroup(desc, groupName) end)
        end
    end
end

function NPCUtils:assignNPCNoCollide(npcModel: Model)
    -- Ensure NPC-vs-NPC does not collide, then assign all parts
    ensureNPCGroup()
    setModelCollisionGroup(npcModel, NPC_COLLISION_GROUP)
end

local function getHumanoid(model: Model)
    return model and model:FindFirstChildOfClass("Humanoid") or nil
end

local function getRootPart(model: Model)
    local hrp = model and model:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp end
    return model and model:FindFirstChildWhichIsA("BasePart") or nil
end

-- Move NPC to a goal using Roblox pathfinding.
-- Options:
--   agentRadius, agentHeight, agentCanJump (defaults are fine for most rigs)
--   repathSeconds (default 2.0): recompute when blocked
--   timeoutSeconds (default 20): overall timeout
-- Returns true on reaching goal, false on fail/timeout.
function NPCUtils:pathfindTo(npcModel: Model, goalPosition: Vector3, options)
    options = options or {}
    local humanoid = getHumanoid(npcModel)
    local root = getRootPart(npcModel)
    if not humanoid or not root then return false end

    local agentParams = {
        AgentRadius = options.agentRadius or 2.0,
        AgentHeight = options.agentHeight or 5.0,
        AgentCanJump = (options.agentCanJump == nil) and true or options.agentCanJump,
    }
    local path = PathfindingService:CreatePath(agentParams)

    local function compute()
        local ok = pcall(function()
            path:ComputeAsync(root.Position, goalPosition)
        end)
        return ok and path.Status == Enum.PathStatus.Success
    end

    local success = compute()
    if not success then
        return false
    end

    local waypoints = path:GetWaypoints()
    local reached = false
    local blocked = false
    local lastRepath = tick()
    local repathSeconds = options.repathSeconds or 2.0
    local timeoutSeconds = options.timeoutSeconds or 20.0
    local startTime = tick()

    local connection
    connection = path.Blocked:Connect(function()
        blocked = true
    end)

    for i,wp in ipairs(waypoints) do
        if wp.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end
        humanoid:MoveTo(wp.Position)
        local reachedThis = humanoid.MoveToFinished:Wait()
        if not reachedThis then
            -- try to recompute if blocked or off-path
            if (tick() - lastRepath) > repathSeconds then
                lastRepath = tick()
                if compute() then
                    waypoints = path:GetWaypoints()
                    -- restart loop from closest waypoint
                    local closestIdx = i
                    local minDist = math.huge
                    for j,w in ipairs(waypoints) do
                        local d = (w.Position - root.Position).Magnitude
                        if d < minDist then minDist = d closestIdx = j end
                    end
                    i = math.max(closestIdx - 1, 1)
                end
            end
        end
        if (goalPosition - root.Position).Magnitude <= 4 then
            reached = true
            break
        end
        if (tick() - startTime) > timeoutSeconds then
            break
        end
    end

    if connection then connection:Disconnect() end
    return reached
end

-- Make an NPC look at a world position.
-- If R15 rig with Neck Motor6D is present, rotates neck slightly; otherwise rotates root CFrame.
-- Options:
--   maxNeckAngle (radians) default ~30 deg
--   lockAutoRotate (bool) default false, set true to disable Humanoid.AutoRotate while looking
function NPCUtils:makeLookAt(npcModel: Model, worldPosition: Vector3, options)
    options = options or {}
    local humanoid = getHumanoid(npcModel)
    local root = getRootPart(npcModel)
    if not humanoid or not root then return end

    local head = npcModel:FindFirstChild("Head")
    local neck = nil
    if head then
        -- Find the neck Motor6D (usually attached to UpperTorso or Torso)
        local parent = head.Parent
        if parent then
            for _,d in ipairs(parent:GetDescendants()) do
                if d:IsA("Motor6D") and (d.Part1 == head or d.Part0 == head) and d.Name == "Neck" then
                    neck = d
                    break
                end
            end
        end
    end

    local lookVector = (worldPosition - root.Position)
    if lookVector.Magnitude < 1e-3 then return end

    if options.lockAutoRotate then
        humanoid.AutoRotate = false
    end

    if neck then
        -- Rotate neck toward target with clamp
        local maxAngle = options.maxNeckAngle or math.rad(30)
        local rootCF = root.CFrame
        local targetCF = CFrame.lookAt(head.Position, worldPosition)
        local _, _, rootYaw = rootCF:ToEulerAnglesYXZ()
        local _, _, targetYaw = targetCF:ToEulerAnglesYXZ()
        local deltaYaw = math.clamp(targetYaw - rootYaw, -maxAngle, maxAngle)
        -- Apply a small yaw rotation to the neck's C0
        local c0 = neck.C0
        local rot = CFrame.Angles(0, deltaYaw, 0)
        neck.C0 = c0:Lerp(c0 * rot, 0.9)
    else
        -- Fallback: rotate root
        root.CFrame = CFrame.lookAt(root.Position, Vector3.new(worldPosition.X, root.Position.Y, worldPosition.Z))
    end
end

return NPCUtils

