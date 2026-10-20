-- ============================================================
-- LOADER — execute semua tab dari GitHub raw
-- Ganti USER/REPO/BRANCH sesuai repo kamu
-- ============================================================

local BASE = "https://raw.githubusercontent.com/USER/REPO/main/"

local FILES = {
    "core.lua",
    "tab_mutasi.lua",
    "tab_shop.lua",
    "tab_event.lua",
    "tab_food_craft.lua",
}

-- Shared table untuk komunikasi antar file
-- (dipakai semua file sebagai global)
_G.APM = _G.APM or {}
_G.APM.base = BASE

local function loadFile(name)
    local url = BASE .. name
    local ok, src = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not src or src == "" then
        warn("[Loader] Gagal ambil: " .. url)
        return false
    end
    local fn, err = loadstring(src, "=" .. name)
    if not fn then
        warn("[Loader] Syntax error di " .. name .. ": " .. tostring(err))
        return false
    end
    local ok2, err2 = pcall(fn)
    if not ok2 then
        warn("[Loader] Runtime error di " .. name .. ": " .. tostring(err2))
        return false
    end
    print("[Loader] ✓ " .. name)
    return true
end

for _, f in ipairs(FILES) do
    if not loadFile(f) then
        warn("[Loader] Berhenti di " .. f)
        break
    end
    task.wait(0.1)
end

print("[Loader] Selesai — semua tab loaded")
