-- GTax_Events.lua
-- Event frame, registration, handlers, hooks

local addonName, GTax = ...
GTax = GTax or {}

GTax.pendingDeposit = false
GTax.pendingDepositTimer = nil
GTax.pendingDepositAmount = nil
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
            GTax.pendingDepositTimer = nil
        end)
        return
    end
    if C_Timer.After then
        C_Timer.After(2, function()
            GTax.pendingDeposit = false
            GTax.pendingDepositAmount = nil
            GTax.pendingDepositTimer = nil
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
    startPendingDepositTimer()
end

local function isLikelyDeposit(txType, who, amount)
    if txType ~= "deposit" or type(amount) ~= "number" or amount <= 0 then
        return false
    end
    return normalizePlayerName(who) == normalizePlayerName(UnitName("player"))
end

local function scanGuildBankMoneyLog()
    if type(GetNumGuildBankMoneyTransactions) ~= "function" then return end
    if type(GetGuildBankMoneyTransaction) ~= "function" then return end

    local entry = GTax.ensureDB()
    local num = GetNumGuildBankMoneyTransactions()
    if type(num) ~= "number" or num <= 0 then return end

    local newestDepositFingerprint
    local newestDepositAmount
    for i = 1, num do
        local txType, who, amount, years, months, days, hours = GetGuildBankMoneyTransaction(i)
        if isLikelyDeposit(txType, who, amount) then
            newestDepositFingerprint = table.concat({
                tostring(txType),
                tostring(who),
                tostring(amount),
                tostring(years),
                tostring(months),
                tostring(days),
                tostring(hours),
            }, "|")
            newestDepositAmount = amount
            break
        end
    end

    if newestDepositFingerprint and newestDepositFingerprint ~= entry.lastDepositFingerprint then
        if GTax.pendingDeposit then
            GTax.pendingDeposit = false
            GTax.pendingDepositAmount = nil
            if GTax.pendingDepositTimer and GTax.pendingDepositTimer.Cancel then
                GTax.pendingDepositTimer:Cancel()
            end
            GTax.pendingDepositTimer = nil
            GTax.resetTracker("guild bank log detected", newestDepositFingerprint, newestDepositAmount)
            return
        end

        -- No pending local deposit action: treat as historical baseline only.
        entry.lastDepositFingerprint = newestDepositFingerprint
    end

    if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
end

local function onPlayerMoneyChanged()
    local entry = GTax.ensureDB()
    local current = GetMoney() or 0
    if type(entry.lastKnownMoney) ~= "number" then
        entry.lastKnownMoney = current
        return
    end

    local delta = current - entry.lastKnownMoney
    if delta > 0 then
        entry.earnedSinceDeposit = entry.earnedSinceDeposit + delta
        if type(entry.earningsHistory) ~= "table" then entry.earningsHistory = {} end
        table.insert(entry.earningsHistory, { amount = delta, timestamp = time() })
    elseif delta < 0 and GTax.pendingDeposit and GTax.guildBankIsOpen then
        GTax.pendingDeposit = false
        local depositAmount = GTax.pendingDepositAmount or math.abs(delta)
        GTax.pendingDepositAmount = nil
        if GTax.pendingDepositTimer and GTax.pendingDepositTimer.Cancel then
            GTax.pendingDepositTimer:Cancel()
        end
        GTax.pendingDepositTimer = nil
        GTax.resetTracker("guild bank deposit detected", nil, depositAmount)
    end

    entry.lastKnownMoney = current
    if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
end

local function hookGuildBankFrame()
    if GTax.uiGuildBankHooked or not GuildBankFrame then return end

    GTax.uiGuildBankHooked = true
    GuildBankFrame:HookScript("OnShow", function()
        GTax.guildBankIsOpen = true
        local moneyTab = (MAX_GUILDBANK_TABS or 6) + 1
        if QueryGuildBankLog then QueryGuildBankLog(moneyTab) end
        scanGuildBankMoneyLog()
    end)
    GuildBankFrame:HookScript("OnHide", function()
        GTax.guildBankIsOpen = false
    end)
end

local function initializeAddon()
    local entry = GTax.ensureDB()
    entry.lastKnownMoney = entry.lastKnownMoney or (GetMoney() or 0)

    if not GTax.depositHooked and DepositGuildBankMoney then
        GTax.depositHooked = true
        hooksecurefunc("DepositGuildBankMoney", flagPendingDeposit)
    end

    if GTax.UI and GTax.UI.CreateWindow then GTax.UI.CreateWindow() end
    if GTax.MinimapButton and GTax.MinimapButton.Create then GTax.MinimapButton.Create() end

    -- Ask guild clients to publish their latest leaderboard data after login/reload.
    if C_Timer and C_Timer.After and GTax.sendLeaderboardRequest then
        C_Timer.After(2, function()
            GTax.sendLeaderboardRequest()
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

    if event == "GUILDBANK_UPDATE_MONEY" or event == "GUILDBANKLOG_UPDATE" then
        local moneyTab = (MAX_GUILDBANK_TABS or 6) + 1
        if QueryGuildBankLog then QueryGuildBankLog(moneyTab) end
        scanGuildBankMoneyLog()
    end
end)
