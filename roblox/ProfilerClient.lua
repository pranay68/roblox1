-- ProfilerClient.lua
-- LocalScript: samples FPS, particle counts and memory and sends to server periodically
-- Place in StarterPlayer > StarterPlayerScripts

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local PROFILER_REMOTE = ReplicatedStorage:FindFirstChild("ProfilerEvent")
if not PROFILER_REMOTE then
    -- create a local placeholder to avoid errors; installer will create the real remote
    PROFILER_REMOTE = Instance.new("RemoteEvent")
    PROFILER_REMOTE.Name = "ProfilerEvent"
    PROFILER_REMOTE.Parent = ReplicatedStorage
end

local sampleInterval = 10 -- seconds
local frameTimes = {}
local lastSample = tick()

RunService.Heartbeat:Connect(function(dt)
    table.insert(frameTimes, dt)
    if #frameTimes > 300 then table.remove(frameTimes, 1) end
end)

local function sampleAndSend()
    local now = tick()
    local count = #frameTimes
    if count == 0 then return end
    local sum = 0
    for _,v in ipairs(frameTimes) do sum = sum + v end
    local avg = sum / count
    local fps = 1 / math.max(0.0001, avg)

    -- count particle emitters and aggregate rate
    local particleCount = 0
    local particleRate = 0
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") then
            particleCount = particleCount + 1
            local ok, rate = pcall(function() return obj.Rate end)
            if ok and type(rate) == "number" then particleRate = particleRate + rate end
        end
    end

    local memKb = collectgarbage("count")

    local payload = {
        time = now,
        fps = fps,
        avgFrameTime = avg,
        particleCount = particleCount,
        particleRate = particleRate,
        memKb = memKb,
        player = player and player.UserId or "unknown",
    }

    -- fire to server safely
    pcall(function() PROFILER_REMOTE:FireServer(payload) end)
end

while true do
    if tick() - lastSample >= sampleInterval then
        sampleAndSend()
        lastSample = tick()
    end
    task.wait(1)
end


