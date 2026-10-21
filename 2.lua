-- ============================================================
-- TAB SHOP (Auto Buy, Golden, FPS, Hide Fish)
-- ============================================================

local APM = _G.APM
local S, CFG = APM.S, APM.CFG

local ShopTab = APM.Window:CreateTab("Shop", 4483362458)

ShopTab:CreateSection("🛒 Auto Farm Shop")
APM.mkToggle(ShopTab, "Auto Buy Gear", "ShopGear", false, function(v) S.shopGear = v; S.nextGear = 0 end)
APM.mkToggle(ShopTab, "Auto Buy Bait", "ShopBait", false, function(v) S.shopBait = v; S.nextBait = 0 end)
APM.mkToggle(ShopTab, "Auto Buy Egg (Tropical/Exotic)", "ShopEgg", false, function(v) S.shopEgg = v; S.nextEgg = 0 end)

ShopTab:CreateSection("🥇 Golden Merchant")
APM.mkToggle(ShopTab, "Auto Buy Golden", "ShopGolden", false, function(v) S.goldenOn = v; S.nextGolden = 0 end)

ShopTab:CreateSection("⚡ Performance")
APM.mkToggle(ShopTab, "⚡ FPS Boost", "ShopFPS", false, function(v)
    task.spawn(function() if v then APM.boostFPS() else APM.unboostFPS() end end)
end)
APM.mkToggle(ShopTab, "🐟 Hide Fish", "ShopHideFish", false, function(v)
    task.spawn(function() if v then APM.hideFish() else APM.showFish() end end)
end)

local shopLbl = APM.mkLabel(ShopTab, "[Shop] IDLE")
task.spawn(function()
    while true do
        task.wait(1)
        pcall(function() shopLbl:Set(string.format("[Shop] Gear:%s Bait:%s Egg:%s | AFK:AUTO | Gold:%s | FPS:%s Fish:%s",
            S.shopGear and "ON" or "OFF", S.shopBait and "ON" or "OFF", S.shopEgg and "ON" or "OFF",
            S.goldenOn and (S.goldenActive and "ON" or "WAIT") or "OFF",
            S.fpsBoosted and "ON" or "OFF", S.fishHidden and "HIDDEN" or "SHOWN")) end)
    end
end)

print("[Tab Shop] Loaded")
