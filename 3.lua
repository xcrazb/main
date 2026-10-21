-- ============================================================
-- TAB EVENT (Halloween)
-- ============================================================

local APM = _G.APM
local S = APM.S

local EvTab = APM.Window:CreateTab("Event", 4483362458)

EvTab:CreateSection("🎃 Halloween Event")
APM.mkToggle(EvTab, "Collect Halloween Fish", "HWCollect", false, function(v)
    S.hwCollect = v
    if v then APM.hwStartCollect() else APM.hwStopCollect() end
end)
APM.mkToggle(EvTab, "Feed Tree + Pickup All", "HWFeed", false, function(v)
    S.hwFeed = v
    if v then APM.hwStartFeed() else APM.hwStopFeed() end
end)
APM.mkButton(EvTab, "💰 Pickup All (Manual)", function()
    task.spawn(function() local c = APM.hwPickupAll(); print(string.format("[Pickup] Claimed %d", c)) end)
end)

local evLbl = APM.mkLabel(EvTab, "[Event] IDLE")
task.spawn(function()
    while true do
        task.wait(1)
        pcall(function() evLbl:Set(string.format("[Event] Collect:%s | Feed+Pickup:%s",
            S.hwCollect and "ON" or "OFF", S.hwFeed and "ON" or "OFF")) end)
    end
end)

print("[Tab Event] Loaded")
