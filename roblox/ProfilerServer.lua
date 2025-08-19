-- ProfilerServer.lua
-- Receives profiler payloads from clients and records metrics via Metrics.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Metrics = nil
pcall(function() Metrics = require(game:GetService("ServerScriptService"):FindFirstChild("Metrics") or nil) end)

local prof = ReplicatedStorage:FindFirstChild("ProfilerEvent")
if not prof then
    prof = Instance.new("RemoteEvent") prof.Name = "ProfilerEvent" prof.Parent = ReplicatedStorage
end

prof.OnServerEvent:Connect(function(player, payload)
    if not payload then return end
    -- basic validation
    if type(payload.fps) ~= "number" or type(payload.particleCount) ~= "number" then return end
    if Metrics then
        pcall(function()
            Metrics:Increment("fps_samples")
            Metrics:Increment("last_fps", payload.fps)
            Metrics:Increment("particle_count_samples", payload.particleCount)
        end)
    end
    -- print summary occasionally
    if math.random() < 0.02 then
        print("Profiler: player", player.Name, "fps", math.floor(payload.fps), "particles", payload.particleCount)
    end
end)







