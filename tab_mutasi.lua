-- ============================================================
-- TAB MUTASI (Mode Gear + Mode DiamondCookie)
-- ============================================================

local APM = _G.APM
local R, S, CFG, lp = APM.R, APM.S, APM.CFG, APM.lp
local safeFire, safeInvoke = APM.safeFire, APM.safeInvoke

local MutTab = APM.Window:CreateTab("Mutasi", 4483362458)

-- ============================================================
-- MODE GEAR
-- ============================================================
MutTab:CreateSection("Mode Gear")

local function switchLO(idx)
    if S.curLO == idx then return true end
    local el = os.clock() - S.lastLOSwitch
    if el < CFG.Gear.LOSwitchDelay then task.wait(CFG.Gear.LOSwitchDelay - el) end
    local ok = pcall(function() R.switchLO:InvokeServer(idx) end)
    if ok then S.curLO = idx; S.lastLOSwitch = os.clock(); task.wait(CFG.Gear.LOSwitchDelay); return true end
    return false
end
local function ensureLO(idx) if S.curLO == idx then return true end return switchLO(idx) end

local function scanLowAge()
    local d = APM.getData(); if not d then return {} end
    local list = {}
    for id, pd in pairs(d.inventory.pets) do
        local a, m = APM.getAge(pd), APM.getMut(pd)
        if not APM.isDesired(m) and a < CFG.Gear.TargetAge then table.insert(list, {id=id, age=a}) end
    end
    table.sort(list, function(x,y) return x.age < y.age end)
    return list
end
local function scanForMut()
    local d = APM.getData(); if not d then return {} end
    local list = {}
    for id, pd in pairs(d.inventory.pets) do
        local a, m = APM.getAge(pd), APM.getMut(pd)
        if not APM.isDesired(m) and a >= CFG.Gear.TargetAge and not S.mutDone[id] and not S.mutInProg[id] then
            table.insert(list, {id=id, age=a})
        end
    end
    return list
end
local function countWave()
    local d = APM.getData(); local c, t = 0, 0
    if not d then return 0,0 end
    for id in pairs(S.wave) do
        t += 1
        local pd = d.inventory.pets[id]
        if pd and APM.getAge(pd) >= CFG.Gear.TargetAge then c += 1 end
    end
    return c, t
end
local function allMaxed()
    local d = APM.getData(); if not d then return false end
    local any = false
    for _, pd in pairs(d.inventory.pets) do
        if not APM.isDesired(APM.getMut(pd)) then any = true; if APM.getAge(pd) < CFG.Gear.TargetAge then return false end end
    end
    return any
end
local function allAchieved()
    local d = APM.getData(); if not d then return false end
    local t, tar = 0, 0
    for _, pd in pairs(d.inventory.pets) do
        t += 1; if APM.isDesired(APM.getMut(pd)) then tar += 1 end
    end
    return t > 0 and tar >= t
end

local function placePet(id)
    if S.placed[id] then return true end
    local d = APM.getData()
    if not d or not d.inventory.pets[id] then S.placed[id] = true; return true end
    pcall(function() R.equipTool:FireServer(id, "pet") end); task.wait(CFG.Gear.WaitAfterPlace)
    local ok = pcall(function() R.placePet:InvokeServer(id) end); task.wait(CFG.Gear.WaitAfterPlace)
    if ok then pcall(function() R.requestPos:InvokeServer(id) end); task.wait(0.3) end
    S.placed[id] = true; S.picked[id] = nil
    return ok
end
local function pickUp(id)
    if S.picked[id] then return true end
    local ok = pcall(function() R.pickUp:InvokeServer(id) end)
    if not ok then return false end
    S.picked[id] = true; S.placed[id] = nil
    return true
end

local function fireJumper(force)
    local now = os.clock()
    if not force and (now - S.lastJumper) < CFG.Gear.JumperCooldown then return false end
    if S.curLO ~= CFG.Gear.JumperLOA then return false end
    local d = APM.getData()
    if not d or not d.inventory.gears.TimeJumper or d.inventory.gears.TimeJumper.amount <= 0 then return false end
    local ok = pcall(function() R.useTimeWatch:FireServer("TimeJumper") end)
    if ok then S.lastJumper = now; S.jumperCnt += 1; S.boostJumperCnt += 1; return true end
    return false
end
local function doLOCycle()
    if S.boostLOSwitching then return end
    S.boostLOSwitching = true
    ensureLO(CFG.Gear.JumperLOB); task.wait(CFG.Gear.JumperSwitchDelay)
    ensureLO(CFG.Gear.JumperLOA); task.wait(CFG.Gear.JumperSwitchDelay)
    S.boostJumperCnt = 0; S.boostLOSwitching = false
end
local function resetWave() S.wave = {}; S.phase = "idle" end

local function placeNewWave()
    ensureLO(CFG.Gear.BoostLO)
    local c = scanLowAge(); if #c == 0 then S.phase = "done"; return false end
    local tp = {}
    for i = 1, math.min(CFG.Gear.MaxPlacePerWave, #c) do table.insert(tp, c[i]) end
    S.wave = {}; S.phase = "placing"
    local sc = 0
    for _, p in ipairs(tp) do
        if placePet(p.id) ~= false then S.wave[p.id] = true; sc += 1 end
        task.wait(0.2)
    end
    if sc == 0 then S.phase = "done"; return false end
    S.boostJumperCnt = 0; S.phase = "boosting"; return true
end
local function pickUpWave()
    for id in pairs(S.wave) do
        if pickUp(id) then S.totalBoost += 1 end
        task.wait(0.3)
    end
    resetWave()
end
local function insertPet(id)
    pcall(function() R.equipTool:FireServer(id, "pet") end); task.wait(0.5)
    local ok = pcall(function() R.startMut:InvokeServer(id) end)
    if ok then S.mutInProg[id] = true; S.mutDone[id] = true; return true end
    return false
end
local function doMut()
    local now = os.clock()
    if (now - S.lastMutAct) < CFG.Gear.MutationCooldown then return end
    local st = APM.machineState()
    if st == "Ready" then
        if not ensureLO(CFG.Gear.MutCollectLO) then return end
        local col = {}
        for id in pairs(S.mutInProg) do table.insert(col, id) end
        if pcall(function() R.collectMut:InvokeServer() end) then
            for _, id in ipairs(col) do S.totalMut += 1; S.mutDone[id] = nil end
            S.mutInProg = {}; S.lastMutAct = now
            task.wait(CFG.Gear.MutCollectSyncDelay)
        end
        return
    end
    if st == "InProgress" then
        if S.curLO ~= CFG.Gear.MutWaitLO then ensureLO(CFG.Gear.MutWaitLO) end
        return
    end
    if st == "Idle" then
        if next(S.mutInProg) ~= nil then S.mutInProg = {} end
        local c = scanForMut(); if #c == 0 then S.phase = "idle"; return end
        if not ensureLO(CFG.Gear.MutInsertLO) then return end
        if insertPet(c[1].id) then S.lastMutAct = now; task.wait(0.5); ensureLO(CFG.Gear.MutWaitLO) end
    end
end
local function boostLoop()
    ensureLO(CFG.Gear.BoostLO)
    while S.gearRun do
        task.wait(CFG.Gear.JumperInterval)
        if not APM.getData() then continue end
        if allAchieved() and next(S.wave) == nil then S.phase = "stopped"; S.gearRun = false; break end
        if S.cycle >= CFG.Gear.MaxCycles then S.phase = "stopped"; S.gearRun = false; break end
        if S.phase ~= "mutating" and allMaxed() and next(S.wave) == nil then
            if #scanForMut() > 0 then S.phase = "mutating"; ensureLO(CFG.Gear.MutInsertLO)
            else task.wait(10); S.phase = "idle" end
        end
        if S.phase == "mutating" then
            if #scanForMut() > 0 or APM.machineState() == "Ready" or APM.machineState() == "InProgress" then doMut()
            else
                if allAchieved() then S.phase = "stopped"; S.gearRun = false; break end
                S.cycle += 1; S.phase = "idle"; ensureLO(CFG.Gear.BoostLO)
            end
            continue
        end
        if S.phase == "idle" or S.phase == "done" then
            if #scanLowAge() > 0 then placeNewWave()
            elseif next(S.wave) ~= nil then
                local c, t = countWave(); if t > 0 and c >= t then pickUpWave() end
            end
        elseif S.phase == "placing" then S.phase = "boosting"
        elseif S.phase == "boosting" then
            local c, t = countWave()
            if t > 0 and c >= t then pickUpWave(); S.boostJumperCnt = 0
            else
                if S.boostJumperCnt >= CFG.Gear.JumperBeforeSwitch and not S.boostLOSwitching then doLOCycle()
                else
                    if S.curLO ~= CFG.Gear.JumperLOA then ensureLO(CFG.Gear.JumperLOA) end
                    fireJumper(false)
                end
            end
        end
    end
end

APM.mkToggle(MutTab, "[Gear] Aktifkan", "BoostToggle", false, function(v)
    S.gearRun = v
    if v then
        resetWave(); S.placed = {}; S.picked = {}; S.mutInProg = {}; S.mutDone = {}
        S.curLO = nil; S.lastLOSwitch = 0; S.totalBoost = 0; S.totalMut = 0; S.cycle = 0
        S.jumperCnt = 0; S.lastJumper = 0; S.lastMutAct = 0; S.boostJumperCnt = 0; S.boostLOSwitching = false
        task.spawn(boostLoop)
    end
end)
MutTab:CreateDropdown({
    Name = "[Gear] Target Mutasi",
    Options = {"Diamond","Silver","Radiant","Huge","Lightning","Guardian","Gold","Tiny","Aquatic","Tamed"},
    CurrentOption = {}, MultipleOptions = true,
    Callback = function(sel) S.selMut = {}; for _, m in ipairs(sel) do S.selMut[m] = true end end,
})
local gearLabel = APM.mkLabel(MutTab, "[Gear] IDLE")
task.spawn(function()
    while true do
        task.wait(1)
        local c, t = countWave()
        pcall(function() gearLabel:Set(string.format("[Gear] %s | Wave %d/%d | Mut %d | LO %s | Jump %d/%d",
            S.phase:upper(), c, t, S.totalMut, tostring(S.curLO), S.boostJumperCnt, CFG.Gear.JumperBeforeSwitch)) end)
    end
end)

-- ============================================================
-- MODE DIAMONDCOOKIE
-- ============================================================
MutTab:CreateSection("Mode DiamondCookie")

local DCmod = {
    getPlayerData = nil, getSharedTime = nil, PET_MUT_TIME = nil, PetMuts = nil,
    getPetAge = nil, MAX_AGE = nil, invState = nil,
}
pcall(function() DCmod.getPlayerData = require(APM.RS.TS.state["player-data"]).getPlayerData end)
pcall(function() DCmod.getSharedTime = require(game:GetService("StarterPlayer").StarterPlayerScripts.TS.systems.core.sharedTime).getSharedTime end)
pcall(function() DCmod.PET_MUT_TIME = require(APM.RS.TS.constants).PET_MUTATION_TIME end)
pcall(function() DCmod.PetMuts = require(APM.RS.TS.lists.game["pet-mutations"]).PetMutations end)
pcall(function() local v = require(APM.RS.TS.utils["pet-age.utils"]); DCmod.getPetAge = v.getPetAgeFromData; DCmod.MAX_AGE = v.MAX_AGE end)
pcall(function() DCmod.invState = require(game.Players.LocalPlayer.PlayerScripts.TS.ui.features.toolbar["inventory.state"]) end)

local function dcAgeReady() return DCmod.getPlayerData and DCmod.getPetAge and DCmod.MAX_AGE end
local function dcModulesReady() return DCmod.getPlayerData and DCmod.getSharedTime and DCmod.PET_MUT_TIME end
local function dcPetAge(id)
    if not dcAgeReady() then return nil end
    local ok, d = pcall(function() return DCmod.getPlayerData(lp) end)
    if not ok or not d or not d.inventory or not d.inventory.pets then return nil end
    local pd = d.inventory.pets[id]; if not pd then return nil end
    local ok2, a = pcall(function() return DCmod.getPetAge(pd) end)
    return ok2 and a or nil
end
local function dcMachineState()
    if not dcModulesReady() then return "Unknown", 0 end
    local ok, d = pcall(function() return DCmod.getPlayerData(lp) end)
    if not ok or not d then return "Unknown", 0 end
    local pm = d.petMutation; if pm == nil then return "Idle", 0 end
    local ok2, st = pcall(DCmod.getSharedTime)
    if not ok2 or not st then return "InProgress", 0 end
    local el = st - pm.timeStarted
    local total = DCmod.PET_MUT_TIME / (pm.depletionRate or 1)
    if el >= total then return "Ready", 0 end
    return "InProgress", math.max(0, total - el)
end
local function dcParseMut(r)
    if r == nil or r == false then return nil end
    if type(r) == "string" then return r end
    if type(r) == "table" then return r.mutation or r.mutationType or r.name or r.type end
    return tostring(r)
end
local function dcIsTarget(m)
    if not m or next(S.dcTargetMut) == nil then return false end
    return S.dcTargetMut[m] == true
end
local function dcAllHit()
    for _, id in ipairs(S.dcOrder) do local p = S.dcQueue[id]; if p and not p.targetHit then return false end end
    return true
end
local function dcLabel(p)
    local m = (p.mutation and p.mutation ~= "" and p.mutation ~= "None") and p.mutation or "No Mutation"
    return string.format("%s [%s]", p.displayName, m)
end
local function dcScanPets()
    if not DCmod.invState then return {} end
    local ok, st = pcall(function() return DCmod.invState.inventoryStackedData() end)
    if not ok or not st then return {} end
    local pets, seen = {}, {}
    for _, item in pairs(st) do
        local tt = tostring(item.toolType):lower()
        if tt:find("pet") and item.items and item.items[1] then
            local pid = item.items[1].id
            if pid and not seen[pid] then
                seen[pid] = true
                local pd = item.items[1].data
                local mn = "None"
                if pd and pd.mutation and pd.mutation ~= "" then mn = tostring(pd.mutation)
                elseif pd and pd.mutations and type(pd.mutations) == "table" then
                    for _, v in pairs(pd.mutations) do if v and v ~= "" and v ~= "None" then mn = tostring(v); break end end
                end
                table.insert(pets, {id=pid, displayName=item.displayName or item.itemName, mutation=mn,
                    mutationCount=pd and pd.mutationCount or 0})
            end
        end
    end
    table.sort(pets, function(a,b)
        if a.displayName ~= b.displayName then return a.displayName < b.displayName end
        return (a.mutationCount or 0) > (b.mutationCount or 0)
    end)
    return pets
end
local function dcEquipPet(id) safeFire(R.equipTool, id, "pet"); task.wait(CFG.DC.DelayEquip) end
local function dcEquipGear() safeFire(R.equipTool, CFG.DC.Gear, "gear"); task.wait(CFG.DC.DelayEquip) end
local function dcUseGear(id) return safeFire(R.usePetGear, id) end
local function dcSwitchSlot(s) local ok = safeInvoke(R.switchLO, s); task.wait(CFG.DC.DelaySlot); return ok end
local function dcInsert(id) return safeInvoke(R.startMut, id) end
local function dcPickUp(id) return safeInvoke(R.pickUp, id) end
local function dcCollect()
    if not R.collectMut then return false end
    for _ = 1, 5 do
        local ok, r = pcall(function() return R.collectMut:InvokeServer() end)
        if ok and r ~= false and r ~= nil then return true, r end
        task.wait(5)
    end
    return false
end

local function dcDoAge()
    for _, id in ipairs(S.dcOrder) do
        if not S.dcRun then return false end
        local p = S.dcQueue[id]
        if p and not p.targetHit then
            dcSwitchSlot(CFG.DC.AgeSlot); task.wait(1)
            dcEquipPet(id); safeInvoke(R.placePet, id); task.wait(CFG.DC.DelayStep)
            if S.dcRun then
                local gc, max = 0, DCmod.MAX_AGE or 50
                while S.dcRun do
                    local a = dcPetAge(id); if a == nil or a >= max then break end
                    gc += 1; dcEquipGear(); dcUseGear(id); S.dcStats.Gear += 1
                    task.wait(CFG.DC.DelayUse)
                    if gc >= CFG.DC.SafetyMaxGear then break end
                end
                dcPickUp(id); task.wait(1.5)
            end
        end
    end
    return true
end

local function dcDoInsert()
    for _, id in ipairs(S.dcOrder) do
        if not S.dcRun then return false end
        local p = S.dcQueue[id]
        if p and not p.targetHit then
            local chk, idle = 0, false
            while chk < 60 do
                if not S.dcRun then return false end
                local ms = dcMachineState()
                if ms == "Idle" then idle = true; break
                elseif ms == "Ready" then dcSwitchSlot(CFG.DC.CollectSlot); task.wait(2); dcCollect(); task.wait(3)
                elseif ms == "InProgress" then dcSwitchSlot(CFG.DC.WaitSlot); task.wait(5) end
                chk += 5
            end
            if not idle then S.dcStats.Fail += 1
            else
                dcPickUp(id); task.wait(2)
                dcSwitchSlot(CFG.DC.InsertSlot); task.wait(1)
                dcEquipPet(id); task.wait(2)
                if not S.dcRun then return false end
                local iOk, iRes = false, nil
                for att = 1, 3 do
                    if not S.dcRun then return false end
                    iOk, iRes = dcInsert(id)
                    if iOk and iRes ~= false and iRes ~= nil then break end
                    if att < 3 then task.wait(2); dcPickUp(id); task.wait(2); dcEquipPet(id); task.wait(2); dcSwitchSlot(CFG.DC.InsertSlot); task.wait(1) end
                end
                if not iOk or iRes == false or iRes == nil then S.dcStats.Fail += 1
                else
                    dcSwitchSlot(CFG.DC.WaitSlot)
                    if S.dcRun then
                        local ready = false
                        while S.dcRun do
                            local ms = dcMachineState()
                            if ms == "Ready" then ready = true; break elseif ms == "Idle" then break end
                            task.wait(CFG.DC.PollInterval)
                        end
                        if ready then
                            dcSwitchSlot(CFG.DC.CollectSlot); task.wait(CFG.DC.DelayCollect)
                            if not S.dcRun then return false end
                            local cok, cr = dcCollect()
                            if not cok then S.dcStats.Fail += 1
                            else
                                local m = dcParseMut(cr)
                                S.dcStats.Mut += 1; p.mutations = (p.mutations or 0) + 1; p.lastMutation = m
                                if dcIsTarget(m) then p.targetHit = true; p.locked = true end
                                if dcAllHit() then return "ALL_DONE" end
                                local cw = 0
                                while cw < 30 do
                                    if not S.dcRun then return false end
                                    if dcMachineState() == "Idle" then break end
                                    task.wait(3); cw += 3
                                end
                                task.wait(CFG.DC.DelayAfterCollect)
                            end
                        else S.dcStats.Fail += 1 end
                    end
                end
            end
        end
    end
    return "DONE"
end

local function dcRunBatch()
    if not S.dcRun then return end
    if dcAllHit() then S.dcRun = false; return end
    S.dcBatch += 1; S.dcPhase = "age"
    if not dcDoAge() or not S.dcRun then return end
    S.dcPhase = "insert"
    if dcDoInsert() == "ALL_DONE" then S.dcRun = false; return end
    task.wait(CFG.DC.DelayStep)
end
local function dcStart()
    if S.dcRun then return end
    S.dcRun = true; S.dcBatch = 0
    for _, id in ipairs(S.dcOrder) do
        local p = S.dcQueue[id]
        if p then p.mutations = 0; p.targetHit = false; p.locked = false end
    end
    task.spawn(function()
        while S.dcRun do
            local ok = pcall(dcRunBatch)
            if not ok then S.dcStats.Fail += 1; task.wait(5) end
            if not S.dcRun then break end
            task.wait(CFG.DC.DelayStep)
        end
        S.dcRun = false
    end)
end
local function dcUpdateQueue()
    S.dcQueue = {}; S.dcOrder = {}
    for _, p in ipairs(S.dcPetList) do
        if S.dcPetSel[p.id] then
            S.dcQueue[p.id] = {id=p.id, displayName=p.displayName, mutations=0, targetHit=false, locked=false}
            table.insert(S.dcOrder, p.id)
        end
    end
end

local dcFallback = {"Tiny","Gold","Diamond","Rainbow","Mythical","Divine","Celestial","Galaxy","Shadow","Frost","Fire","Nature"}
local function dcMutList()
    local list = {}
    if DCmod.PetMuts then for k, d in pairs(DCmod.PetMuts) do table.insert(list, d.name or k) end; table.sort(list) end
    return #list > 0 and list or dcFallback
end

APM.mkToggle(MutTab, "[DiamondCookie] Aktifkan", "DCToggle", false, function(v)
    if v then
        if #S.dcOrder == 0 then warn("[DC] Pilih pet dulu!"); return end
        if next(S.dcTargetMut) == nil then warn("[DC] Pilih target mutation dulu!"); return end
        S.dcStats = {Mut=0, Gear=0, Fail=0}; dcStart()
    else S.dcRun = false end
end)
local dcPetOpts = {}
local dcPetDD = MutTab:CreateDropdown({
    Name = "[DiamondCookie] Pilih Pet", Options = {}, CurrentOption = {}, MultipleOptions = true,
    Callback = function(sel)
        S.dcPetSel = {}
        for _, lbl in ipairs(sel) do for _, p in ipairs(S.dcPetList) do if dcLabel(p) == lbl then S.dcPetSel[p.id] = true; break end end end
        dcUpdateQueue()
    end,
})
APM.mkButton(MutTab, "[DiamondCookie] Scan Pet", function()
    if S.dcRun then return end
    S.dcPetList = dcScanPets(); dcPetOpts = {}
    for _, p in ipairs(S.dcPetList) do table.insert(dcPetOpts, dcLabel(p)) end
    pcall(function() dcPetDD:Refresh(dcPetOpts) end)
end)
MutTab:CreateDropdown({
    Name = "[DiamondCookie] Target Mutation", Options = dcMutList(), CurrentOption = {}, MultipleOptions = true,
    Callback = function(sel) S.dcTargetMut = {}; for _, m in ipairs(sel) do S.dcTargetMut[m] = true end end,
})
local dcLabelUI = APM.mkLabel(MutTab, "[DC] IDLE")
task.spawn(function()
    while true do
        task.wait(1)
        local hit, tot = 0, #S.dcOrder
        for _, id in ipairs(S.dcOrder) do local p = S.dcQueue[id]; if p and p.targetHit then hit += 1 end end
        local ms = dcMachineState()
        pcall(function() dcLabelUI:Set(string.format("[DC] %s | Batch %d | Mut %d | Gear %d | Fail %d | Hit %d/%d | Mesin %s",
            S.dcRun and "RUNNING" or "IDLE", S.dcBatch, S.dcStats.Mut, S.dcStats.Gear, S.dcStats.Fail, hit, tot, tostring(ms or "-"))) end)
    end
end)

print("[Tab Mutasi] Loaded")
