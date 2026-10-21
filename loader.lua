-- ============================================================
-- LOADER — execute semua tab dari GitHub raw
-- USER: xcrazb | REPO: main | BRANCH: main
-- ============================================================

local BASE = "https://raw.githubusercontent.com/xcrazb/main/main/"

local FILES = {
    "core.lua",
    "webhook.lua",
    "1.lua",
    "tab_shop.lua",
    "tab_event.lua",
    "tab_food_craft.lua",
}

_G.APM = _G.APM or {}
_G.APM.base = BASE

local function loadFile(name)
    local url = BASE .. name
    local ok, src = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not src or src == "" or src:match("^404:") or src:match("<html") then
        warn("[Loader] ❌ Gagal ambil: " .. url)
        warn("[Loader] Cek: user='xcrazb' repo='main' branch='main' file='" .. name .. "'")
        return false
    end
    local fn, err = loadstring(src, "=" .. name)
    if not fn then
        warn("[Loader] ❌ Syntax error di " .. name .. ": " .. tostring(err))
        return false
    end
    local ok2, err2 = pcall(fn)
    if not ok2 then
        warn("[Loader] ❌ Runtime error di " .. name .. ": " .. tostring(err2))
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
