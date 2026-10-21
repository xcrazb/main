-- ============================================================
-- TAB FOOD & CRAFT
-- ============================================================

local APM = _G.APM
local S, CFG = APM.S, APM.CFG

local FcTab = APM.Window:CreateTab("Food & Craft", 4483362458)

FcTab:CreateSection("🍔 Food Tray")
APM.mkToggle(FcTab, "Auto Place Food Tray", "FoodOn", false, function(v) CFG.Food.On = v; S.nextFood = 0 end)
APM.mkInput(FcTab, "Food Type", "SupremeFoodTray", function(t) if t and t ~= "" then CFG.Food.Type = t end end)
APM.mkInput(FcTab, "Food Category", "booster", function(t) if t and t ~= "" then CFG.Food.Cat = t end end)

FcTab:CreateSection("⚙️ Craft")
APM.mkToggle(FcTab, "Auto Craft", "CraftOn", false, function(v)
    CFG.Craft.On = v; S.nextCraftTry = 0
    if not v then S.craftPhase = "idle"; S.craftCd = 0 end
end)
APM.mkInput(FcTab, "Craft Item", "TimeJumper", function(t) if t and t ~= "" then CFG.Craft.Item = t end end)
APM.mkInput(FcTab, "Craft Category", "gear", function(t) if t and t ~= "" then CFG.Craft.Cat = t end end)

local fcLbl = APM.mkLabel(FcTab, "[Food & Craft] IDLE")
task.spawn(function()
    while true do
        task.wait(1)
        pcall(function() fcLbl:Set(string.format("[Food & Craft] Food:%s(%s) | Craft:%s(%s)",
            CFG.Food.On and "ON" or "OFF", CFG.Food.Type,
            CFG.Craft.On and ("ON " .. (S.craftCd > 0 and (math.floor(S.craftCd) .. "s") or "Ready")) or "OFF",
            CFG.Craft.Item)) end)
    end
end)

print("[Tab Food & Craft] Loaded")
