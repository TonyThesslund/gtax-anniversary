-- GTax_Events.lua
-- Event frame, registration, handlers, hooks

local addonName, GTax = ...
GTax = GTax or {}

GTax.pendingDeposit = false
GTax.pendingDepositTimer = nil
GTax.guildBankIsOpen = false

local frame = CreateFrame("Frame")
GTax.eventFrame = frame

local function scanGuildBankMoneyLog()
    if type(GetNumGuildBankMoneyTransactions) ~= "function" then return end
    if type(GetGuildBankMoneyTransaction) ~= "function" then return end
    local entry = GTax.ensureDB()
    local num = GetNumGuildBankMoneyTransactions()
    if type(num) ~= "number" or num <= 0 then return end
    local newestDepositFingerprint = nil
    for i = 1, num do
        local txType, who, amount, whenText = GetGuildBankMoneyTransaction(i)
        if GTax.isLikelyDeposit and GTax.isLikelyDeposit(txType, who, amount) then
            local fingerprint = table.concat({ tostring(txType), tostring(who), tostring(amount), tostring(whenText) }, "|")
            if not newestDepositFingerprint then newestDepositFingerprint = fingerprint end
            break
        end
    end
    if newestDepositFingerprint and newestDepositFingerprint ~= entry.lastDepositFingerprint then
        entry.lastDepositFingerprint = newestDepositFingerprint
        entry.earnedSinceDeposit = 0
        entry.lastResetAt = time()
        GTax.printMessage("Tracker reset (guild bank deposit detected).")
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
        -- Track earnings for today/week
        if type(entry.earningsHistory) ~= "table" then entry.earningsHistory = {} end
        table.insert(entry.earningsHistory, { amount = delta, timestamp = time() })
    elseif delta < 0 then
        if GTax.pendingDeposit and GTax.guildBankIsOpen then
            local depositAmount = math.abs(delta)
            GTax.pendingDeposit = false
            if GTax.pendingDepositTimer then GTax.pendingDepositTimer = nil end
            GTax.resetTracker("guild bank deposit detected", nil, depositAmount)
        end
    end
    entry.lastKnownMoney = current
    if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        local entry = GTax.ensureDB()
        GTax.playerNameLower = string.lower(UnitName("player") or "")
        if type(entry.lastKnownMoney) ~= "number" then
            entry.lastKnownMoney = GetMoney() or 0
        end
        if DepositGuildBankMoney then
            hooksecurefunc("DepositGuildBankMoney", function()
                GTax.pendingDeposit = true
                if GTax.pendingDepositTimer and C_Timer and C_Timer.After and GTax.pendingDepositTimer.Cancel then
                    GTax.pendingDepositTimer:Cancel()
                end
                if C_Timer and C_Timer.After then
                    GTax.pendingDepositTimer = C_Timer.After(2, function()
                        GTax.pendingDeposit = false
                        GTax.pendingDepositTimer = nil
                    end)
                end
            end)
        end
        if GTax.UI and GTax.UI.CreateWindow then GTax.UI.CreateWindow() end
        if GTax.MinimapButton and GTax.MinimapButton.Create then GTax.MinimapButton.Create() end
        if GTax.UI and GTax.UI.frame then GTax.UI.frame:Show() end
        return
    end
    if event == "ADDON_LOADED" then
        local addon = select(1, ...)
        if addon == "Blizzard_GuildBankUI" and not GTax.uiGuildBankHooked then
            GTax.uiGuildBankHooked = true
            if GuildBankFrame then
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
        if GTax.UI and GTax.UI.depositPrompt then GTax.UI.depositPrompt:Hide() end
        return
    end
    if event == "GUILDBANK_UPDATE_MONEY" then
        local moneyTab = (MAX_GUILDBANK_TABS or 6) + 1
        if QueryGuildBankLog then QueryGuildBankLog(moneyTab) end
        scanGuildBankMoneyLog()
        return
    end
    if event == "GUILDBANKLOG_UPDATE" then
        scanGuildBankMoneyLog()
        return
    end
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("GUILDBANKFRAME_OPENED")
frame:RegisterEvent("GUILDBANKFRAME_CLOSED")
frame:RegisterEvent("GUILDBANKLOG_UPDATE")
frame:RegisterEvent("GUILDBANK_UPDATE_MONEY")
