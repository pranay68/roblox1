-- Metrics.lua
-- Simple server-side metrics and logging helper. Place in ServerScriptService as a ModuleScript.

local Metrics = {}
local counters = {}

function Metrics:Increment(name, amount)
    amount = amount or 1
    counters[name] = (counters[name] or 0) + amount
end

function Metrics:Get(name)
    return counters[name] or 0
end

function Metrics:Log(info)
    -- structured console log; can be extended to send to an external logging service
    print(string.format("[Metrics] %s | data=%s", tostring(info), tostring(os.time())))
end

function Metrics:ReportAll()
    print("[Metrics] Report")
    for k,v in pairs(counters) do
        print("  ", k, v)
    end
end

return Metrics


