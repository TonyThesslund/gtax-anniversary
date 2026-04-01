-- GTax_Events.lua
-- Event frame, registration, handlers, hooks

local addonName, GTax = ...
GTax = GTax or {}

GTax.pendingDeposit = false
GTax.pendingDepositTimer = nil
GTax.pendingDepositAmount = nil
GTax.pendingDepositExpiresAt = nil
GTax.pendingWithdrawal = false
GTax.pendingWithdrawalTimer = nil
GTax.pendingWithdrawalAmount = nil
GTax.pendingWithdrawalExpiresAt = nil
GTax.guildBankIsOpen = false

local function normalizePlayerName(name)
    if type(name) ~= "string" then return "" end
    local shortName = string.match(name, "^[^-]+") or name
    return string.lower(shortName)
end

local function registerAddonPrefix()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix("GTax")
    end
end

local function startPendingDepositTimer()
    if GTax.pendingDepositTimer and GTax.pendingDepositTimer.Cancel then
        GTax.pendingDepositTimer:Cancel()
    end
    GTax.pendingDepositTimer = nil

    if not C_Timer then return end
    if C_Timer.NewTimer then
        GTax.pendingDepositTimer = C_Timer.NewTimer(2, function()
            GTax.pendingDeposit = false
            GTax.pendingDepositAmount = nil
            GTax.pendingDepositExpiresAt = nil
            GTax.pendingDepositTimer = nil
        end)
        return
    end
    if C_Timer.After then
        C_Timer.After(2, function()
            GTax.pendingDeposit = false
            GTax.pendingDepositAmount = nil
            GTax.pendingDepositExpiresAt = nil
            GTax.pendingDepositTimer = nil
        end)
    end
end

local function startPendingWithdrawalTimer()
    if GTax.pendingWithdrawalTimer and GTax.pendingWithdrawalTimer.Cancel then
        GTax.pendingWithdrawalTimer:Cancel()
    end
    GTax.pendingWithdrawalTimer = nil

    if not C_Timer then return end
    if C_Timer.NewTimer then
        GTax.pendingWithdrawalTimer = C_Timer.NewTimer(10, function()
            GTax.pendingWithdrawal = false
            GTax.pendingWithdrawalAmount = nil
            GTax.pendingWithdrawalExpiresAt = nil
            GTax.pendingWithdrawalTimer = nil
        end)
        return
    end
    if C_Timer.After then
        C_Timer.After(10, function()
            GTax.pendingWithdrawal = false
            GTax.pendingWithdrawalAmount = nil
            GTax.pendingWithdrawalExpiresAt = nil
            GTax.pendingWithdrawalTimer = nil
        end)
    end
end

local function flagPendingDeposit(amount)
    GTax.pendingDeposit = true
    local parsedAmount = tonumber(amount)
    if type(parsedAmount) == "number" and parsedAmount > 0 then
        GTax.pendingDepositAmount = math.floor(parsedAmount)
    else
        GTax.pendingDepositAmount = nil
    end
    GTax.pendingDepositExpiresAt = time() + 10
    startPendingDepositTimer()
end

local function flagPendingWithdrawal(amount)
    GTax.pendingWithdrawal = true
    local parsedAmount = tonumber(amount)
    if type(parsedAmount) == "number" and parsedAmount > 0 then
        GTax.pendingWithdrawalAmount = math.floor(parsedAmount)
    else
        GTax.pendingWithdrawalAmount = nil
    end
    GTax.pendingWithdrawalExpiresAt = time() + 10
    startPendingWithdrawalTimer()
end

local function applyConfirmedWithdrawal(entry, amount)
    if type(amount) ~= "number" or amount <= 0 then return end
    if type(entry.unpaidLoans) ~= "number" then entry.unpaidLoans = 0 end

    entry.unpaidLoans = entry.unpaidLoans + amount

    if IsInGuild and IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage then
        local name = UnitName("player") or "Unknown"
        local indent = string.rep(" ", 11)
        local lines = {
            string.format("|cff5fd7ff[GTax]|r |cffffa500%s|r withdrew %s from guild bank.", name, GTax.formatMoney(amount)),
            indent .. "|cffffa500Total loans:|r " .. GTax.formatMoney(entry.unpaidLoans),
        }
        for i, line in ipairs(lines) do
            C_ChatInfo.SendAddonMessage("GTax", line, "GUILD")
        end
    end

    if GTax.sendLeaderboardData then GTax.sendLeaderboardData() end
    if GTax.UI and GTax.UI.UpdateLeaderboard then GTax.UI.UpdateLeaderboard() end
end

local function onPlayerMoneyChanged()
    local entry = GTax.ensureDB()
    local current = GetMoney() or 0
    if type(entry.lastKnownMoney) ~= "number" then
        entry.lastKnownMoney = current
        return
    end

    local delta = current - entry.lastKnownMoney

    -- Guard against stale guild-bank state causing normal earnings (e.g., vendor sales) to be ignored.
    if GTax.guildBankIsOpen and GuildBankFrame and GuildBankFrame.IsShown and not GuildBankFrame:IsShown() then
        GTax.guildBankIsOpen = false
        GTax.pendingWithdrawal = false
        GTax.pendingWithdrawalAmount = nil
        GTax.pendingWithdrawalExpiresAt = nil
        if GTax.pendingWithdrawalTimer and GTax.pendingWithdrawalTimer.Cancel then
            GTax.pendingWithdrawalTimer:Cancel()
        end
        GTax.pendingWithdrawalTimer = nil
    end

    local merchantOpen = (MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown()) and true or false
    local inGuildBankContext = GTax.guildBankIsOpen and not merchantOpen

    if delta > 0 then
        if not inGuildBankContext then
            -- Regular earned gold (vendor sale, quest reward, etc.)
            entry.earnedSinceDeposit = entry.earnedSinceDeposit + delta
            if type(entry.earningsHistory) ~= "table" then entry.earningsHistory = {} end
            table.insert(entry.earningsHistory, { amount = delta, timestamp = time() })
        end
        -- If guild bank is open, the positive delta is a withdrawal —
        -- WithdrawGuildBankMoney hook already captured the amount, so nothing to do here.
    elseif delta < 0 and inGuildBankContext then
        -- Fallback: money left wallet while guild bank open but hook may not have fired.
        -- flagPendingDeposit only if not already pending (hook sets it first).
        if not GTax.pendingDeposit then
            flagPendingDeposit(math.abs(delta))
        end
    end

    entry.lastKnownMoney = current
    if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
end

local function hookGuildBankFrame()
    if GTax.uiGuildBankHooked or not GuildBankFrame then return end

    GTax.uiGuildBankHooked = true

    -- Hook deposit and withdrawal functions here, not on login,
    -- because these are defined in Blizzard_GuildBankUI which loads lazily.
    if DepositGuildBankMoney then
        hooksecurefunc("DepositGuildBankMoney", flagPendingDeposit)
    end
    if WithdrawGuildBankMoney then
        hooksecurefunc("WithdrawGuildBankMoney", flagPendingWithdrawal)
    end

    GuildBankFrame:HookScript("OnShow", function()
        GTax.guildBankIsOpen = true
        local moneyTab = (MAX_GUILDBANK_TABS or 6) + 1
        if QueryGuildBankLog then QueryGuildBankLog(moneyTab) end
        scanGuildBankMoneyLog()
    end)
    GuildBankFrame:HookScript("OnHide", function()
        GTax.guildBankIsOpen = false
        GTax.pendingDeposit = false
        GTax.pendingDepositAmount = nil
        GTax.pendingDepositExpiresAt = nil
        if GTax.pendingDepositTimer and GTax.pendingDepositTimer.Cancel then
            GTax.pendingDepositTimer:Cancel()
        end
        GTax.pendingDepositTimer = nil
        GTax.pendingWithdrawal = false
        GTax.pendingWithdrawalAmount = nil
        GTax.pendingWithdrawalExpiresAt = nil
        if GTax.pendingWithdrawalTimer and GTax.pendingWithdrawalTimer.Cancel then
            GTax.pendingWithdrawalTimer:Cancel()
        end
        GTax.pendingWithdrawalTimer = nil
    end)
end

local function initializeAddon()
    local entry = GTax.ensureDB()
    entry.lastKnownMoney = entry.lastKnownMoney or (GetMoney() or 0)

    if GTax.UI and GTax.UI.CreateWindow then GTax.UI.CreateWindow() end
    if GTax.MinimapButton and GTax.MinimapButton.Create then GTax.MinimapButton.Create() end

    -- Publish our own snapshot on login/reload, then request others.
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            if GTax.sendLeaderboardData then GTax.sendLeaderboardData() end
            if GTax.sendLeaderboardRequest then GTax.sendLeaderboardRequest() end
        end)
    end
end

local prefixFrame = CreateFrame("Frame")
prefixFrame:RegisterEvent("ADDON_LOADED")
prefixFrame:SetScript("OnEvent", function(_, _, addon)
    if addon == "GTax" then
        registerAddonPrefix()
    end
end)

local addonMessageFrame = CreateFrame("Frame")
addonMessageFrame:RegisterEvent("CHAT_MSG_ADDON")
addonMessageFrame:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix == "GTax" and channel == "GUILD" then
        if GTax.handleSyncMessage and GTax.handleSyncMessage(message, sender) then
            return
        end
        print(message)
    end
end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("GUILDBANKFRAME_OPENED")
frame:RegisterEvent("GUILDBANKFRAME_CLOSED")
frame:RegisterEvent("GUILDBANKLOG_UPDATE")
frame:RegisterEvent("GUILDBANK_UPDATE_MONEY")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        initializeAddon()
        return
    end

    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "GTax" then
            registerAddonPrefix()
            return
        end
        if addon == "Blizzard_GuildBankUI" then
            hookGuildBankFrame()
        end
        return
    end

    if event == "PLAYER_MONEY" then
        onPlayerMoneyChanged()
        return
    end

    if event == "GUILDBANKFRAME_OPENED" then
        GTax.guildBankIsOpen = true
        local moneyTab = (MAX_GUILDBANK_TABS or 6) + 1
        if QueryGuildBankLog then QueryGuildBankLog(moneyTab) end
        scanGuildBankMoneyLog()
        return
    end

    if event == "GUILDBANKFRAME_CLOSED" then
        GTax.guildBankIsOpen = false
        return
    end

    if event == "GUILDBANK_UPDATE_MONEY" then
        -- Guild bank money changed. Confirm pending deposit or withdrawal.
        local entry = GTax.ensureDB()
        local hasPendingDeposit = GTax.pendingDeposit
            or (type(GTax.pendingDepositAmount) == "number" and GTax.pendingDepositAmount > 0
                and (type(GTax.pendingDepositExpiresAt) ~= "number" or time() <= GTax.pendingDepositExpiresAt))
        if hasPendingDeposit then
            local depositAmount = GTax.pendingDepositAmount
            GTax.pendingDeposit = false
            GTax.pendingDepositAmount = nil
            GTax.pendingDepositExpiresAt = nil
            if GTax.pendingDepositTimer and GTax.pendingDepositTimer.Cancel then
                GTax.pendingDepositTimer:Cancel()
            end
            GTax.pendingDepositTimer = nil
            GTax.resetTracker("guild bank deposit", nil, depositAmount)
            return
        end

        local hasPendingWithdrawal = GTax.pendingWithdrawal
            or (type(GTax.pendingWithdrawalAmount) == "number" and GTax.pendingWithdrawalAmount > 0
                and (type(GTax.pendingWithdrawalExpiresAt) ~= "number" or time() <= GTax.pendingWithdrawalExpiresAt))
        if hasPendingWithdrawal then
            local withdrawalAmount = GTax.pendingWithdrawalAmount
            GTax.pendingWithdrawal = false
            GTax.pendingWithdrawalAmount = nil
            GTax.pendingWithdrawalExpiresAt = nil
            if GTax.pendingWithdrawalTimer and GTax.pendingWithdrawalTimer.Cancel then
                GTax.pendingWithdrawalTimer:Cancel()
            end
            GTax.pendingWithdrawalTimer = nil
            applyConfirmedWithdrawal(entry, withdrawalAmount)
        end
        return
    end

    if event == "GUILDBANKLOG_UPDATE" then
        return -- no longer used
    end
end)
