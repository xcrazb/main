-- ============================================================
-- CORE — shared services, remote, window, state, helpers, scheduler
-- ============================================================

local APM = _G.APM

-- ---------- SERVICES ----------
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local VIM = game:GetService("VirtualInputManager")
local lp = Players.LocalPlayer

APM.Players = Players
APM.RS = RS
APM.CS = CS
APM.UIS = UIS
APM.Lighting = Lighting
APM.VIM = VIM
APM.lp = lp

-- ---------- CONFIG ----------
APM.CFG = {
    Gear = {
        TargetAge = 50, MaxPlacePerWave = 4, JumperInterval = 1,
        WaitAfterPlace = 0.2, JumperCooldown = 1, MutationCooldown = 2,
        BoostLO = 1, MutInsertLO = 0, MutWaitLO = 3, MutCollectLO = 0,
        LOSwitchDelay = 0.5, MutCollectSyncDelay = 1.5,
        MaxCycles = 999, JumperBeforeSwitch = 5,
        JumperLOA = 1, JumperLOB = 0, JumperSwitchDelay = 1,
    },
    DC = {
        Gear = "DiamondCookie", SafetyMaxGear = 23,
        AgeSlot = 2, InsertSlot = 0, WaitSlot = 3, CollectSlot = 0,
        DelayEquip = 0.1, DelayUse = 0.2, DelayStep = 1, DelaySlot = 0.1,
        DelayCollect = 1.5, DelayAfterCollect = 1.5, PollInterval = 3,
    },
    Shop = {
        Interval = 5, BuyAll = true, BuyDelay = 0.15, StockTTL = 1.5,
        AfkInt = 240, SchedulerTick = 0.5,
        GoldenInterval = 3, GoldenIdleInterval = 10, GoldenBuyDelay = 0.25,
        GoldenBulkLoopDelay = 0.4, GoldenMaxPass = 8,
        GearList = {"NetMover","FoodScoop","MagnifyingGlass","TeleportWand","StarLock","TradingTicket",
            "BasicAutoFeeder","AdvancedAutoFeeder","SupremeAutoFeeder","ExtremeAutoFeeder","GodlyAutoFeeder",
            "BasicFoodTray","AdvancedFoodTray","SupremeFoodTray","XpCookie","PetToy","PetWhistle",
            "GoldenCookie","EggHatcher","EggIncubator","MutationBeacon","StormHorn"},
        EggWL = {"Tropical", "Exotic"},
    },
    Food = { On = false, Int = 300, Type = "SupremeFoodTray", Cat = "booster",
        Pos = Vector3.new(10.86, -0.012, -11) },
    Craft = { On = false, Item = "TimeJumper", Cat = "gear",
        Mats = {{n="TeleportWand",a=10},{n="MagnifyingGlass",a=25},{n="SupremeAutoFeeder",a=1}} },
}

-- ---------- STATE ----------
APM.S = {
    gearRun = false, wave = {}, phase = "idle", placed = {}, picked = {},
    selMut = {}, mutInProg = {}, mutDone = {}, lastMutAct = 0,
    curLO = nil, lastLOSwitch = 0, totalBoost = 0, totalMut = 0, cycle = 0,
    jumperCnt = 0, lastJumper = 0, boostJumperCnt = 0, boostLOSwitching = false,
    dcRun = false, dcQueue = {}, dcOrder = {}, dcBatch = 0, dcPhase = "idle",
    dcTargetMut = {}, dcPetList = {}, dcPetSel = {},
    dcStats = { Mut=0, Gear=0, Fail=0 },
    shopGear = false, shopBait = false, shopEgg = false,
    shopGearTot = 0, shopBaitTot = 0, shopEggTot = 0,
    afkOn = true, nextGear = 0, nextBait = 0, nextEgg = 0, nextAfk = 0,
    nextFood = 0, nextGolden = 0, goldenOn = false, goldenActive = false,
    stockCache = {},
    hwCollect = false, hwFeed = false, hwThread1 = nil, hwThread2 = nil,
    fpsBoosted = false, fpsOrig = {}, fpsHidden = {}, fishHidden = false, hiddenFish = {},
    craftPhase = "idle", craftCd = 0, nextCraftTry = 0,
}

-- ---------- REMOTES ----------
local function getRemo(name)
    return RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts")
        :WaitForChild("remo"):WaitForChild("src"):WaitForChild("container"):WaitForChild(name)
end

APM.R = {
    useTimeWatch = getRemo("gear.useTimeWatch"),
    equipTool    = getRemo("tools.equipTool"),
    placePet     = getRemo("pets.placePetFromInventory"),
    requestPos   = getRemo("pets.requestPosition"),
    pickUp       = getRemo("pets.pickUpPet"),
    switchLO     = getRemo("pets.switchPetLoadout"),
    startMut     = getRemo("pets.startMutation"),
    collectMut   = getRemo("pets.collectMutation"),
    usePetGear   = getRemo("pets.usePetGearOnPet"),
}

function APM.safeFire(r, ...)
    if not r then return false end
    local a = {...}
    return pcall(function() r:FireServer(table.unpack(a)) end)
end
function APM.safeInvoke(r, ...)
    if not r then return false end
    local a = {...}
    return pcall(function() return r:InvokeServer(table.unpack(a)) end)
end

-- ---------- WINDOW ----------
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
APM.Rayfield = Rayfield
APM.Window = Rayfield:CreateWindow({
    Name = "Auto Pet Mutation + Shop",
    LoadingTitle = "Memuat...", LoadingSubtitle = "by AutoMutasi",
    ConfigurationSaving = { Enabled = false }, KeySystem = false,
})

-- ---------- UI HELPERS ----------
function APM.mkToggle(tab, name, flag, def, cb)
    return tab:CreateToggle({ Name = name, CurrentValue = def or false, Flag = flag, Callback = cb })
end
function APM.mkButton(tab, name, cb) return tab:CreateButton({ Name = name, Callback = cb }) end
function APM.mkInput(tab, name, def, cb)
    return tab:CreateInput({ Name = name, CurrentValue = def, PlaceholderText = def, RemoveTextAfterFocusLost = false, Callback = cb })
end
function APM.mkLabel(tab, text) return tab:CreateLabel(text) end

-- ---------- PET / MUTATION UTILS ----------
local pdMod = require(RS.TS.state["player-data"])
local ageMod = require(RS.TS.utils["pet-age.utils"])
APM.pdMod = pdMod
APM.ageMod = ageMod

function APM.getData() return pdMod.getPlayerDataById(tostring(lp.UserId)) end
function APM.getAge(pd) local ok,a = pcall(ageMod.getPetAgeFromData, pd) return ok and a or 0 end
function APM.getMut(pd)
    if not pd then return "None" end
    for _, m in ipairs({pd.mutation, pd.mutations, pd.mutationType, pd.mutationName}) do
        if m and m ~= "" and m ~= "None" then
            if type(m) == "table" then
                for _, v in pairs(m) do if v and v ~= "" and v ~= "None" then return tostring(v) end end
            else return tostring(m) end
        end
    end
    return "None"
end
function APM.normMut(m) return string.lower(string.gsub(tostring(m or ""), "^%s*(.-)%s*$", "%1")) end
function APM.isDesired(m)
    local n = APM.normMut(m); if n == "none" or n == "" then return false end
    for t in pairs(APM.S.selMut) do if APM.normMut(t) == n then return true end end
    return false
end
function APM.machineState()
    local l = CS:GetTagged("petMutationLabel")
    if #l == 0 then return "Unknown" end
    local t = l[1].Text
    if t == "MUTATION" or t == "" then return "Idle"
    elseif t == "READY!" then return "Ready" else return "InProgress" end
end

-- ---------- SHOP / EVENT / FOOD-CRAFT MODULES ----------
local TS2 = RS:WaitForChild("TS", 30)
local remotes2, getPD2, shopRestock2, ShopType2, personalRestock2
local craftUtils2, travelMerch2

if TS2 then
    pcall(function() remotes2 = require(TS2:WaitForChild("remotes")).default end)
    pcall(function() getPD2 = require(TS2:WaitForChild("state"):WaitForChild("player-data")).getPlayerData end)
    pcall(function()
        local m = require(TS2:WaitForChild("state"):WaitForChild("shop-restock"))
        shopRestock2 = m.shopRestock; ShopType2 = m.ShopType; personalRestock2 = m.personalRestockItems
    end)
    pcall(function() craftUtils2 = require(TS2:WaitForChild("utils"):WaitForChild("crafting.utils")) end)
    pcall(function() travelMerch2 = require(TS2.state["travelling-merchant"]).travellingMerchants end)
end

APM.getPD2 = getPD2
APM.ShopType2 = ShopType2
APM.craftUtils2 = craftUtils2
APM.travelMerch2 = travelMerch2

local RC2 = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("remo"):WaitForChild("src"):WaitForChild("container")
APM.RC2 = RC2
APM.hwCollectFish = RC2:FindFirstChild("bait.collectFish")
APM.hwFeedAll     = RC2:FindFirstChild("halloween.feedTreeAll")
APM.hwClaimPickup = RC2:FindFirstChild("pickup.claimPickup")
APM.placeBldg     = RC2:WaitForChild("ponds.placeBuilding")
APM.craftSel       = RC2:WaitForChild("crafting.selectCraftingItem")
APM.craftSub       = RC2:WaitForChild("crafting.submitItems")
APM.craftStart     = RC2:WaitForChild("crafting.startCraft")
APM.craftCollect   = RC2:WaitForChild("crafting.collectCraft")
APM.goldenBuy     = RC2:WaitForChild("merchant.purchaseItem")
APM.buyGearR      = remotes2 and remotes2.shop.purchaseGear
APM.buyBaitR      = remotes2 and remotes2.shop.purchaseBait
APM.buyEggR       = remotes2 and remotes2.shop.purchaseEgg

APM.HW_BIT = 549755813888
pcall(function()
    local b = require(TS2:WaitForChild("lists"):WaitForChild("game"):WaitForChild("mutation-bits")).MUTATION_BITS
    if b and b.Halloween then APM.HW_BIT = 2 ^ b.Halloween end
end)

-- ---------- STOCK HELPERS ----------
local function stockKey(s, t) return s .. "|" .. t end
APM.stockKey = stockKey

function APM.getStock(shopType, itemType)
    local S = APM.S; local CFG = APM.CFG
    local k = stockKey(shopType, itemType)
    local now = os.clock()
    local c = S.stockCache[k]
    if c and (now - c.t) < CFG.Shop.StockTTL then return c.v end
    local val = 0
    if shopRestock2 and personalRestock2 and getPD2 then
        local ok, rs, pi, data = pcall(function() return shopRestock2(), personalRestock2(), getPD2(lp) end)
        if ok and rs and data then
            local nowT = os.time()
            local pr = data.personalRestocks and data.personalRestocks[shopType]
            local active = pr and pr.endTime and nowT < pr.endTime
            local uid = tostring(lp.UserId)
            local avail = active and (pi[uid] and pi[uid][shopType] and pi[uid][shopType][itemType] or 0)
                or (rs.availableItems and rs.availableItems[shopType] and rs.availableItems[shopType][itemType] or 0)
            local bought = 0
            local pur = data.shopPurchases and data.shopPurchases[shopType]
            if pur and pur.purchases then
                if active and pur.currentTimeSlot == pr.timeSlot then bought = pur.purchases[itemType] or 0
                elseif not active and pur.currentTimeSlot == rs.currentTimeSlot then bought = pur.purchases[itemType] or 0 end
            end
            val = math.max(0, avail - bought)
        end
    end
    S.stockCache[k] = {v=val, t=now}; return val
end

function APM.invStock(s, t) APM.S.stockCache[stockKey(s, t)] = nil end

function APM.availList(shopType, wl, bl)
    local list = {}
    if not shopRestock2 then return list end
    local rs = shopRestock2(); if not rs then return list end
    local shop = rs.availableItems and rs.availableItems[shopType]; if not shop then return list end
    local wlS, blS
    if wl and #wl > 0 then wlS = {} for _, v in ipairs(wl) do wlS[v] = true end end
    if bl and #bl > 0 then blS = {} for _, v in ipairs(bl) do blS[v] = true end end
    for t in pairs(shop) do
        local inc = true
        if wlS and not wlS[t] then inc = false end
        if inc and blS and blS[t] then inc = false end
        if inc then table.insert(list, t) end
    end
    return list
end

function APM.bulkBuy(list, buyFn, stockType, onFlag, counterKey)
    local S, CFG = APM.S, APM.CFG
    for _, t in ipairs(list) do
        if not onFlag() then return end
        local rem = APM.getStock(stockType, t)
        if rem > 0 then
            local max = CFG.Shop.BuyAll and (rem + 2) or 1
            for a = 1, max do
                if not onFlag() then return end
                if not pcall(buyFn, t) then break end
                APM.invStock(stockType, t)
                if counterKey then S[counterKey] = (S[counterKey] or 0) + 1 end
                if a < max then task.wait(CFG.Shop.BuyDelay) end
            end
        end
    end
end

-- ---------- ANTI-AFK ----------
local function sendKey(k, hold)
    pcall(function() VIM:SendKeyEvent(true, k, false, game); task.wait(hold); VIM:SendKeyEvent(false, k, false, game) end)
end
function APM.doJump()
    local ch = lp.Character; if not ch then return end
    local h = ch:FindFirstChildOfClass("Humanoid"); if not h or h.Health <= 0 then return end
    sendKey(Enum.KeyCode.Space, 0.05); task.wait(0.1)
    sendKey(Enum.KeyCode.W, 0.1); task.wait(0.1)
    pcall(function()
        local pos = UIS:GetMouseLocation()
        VIM:SendMouseMoveEvent(pos.X + 5, pos.Y + 5, game); task.wait(0.05)
        VIM:SendMouseMoveEvent(pos.X, pos.Y, game)
    end)
end

-- ---------- FOOD ----------
function APM.doFood()
    pcall(function() APM.placeBldg:InvokeServer(APM.CFG.Food.Cat, APM.CFG.Food.Type, APM.CFG.Food.Pos) end)
end

-- ---------- CRAFT ----------
local CRAFT_FB = {DiamondCookie=300, YolkBreaker=600, TimeJumper=600, ShieldLock=1500, NetRetractor=1500}
local function getCraftTime(id, cat)
    if craftUtils2 and craftUtils2.getCraftingTime then
        local ok, r = pcall(craftUtils2.getCraftingTime, id, cat); if ok and r then return r end
    end
    return CRAFT_FB[id] or 600
end
local function getCraftData()
    if not getPD2 then return nil end
    local d = getPD2(lp); if not d or not d.crafting then return nil end
    local c = d.crafting[APM.CFG.Craft.Cat]; if not c or not c.id then return nil end
    return c
end
function APM.isCraftActive() local c = getCraftData(); return c and c.timeStarted ~= nil end
function APM.getCraftRem()
    local c = getCraftData(); if not c or not c.timeStarted then return nil end
    local now = os.time(); local tt = getCraftTime(c.id, APM.CFG.Craft.Cat)
    local acc = c.accumulatedProgress or 0; local lu = c.lastProgressUpdate or c.timeStarted
    return math.max(0, tt - (acc + (now - lu) * (c.depletionRate or 1)))
end
function APM.doCraftOnce()
    local S, CFG = APM.S, APM.CFG
    S.craftPhase = "submitting"
    local ok = pcall(function() APM.craftSel:FireServer(CFG.Craft.Item, CFG.Craft.Cat) end); task.wait(0.3)
    if ok then
        local m, i = {}, 1
        for _, x in ipairs(CFG.Craft.Mats) do for _ = 1, x.a do m[i] = x.n; i += 1 end end
        ok = pcall(function() APM.craftSub:FireServer(m, CFG.Craft.Cat) end); task.wait(0.3)
    end
    if ok then ok = pcall(function() APM.craftStart:FireServer(CFG.Craft.Cat) end); task.wait(0.3) end
    if not ok then S.craftPhase = "idle"; return false end
    S.craftPhase = "crafting"; return true
end
function APM.collectCraft()
    APM.S.craftPhase = "collecting"
    local ok = pcall(function() APM.craftCollect:FireServer(APM.CFG.Craft.Cat) end)
    APM.S.craftPhase = "idle"; return ok
end

-- ---------- GOLDEN ----------
function APM.getGoldenStock()
    if not travelMerch2 then return {}, false end
    local d = travelMerch2(); if not d then return {}, false end
    local g = d.golden; if not g or not g.isActive or not g.availableStock then return {}, false end
    return g.availableStock, true
end
function APM.goldenBulk()
    local S, CFG = APM.S, APM.CFG
    local pass = 0
    while S.goldenOn and pass < CFG.Shop.GoldenMaxPass do
        pass += 1
        local map, active = APM.getGoldenStock(); if not active then break end
        local targets = {}
        for name, st in pairs(map) do if st > 0 then table.insert(targets, name) end end
        if #targets == 0 then break end
        for _, name in ipairs(targets) do
            if not S.goldenOn then break end
            pcall(function() APM.goldenBuy:FireServer("golden", name) end)
            task.wait(CFG.Shop.GoldenBuyDelay)
        end
        task.wait(CFG.Shop.GoldenBulkLoopDelay)
    end
end

-- ---------- HALLOWEEN ----------
local function isHW(mut)
    if not mut then return false end
    if typeof(mut) == "number" then return math.floor(mut / APM.HW_BIT) % 2 == 1 end
    if type(mut) == "table" then for _, v in pairs(mut) do if typeof(v) == "string" and v:lower() == "halloween" then return true end end end
    return false
end
function APM.hwCollectOnce()
    if not APM.hwCollectFish or not getPD2 then return 0 end
    local pd = getPD2(lp); if not pd or not pd.ponds then return 0 end
    local c = 0
    for _, pond in pairs(pd.ponds) do
        if type(pond) == "table" and pond.baits then
            for bId, bD in pairs(pond.baits) do
                if type(bD) == "table" and bD.fishes then
                    for fId, fD in pairs(bD.fishes) do
                        if type(fD) == "table" and isHW(fD.mutations) then
                            pcall(function() APM.hwCollectFish:FireServer(bId, fId) end); c += 1; task.wait(0.05)
                        end
                    end
                end
            end
        end
    end
    return c
end
function APM.hwFeed() if APM.hwFeedAll then pcall(function() APM.hwFeedAll:FireServer() end) end end
function APM.hwPickupAll()
    if not APM.hwClaimPickup then return 0 end
    local c = 0
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("BasePart") and obj.Name:sub(1, 7) == "Pickup_" then
            local uid = obj.Name:sub(8)
            if #uid > 0 then pcall(function() APM.hwClaimPickup:FireServer(uid) end); c += 1; task.wait(0.02) end
        end
    end
    return c
end
function APM.hwStartCollect()
    local S = APM.S
    if S.hwThread1 then pcall(function() task.cancel(S.hwThread1) end) end
    S.hwThread1 = task.spawn(function() while S.hwCollect do pcall(APM.hwCollectOnce); task.wait(2) end end)
end
function APM.hwStopCollect() local S = APM.S; S.hwCollect = false; if S.hwThread1 then pcall(function() task.cancel(S.hwThread1) end); S.hwThread1 = nil end end
function APM.hwStartFeed()
    local S = APM.S
    if S.hwThread2 then pcall(function() task.cancel(S.hwThread2) end) end
    S.hwThread2 = task.spawn(function()
        while S.hwFeed do pcall(APM.hwFeed); task.wait(1.5); pcall(APM.hwPickupAll); task.wait(1.5) end
    end)
end
function APM.hwStopFeed() local S = APM.S; S.hwFeed = false; if S.hwThread2 then pcall(function() task.cancel(S.hwThread2) end); S.hwThread2 = nil end end

-- ---------- FPS ----------
local Terrain = workspace:FindFirstChildOfClass("Terrain")
local function saveFpsOrig()
    APM.S.fpsOrig = {
        GlobalShadows = Lighting.GlobalShadows, Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
        EnvDiff = Lighting.EnvironmentDiffuseScale, EnvSpec = Lighting.EnvironmentSpecularScale,
    }
end
function APM.boostFPS()
    local S = APM.S
    if S.fpsBoosted then return end
    pcall(function()
        saveFpsOrig(); S.fpsBoosted = true
        Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0
        Lighting.Brightness = 2; Lighting.Ambient = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.FogEnd = 1e6; Lighting.FogStart = 1e6
        Lighting.EnvironmentDiffuseScale = 0; Lighting.EnvironmentSpecularScale = 0
        for _, e in ipairs(Lighting:GetChildren()) do
            pcall(function() if e:IsA("PostEffect") or e:IsA("Atmosphere") or e:IsA("Sky") then if e.Enabled ~= nil then e.Enabled = false end end end)
        end
        if Terrain then pcall(function() Terrain.WaterWaveSize = 0; Terrain.WaterWaveSpeed = 0; Terrain.WaterReflectance = 0; Terrain.WaterTransparency = 1; Terrain.Decoration = false end) end
        local ch = lp.Character
        for _, o in ipairs(workspace:GetDescendants()) do
            if o ~= ch and not (ch and o:IsDescendantOf(ch)) then
                pcall(function()
                    if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") or o:IsA("PointLight") or o:IsA("SpotLight") or o:IsA("SurfaceLight") then
                        if o.Enabled then o.Enabled = false; table.insert(S.fpsHidden, {obj=o, prop="Enabled", val=true}) end
                    end
                end)
            end
        end
    end)
end
function APM.unboostFPS()
    local S = APM.S
    if not S.fpsBoosted then return end
    S.fpsBoosted = false
    pcall(function()
        local o = S.fpsOrig
        Lighting.GlobalShadows = o.GlobalShadows ~= false
        Lighting.Brightness = o.Brightness or 2
        Lighting.Ambient = o.Ambient or Color3.fromRGB(70,70,70)
        Lighting.OutdoorAmbient = o.OutdoorAmbient or Color3.fromRGB(128,128,128)
        Lighting.FogEnd = o.FogEnd or 100000; Lighting.FogStart = o.FogStart or 0
        Lighting.EnvironmentDiffuseScale = o.EnvDiff or 1; Lighting.EnvironmentSpecularScale = o.EnvSpec or 1
        if Terrain then pcall(function() Terrain.WaterWaveSize = 0.15; Terrain.WaterWaveSpeed = 10; Terrain.WaterReflectance = 0.1; Terrain.WaterTransparency = 0.3; Terrain.Decoration = true end) end
        for _, e in ipairs(S.fpsHidden) do pcall(function() if e.obj and e.obj.Parent then e.obj[e.prop] = e.val end end) end
        S.fpsHidden = {}
    end)
end

-- ---------- HIDE FISH ----------
function APM.hideFish()
    local S = APM.S
    if S.fishHidden then return 0 end
    S.hiddenFish = {}; local c = 0
    local g = workspace:FindFirstChild("Game")
    if g then table.insert(S.hiddenFish, {obj=g, parent=g.Parent}); pcall(function() g.Parent = nil end); c += 1 end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Parent and obj.Parent.Name:lower():find("pond") then
            local n = obj.Name:lower()
            if n == "sardine" or n == "cod" or n == "salmon" or n:find("_gold") or n:find("_silver") then
                table.insert(S.hiddenFish, {obj=obj, parent=obj.Parent}); pcall(function() obj.Parent = nil end); c += 1
            end
        end
    end
    S.fishHidden = true; return c
end
function APM.showFish()
    local S = APM.S
    if not S.fishHidden then return 0 end
    local c = 0
    for _, e in ipairs(S.hiddenFish) do pcall(function() e.obj.Parent = e.parent or workspace; c += 1 end) end
    S.hiddenFish = {}; S.fishHidden = false; return c
end

-- ---------- SCHEDULER ----------
local schedRun = false
local function tickSched()
    local S, CFG = APM.S, APM.CFG
    local now = os.clock()
    if S.shopGear and now >= S.nextGear then S.nextGear = now + CFG.Shop.Interval task.spawn(function()
        APM.bulkBuy(CFG.Shop.GearList, APM.buyGearR, APM.ShopType2.Gear, function() return S.shopGear end, "shopGearTot") end)
    end
    if S.shopBait and now >= S.nextBait then S.nextBait = now + CFG.Shop.Interval task.spawn(function()
        APM.bulkBuy(APM.availList(APM.ShopType2.Bait, {}, {}), APM.buyBaitR, APM.ShopType2.Bait, function() return S.shopBait end, "shopBaitTot") end)
    end
    if S.shopEgg and now >= S.nextEgg then S.nextEgg = now + CFG.Shop.Interval task.spawn(function()
        APM.bulkBuy(APM.availList(APM.ShopType2.Eggs, CFG.Shop.EggWL, nil), APM.buyEggR, APM.ShopType2.Eggs, function() return S.shopEgg end, "shopEggTot") end)
    end
    if S.afkOn and now >= S.nextAfk then S.nextAfk = now + CFG.Shop.AfkInt task.spawn(APM.doJump) end
    if CFG.Food.On and now >= S.nextFood then S.nextFood = now + CFG.Food.Int task.spawn(APM.doFood) end
    if S.goldenOn and now >= S.nextGolden then
        local itv = S.goldenActive and CFG.Shop.GoldenInterval or CFG.Shop.GoldenIdleInterval
        S.nextGolden = now + itv
        task.spawn(function() local _, act = APM.getGoldenStock(); S.goldenActive = act; if act then APM.goldenBulk() end end)
    end
    if CFG.Craft.On then
        if APM.isCraftActive() then
            local rem = APM.getCraftRem()
            if rem then S.craftCd = rem; S.craftPhase = "crafting"; if rem <= 0 then task.spawn(APM.collectCraft) end
            else S.craftPhase = "idle"; S.craftCd = 0 end
        else
            if not S.nextCraftTry or now >= S.nextCraftTry then S.nextCraftTry = now + 2; task.spawn(APM.doCraftOnce) end
        end
    else S.craftCd = 0 end
end
function APM.startSched()
    if schedRun then return end
    schedRun = true
    task.spawn(function() while schedRun do tickSched(); task.wait(APM.CFG.Shop.SchedulerTick) end end)
end

-- Auto AFK langsung jalan
APM.S.afkOn = true
APM.startSched()
task.spawn(function() task.wait(2); pcall(APM.doJump); print("[AutoAFK] Aktif otomatis") end)

print("[Core] Loaded")
