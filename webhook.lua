-- ============================================================
-- WEBHOOK — hanya kirim saat TARGET mutasi tercapai
-- URL diisi dari input UI tab Mutasi
-- ============================================================

local APM = _G.APM

APM.WEBHOOK_URL = ""        -- kosong, diisi dari UI
APM.webhookOn = true

APM.WH_COLOR = {
    target  = 10181046,     -- ungu
    info    = 3447003,      -- biru
    error   = 15158332,     -- merah
}

local lastSend = 0
local MIN_INTERVAL = 2

function APM.sendWebhook(title, description, color)
    if not APM.webhookOn then return end
    local url = APM.WEBHOOK_URL
    if not url or url == "" then
        warn("[Webhook] URL belum di-set — isi di tab Mutasi → 🔔 Webhook")
        return
    end
    if not url:match("^https://discord%.com/api/webhooks/") then
        warn("[Webhook] URL tidak valid")
        return
    end

    local now = os.clock()
    if now - lastSend < MIN_INTERVAL then return end
    lastSend = now

    local payload = {
        username = "Auto Pet Mutation",
        embeds = {{
            title = title or "Notifikasi",
            description = description or "",
            color = color or APM.WH_COLOR.info,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "by AutoMutasi" },
        }}
    }

    local ok, body = pcall(function()
        return game:GetService("HttpService"):JSONEncode(payload)
    end)
    if not ok then warn("[Webhook] JSON encode gagal"); return end

    task.spawn(function()
        local ok2, err = pcall(function()
            if typeof(request) == "function" then
                return request({ Url = url, Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" }, Body = body })
            elseif typeof(syn) == "table" and syn.request then
                return syn.request({ Url = url, Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" }, Body = body })
            elseif typeof(http) == "table" and http.request then
                return http.request({ Url = url, Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" }, Body = body })
            end
        end)
        if not ok2 then warn("[Webhook] Kirim gagal: " .. tostring(err)) end
    end)
end

print("[Webhook] Loaded — hanya kirim saat target tercapai")
