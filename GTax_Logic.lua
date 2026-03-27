-- GTax_Logic.lua
-- Pure logic: suggested deposit, time formatting, deposit sums, color, record/reset

local addonName, GTax = ...
GTax = GTax or {}

function GTax.getSuggestedDeposit(money, pct)
    if type(money) ~= "number" or money <= 0 then return 0 end
    local rate = (pct or 3) / 100
    return math.floor((money * rate) + 0.5)
end

function GTax.formatTimeSinceDeposit(timestamp)
    if type(timestamp) ~= "number" or timestamp <= 0 then return "Never" end
    local now = time()
    if type(now) ~= "number" then return "Unknown" end
    local elapsed = now - timestamp
    if elapsed < 0 then elapsed = 0 end
    local days = math.floor(elapsed / 86400)
    local hours = math.floor((elapsed % 86400) / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    return string.format("%dd %dh %dm ago", days, hours, minutes)
end

function GTax.getStartOfDay()
    local d = date("*t")
    return time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
end

function GTax.getStartOfWeek()
    local d = date("*t")
    local wday = d.wday -- 1=Sunday
    local dayOffset = (wday == 1) and 6 or (wday - 2) -- Monday as start
    local startOfDay = time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
    return startOfDay - (dayOffset * 86400)
end

function GTax.getDepositSums(entry)
    local history = entry.depositHistory
    if type(history) ~= "table" then return 0, 0, 0 end
    local todayStart = GTax.getStartOfDay()
    local weekStart = GTax.getStartOfWeek()
    local today, week, total = 0, 0, 0
    for _, record in ipairs(history) do
        local amt = record.amount or 0
        local ts = record.timestamp or 0
        total = total + amt
        if ts >= weekStart then week = week + amt end
        if ts >= todayStart then today = today + amt end
    end
    return today, week, total
end

function GTax.getDepositColor(timestamp)
    if type(timestamp) ~= "number" or timestamp <= 0 then return 1, 0, 0 end
    local elapsed = time() - timestamp
    local days = elapsed / 86400
    if days <= 1 then return 0, 1, 0
    elseif days >= 7 then return 1, 0, 0 end
    local t = (days - 1) / 6
    return t, 1 - t, 0
end

function GTax.recordDeposit(entry, amount)
    if type(entry.depositHistory) ~= "table" then entry.depositHistory = {} end
    if type(amount) == "number" and amount > 0 then
        table.insert(entry.depositHistory, { amount = amount, timestamp = time() })
    end
end

function GTax.resetTracker(reason, fingerprint, depositAmount)
    local entry = GTax.ensureDB()
    local timeSince = GTax.formatTimeSinceDeposit(entry.lastResetAt)
    if depositAmount then
        -- Guild bank deposit: only reset since last deposit, update lastResetAt and fingerprint
        GTax.recordDeposit(entry, depositAmount)
        if IsInGuild and IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage then
            local name = UnitName("player") or "Unknown"
            local entry = GTax.ensureDB()
            local showSuggested = true
            if type(entry.show) == "table" and entry.show.suggestedSinceLast == false then
                showSuggested = false
            end
            local suggested = 0
            if showSuggested and GTax.getSuggestedDeposit then
                local money = entry.earnedSinceDeposit or 0
                local pct = entry.taxPercent or 3
                suggested = GTax.getSuggestedDeposit(money, pct)
            end
            local function fmt(money)
                local g = math.floor(money / (100 * 100))
                local s = math.floor((money / 100) % 100)
                local c = money % 100
                local parts = {}
                local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
                local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
                local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
                if g > 0 then table.insert(parts, g .. goldIcon) end
                if s > 0 or g > 0 then table.insert(parts, s .. silverIcon) end
                table.insert(parts, c .. copperIcon)
                return table.concat(parts, " ")
            end
            local msg
            if showSuggested then
                local pct = entry.taxPercent or 3
                local indent = string.rep(" ", 11)
                local lines = {
                    string.format("|cff5fd7ff[GTax]|r |cff00ff00%s|r contributed to the guild bank!", name),
                    indent .. "Amount: " .. fmt(depositAmount),
                    indent .. "Suggested: " .. fmt(suggested) .. ", at " .. pct .. "%",
                    indent .. "Previous contribution was " .. timeSince .. ".",
                }
                for i, line in ipairs(lines) do
                    C_ChatInfo.SendAddonMessage("GTax", line, "GUILD")
                end
            else
                local indent = string.rep(" ", 11)
                local lines = {
                    string.format("|cff5fd7ff[GTax]|r |cff00ff00%s|r contributed to the guild bank!", name),
                    indent .. "Amount: " .. fmt(depositAmount),
                    indent .. "Previous contribution was " .. timeSince .. ".",
                }
                for i, line in ipairs(lines) do
                    C_ChatInfo.SendAddonMessage("GTax", line, "GUILD")
                end
            end
            -- Do not print locally; handled by addon message handler
        end
        entry.lastResetAt = time()
        entry.earnedSinceDeposit = 0
        if fingerprint then entry.lastDepositFingerprint = fingerprint end
        -- Do NOT clear earningsHistory (today/week)
    elseif reason == "manual" then
        -- Manual reset: clear all earnings, but do NOT update lastResetAt or fingerprint
        entry.earnedSinceDeposit = 0
        entry.earningsHistory = {} -- clear earnings for today/week
    else
        -- Other resets (e.g., today/week): just reset since last
        entry.earnedSinceDeposit = 0
    end
    if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
    GTax.printMessage("Tracker reset" .. (reason and (" (" .. reason .. ")") or "") .. ".")
end
