-- GTax_Logic.lua
-- Pure logic: suggested contribution, time formatting, contribution sums, color, record/reset

local addonName, GTax = ...
GTax = GTax or {}

local function normalizePlayerName(name)
    if type(name) ~= "string" then return "Unknown" end
    local shortName = string.match(name, "^[^-]+") or name
    if shortName == "" then return "Unknown" end
    return shortName
end

local function parseNumber(value)
    local n = tonumber(value)
    if type(n) ~= "number" then return 0 end
    if n < 0 then return 0 end
    return math.floor(n)
end

function GTax.getLeaderboardSnapshot()
    local entry = GTax.ensureDB()
    local today, week, total = GTax.getDepositSums(entry)
    return {
        player = normalizePlayerName(UnitName("player") or "Unknown"),
        total = total,
        today = today,
        week = week,
        lastContributionAt = entry.lastResetAt or 0,
        unpaidLoans = entry.unpaidLoans or 0,
    }
end

function GTax.updateLeaderboardEntry(player, total, today, week, lastContributionAt, unpaidLoans)
    local entry = GTax.ensureDB()
    if type(entry.leaderboardCache) ~= "table" then entry.leaderboardCache = {} end
    local key = normalizePlayerName(player)
    local newTotal = parseNumber(total)

    -- Don't overwrite a remote entry with a lower total.
    -- This protects cached history when a guildmate's SavedVariables reset (reinstall, corrupt WTF).
    -- We skip the guard for the local player since we always trust our own live data.
    local localKey = normalizePlayerName(UnitName("player") or "")
    if key ~= localKey then
        local existing = entry.leaderboardCache[key]
        if existing and newTotal < existing.total then return end
    end

    entry.leaderboardCache[key] = {
        player = key,
        total = newTotal,
        today = parseNumber(today),
        week = parseNumber(week),
        lastContributionAt = parseNumber(lastContributionAt),
        unpaidLoans = parseNumber(unpaidLoans),
        updatedAt = time(),
    }
end

function GTax.getLeaderboardEntries()
    local entries = {}
    local entry = GTax.ensureDB()
    if type(entry.leaderboardCache) ~= "table" then entry.leaderboardCache = {} end

    local localSnapshot = GTax.getLeaderboardSnapshot()
    GTax.updateLeaderboardEntry(
        localSnapshot.player,
        localSnapshot.total,
        localSnapshot.today,
        localSnapshot.week,
        localSnapshot.lastContributionAt,
        localSnapshot.unpaidLoans
    )

    for _, record in pairs(entry.leaderboardCache) do
        table.insert(entries, record)
    end

    table.sort(entries, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        if a.week ~= b.week then return a.week > b.week end
        if a.today ~= b.today then return a.today > b.today end
        if a.lastContributionAt ~= b.lastContributionAt then
            return a.lastContributionAt > b.lastContributionAt
        end
        return string.lower(a.player) < string.lower(b.player)
    end)

    return entries
end

function GTax.sendLeaderboardRequest()
    if not (IsInGuild and IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    C_ChatInfo.SendAddonMessage("GTax", "SYNC|REQ", "GUILD")
end

function GTax.sendLeaderboardData()
    if not (IsInGuild and IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    local snapshot = GTax.getLeaderboardSnapshot()
    GTax.updateLeaderboardEntry(snapshot.player, snapshot.total, snapshot.today, snapshot.week, snapshot.lastContributionAt, snapshot.unpaidLoans)

    local payload = table.concat({
        "SYNC",
        "DATA",
        snapshot.player,
        tostring(snapshot.total),
        tostring(snapshot.today),
        tostring(snapshot.week),
        tostring(snapshot.lastContributionAt),
        tostring(snapshot.unpaidLoans),
    }, "|")
    C_ChatInfo.SendAddonMessage("GTax", payload, "GUILD")

    if GTax.UI and GTax.UI.UpdateLeaderboard then GTax.UI.UpdateLeaderboard() end
end

function GTax.handleSyncMessage(message, sender)
    if type(message) ~= "string" then return false end
    if string.sub(message, 1, 5) ~= "SYNC|" then return false end

    local parts = {}
    for token in string.gmatch(message, "([^|]+)") do
        table.insert(parts, token)
    end

    local messageType = parts[2]
    if messageType == "REQ" then
        if normalizePlayerName(sender) ~= normalizePlayerName(UnitName("player") or "") then
            GTax.sendLeaderboardData()
        end
        return true
    end

    if messageType == "DATA" then
        GTax.updateLeaderboardEntry(
            parts[3] or normalizePlayerName(sender),
            parts[4],
            parts[5],
            parts[6],
            parts[7],
            parts[8]
        )
        if GTax.UI and GTax.UI.UpdateLeaderboard then GTax.UI.UpdateLeaderboard() end
        return true
    end

    return false
end

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

function GTax.getEarningsSums(entry)
    local history = entry.earningsHistory
    if type(history) ~= "table" then return 0, 0 end

    local todayStart = GTax.getStartOfDay()
    local weekStart = GTax.getStartOfWeek()
    local today, week = 0, 0
    for _, record in ipairs(history) do
        local amount = record.amount or 0
        local timestamp = record.timestamp or 0
        if timestamp >= weekStart then week = week + amount end
        if timestamp >= todayStart then today = today + amount end
    end
    return today, week
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

function GTax.resetTracker(reason, depositAmount)
    local entry = GTax.ensureDB()
    local timeSince = GTax.formatTimeSinceDeposit(entry.lastResetAt)
    if type(entry.unpaidLoans) ~= "number" then entry.unpaidLoans = 0 end
    
    if depositAmount then
        -- Guild bank contribution: apply to unpaid loans first if any
        local contributionAmount = depositAmount
        local loanPayment = 0
        
        if entry.unpaidLoans > 0 then
            loanPayment = math.min(depositAmount, entry.unpaidLoans)
            entry.unpaidLoans = entry.unpaidLoans - loanPayment
            contributionAmount = depositAmount - loanPayment
        end
        
        -- Send broadcast message (either loan payment, contribution, or both)
        if loanPayment > 0 or contributionAmount > 0 then
            if IsInGuild and IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage then
                local name = UnitName("player") or "Unknown"
                
                if loanPayment > 0 and contributionAmount > 0 then
                    local indent = string.rep(" ", 11)
                    local lines = {
                        string.format("|cff5fd7ff[GTax]|r |cff00ff00%s|r contributed %s to the guild bank!",
                            name, GTax.formatMoney(depositAmount)),
                        indent .. "|cffffff00Loan paid off:|r " .. GTax.formatMoney(loanPayment),
                        indent .. "|cff00ff00Contribution:|r " .. GTax.formatMoney(contributionAmount),
                        indent .. "|cffffff00Remaining loan:|r " .. GTax.formatMoney(entry.unpaidLoans),
                    }
                    for i, line in ipairs(lines) do
                        C_ChatInfo.SendAddonMessage("GTax", line, "GUILD")
                    end
                elseif loanPayment > 0 then
                    -- Loan payment only
                    local indent = string.rep(" ", 11)
                    local lines = {
                        string.format("|cff5fd7ff[GTax]|r |cffffff00%s|r contributed %s to the guild bank.",
                            name, GTax.formatMoney(loanPayment)),
                        indent .. "|cffffff00Remaining loan:|r " .. GTax.formatMoney(entry.unpaidLoans),
                    }
                    for i, line in ipairs(lines) do
                        C_ChatInfo.SendAddonMessage("GTax", line, "GUILD")
                    end
                else
                    -- Pure contribution (no loan payment)
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
                    if showSuggested then
                        local pct = entry.taxPercent or 3
                        local indent = string.rep(" ", 11)
                        local lines = {
                            string.format("|cff5fd7ff[GTax]|r |cff00ff00%s|r contributed to the guild bank!", name),
                            indent .. "|cff00ff00Amount:|r " .. GTax.formatMoney(contributionAmount),
                            indent .. "|cff00ff00Suggested:|r " .. GTax.formatMoney(suggested) .. ", at " .. pct .. "%",
                            indent .. "|cff00ff00Previous contribution was|r " .. timeSince .. ".",
                        }
                        for i, line in ipairs(lines) do
                            C_ChatInfo.SendAddonMessage("GTax", line, "GUILD")
                        end
                    else
                        local indent = string.rep(" ", 11)
                        local lines = {
                            string.format("|cff5fd7ff[GTax]|r |cff00ff00%s|r contributed to the guild bank!", name),
                            indent .. "|cff00ff00Amount:|r " .. GTax.formatMoney(contributionAmount),
                            indent .. "|cff00ff00Previous contribution was|r " .. timeSince .. ".",
                        }
                        for i, line in ipairs(lines) do
                            C_ChatInfo.SendAddonMessage("GTax", line, "GUILD")
                        end
                    end
                end
            end
        end
        
        local hasContribution = (depositAmount > loanPayment)

        -- Record contribution for history (only when contribution exceeds loan payoff)
        if hasContribution then
            GTax.recordDeposit(entry, contributionAmount)
        end
        
        if hasContribution then
            entry.lastResetAt = time()
            entry.earnedSinceDeposit = 0
        end
        if GTax.sendLeaderboardData then GTax.sendLeaderboardData() end
        -- Do NOT clear earningsHistory (today/week)
    elseif reason == "manual" then
        -- Manual reset: clear all earnings, but do NOT update lastResetAt
        entry.earnedSinceDeposit = 0
        entry.earningsHistory = {} -- clear earnings for today/week
    else
        -- Other resets (e.g., today/week): just reset since last
        entry.earnedSinceDeposit = 0
    end
    if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
    GTax.printMessage("Tracker reset" .. (reason and (" (" .. reason .. ")") or "") .. ".")
end
