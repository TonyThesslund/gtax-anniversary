-- GTax_Runtime_GuildBankTracker.lua
-- Guild-bank pending state, money tracking, and confirmation handling

local addonName, GTax = ...
GTax = GTax or {}

GTax.GuildBankTracker = GTax.GuildBankTracker or {}

local PENDING_DEPOSIT_RESET_SECONDS = 2
local PENDING_WITHDRAWAL_RESET_SECONDS = 10
local PENDING_STATE_TTL_SECONDS = 10

GTax.pendingDeposit = GTax.pendingDeposit or false
GTax.pendingDepositTimer = GTax.pendingDepositTimer or nil
GTax.pendingDepositAmount = GTax.pendingDepositAmount or nil
GTax.pendingDepositExpiresAt = GTax.pendingDepositExpiresAt or nil
GTax.pendingWithdrawal = GTax.pendingWithdrawal or false
GTax.pendingWithdrawalTimer = GTax.pendingWithdrawalTimer or nil
GTax.pendingWithdrawalAmount = GTax.pendingWithdrawalAmount or nil
GTax.pendingWithdrawalExpiresAt = GTax.pendingWithdrawalExpiresAt or nil
GTax.guildBankIsOpen = GTax.guildBankIsOpen or false

local function clearPendingDepositState()
    GTax.pendingDeposit = false
    GTax.pendingDepositAmount = nil
    GTax.pendingDepositExpiresAt = nil
    if GTax.pendingDepositTimer and GTax.pendingDepositTimer.Cancel then
        GTax.pendingDepositTimer:Cancel()
    end
    GTax.pendingDepositTimer = nil
end

local function clearPendingWithdrawalState()
    GTax.pendingWithdrawal = false
    GTax.pendingWithdrawalAmount = nil
    GTax.pendingWithdrawalExpiresAt = nil
    if GTax.pendingWithdrawalTimer and GTax.pendingWithdrawalTimer.Cancel then
        GTax.pendingWithdrawalTimer:Cancel()
    end
    GTax.pendingWithdrawalTimer = nil
end

local function startPendingDepositTimer()
    if GTax.pendingDepositTimer and GTax.pendingDepositTimer.Cancel then
        GTax.pendingDepositTimer:Cancel()
    end
    GTax.pendingDepositTimer = nil

    if not C_Timer then return end
    if C_Timer.NewTimer then
        GTax.pendingDepositTimer = C_Timer.NewTimer(PENDING_DEPOSIT_RESET_SECONDS, function()
            clearPendingDepositState()
        end)
        return
    end
    if C_Timer.After then
        C_Timer.After(PENDING_DEPOSIT_RESET_SECONDS, function()
            clearPendingDepositState()
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
        GTax.pendingWithdrawalTimer = C_Timer.NewTimer(PENDING_WITHDRAWAL_RESET_SECONDS, function()
            clearPendingWithdrawalState()
        end)
        return
    end
    if C_Timer.After then
        C_Timer.After(PENDING_WITHDRAWAL_RESET_SECONDS, function()
            clearPendingWithdrawalState()
        end)
    end
end

function GTax.GuildBankTracker.FlagPendingDeposit(amount)
    GTax.pendingDeposit = true
    local parsedAmount = tonumber(amount)
    if type(parsedAmount) == "number" and parsedAmount > 0 then
        GTax.pendingDepositAmount = math.floor(parsedAmount)
    else
        GTax.pendingDepositAmount = nil
    end
    GTax.pendingDepositExpiresAt = time() + PENDING_STATE_TTL_SECONDS
    startPendingDepositTimer()
end

function GTax.GuildBankTracker.FlagPendingWithdrawal(amount)
    GTax.pendingWithdrawal = true
    local parsedAmount = tonumber(amount)
    if type(parsedAmount) == "number" and parsedAmount > 0 then
        GTax.pendingWithdrawalAmount = math.floor(parsedAmount)
    else
        GTax.pendingWithdrawalAmount = nil
    end
    GTax.pendingWithdrawalExpiresAt = time() + PENDING_STATE_TTL_SECONDS
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
        for _, line in ipairs(lines) do
            C_ChatInfo.SendAddonMessage("GTax", line, "GUILD")
        end
    end

    if GTax.sendLeaderboardData then GTax.sendLeaderboardData() end
    if GTax.UI and GTax.UI.UpdateLeaderboard then GTax.UI.UpdateLeaderboard() end
end

function GTax.GuildBankTracker.OnPlayerMoneyChanged()
    local entry = GTax.ensureDB()
    local current = GetMoney() or 0
    if type(entry.lastKnownMoney) ~= "number" then
        entry.lastKnownMoney = current
        return
    end

    local delta = current - entry.lastKnownMoney

    if GTax.guildBankIsOpen and GuildBankFrame and GuildBankFrame.IsShown and not GuildBankFrame:IsShown() then
        GTax.guildBankIsOpen = false
        clearPendingWithdrawalState()
    end

    local merchantOpen = (MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown()) and true or false
    local inGuildBankContext = GTax.guildBankIsOpen and not merchantOpen

    if delta > 0 then
        if not inGuildBankContext then
            entry.earnedSinceDeposit = entry.earnedSinceDeposit + delta
            if type(entry.earningsHistory) ~= "table" then entry.earningsHistory = {} end
            table.insert(entry.earningsHistory, { amount = delta, timestamp = time() })
        end
    elseif delta < 0 and inGuildBankContext then
        if not GTax.pendingDeposit then
            GTax.GuildBankTracker.FlagPendingDeposit(math.abs(delta))
        end
    end

    entry.lastKnownMoney = current
    if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
end

function GTax.GuildBankTracker.HandleGuildBankFrameOpened()
    GTax.guildBankIsOpen = true
    local moneyTab = (MAX_GUILDBANK_TABS or 6) + 1
    if QueryGuildBankLog then QueryGuildBankLog(moneyTab) end
end

function GTax.GuildBankTracker.HandleGuildBankFrameClosed()
    GTax.guildBankIsOpen = false
end

function GTax.GuildBankTracker.HardResetGuildBankPendingState()
    clearPendingDepositState()
    clearPendingWithdrawalState()
end

function GTax.GuildBankTracker.HookGuildBankFrame()
    if GTax.uiGuildBankHooked or not GuildBankFrame then return end

    GTax.uiGuildBankHooked = true

    if DepositGuildBankMoney then
        hooksecurefunc("DepositGuildBankMoney", GTax.GuildBankTracker.FlagPendingDeposit)
    end
    if WithdrawGuildBankMoney then
        hooksecurefunc("WithdrawGuildBankMoney", GTax.GuildBankTracker.FlagPendingWithdrawal)
    end

    if GTax.MoneyDialogs and GTax.MoneyDialogs.EnsureHooks then
        GTax.MoneyDialogs.EnsureHooks()
    end

    GuildBankFrame:HookScript("OnShow", function()
        GTax.GuildBankTracker.HandleGuildBankFrameOpened()
    end)
    GuildBankFrame:HookScript("OnHide", function()
        GTax.guildBankIsOpen = false
        GTax.GuildBankTracker.HardResetGuildBankPendingState()
    end)
end

function GTax.GuildBankTracker.HandleGuildBankMoneyUpdate()
    local entry = GTax.ensureDB()

    local hasPendingDeposit = GTax.pendingDeposit
        or (type(GTax.pendingDepositAmount) == "number" and GTax.pendingDepositAmount > 0
            and (type(GTax.pendingDepositExpiresAt) ~= "number" or time() <= GTax.pendingDepositExpiresAt))
    if hasPendingDeposit then
        local contributionAmount = GTax.pendingDepositAmount
        clearPendingDepositState()
        GTax.resetTracker("guild bank contribution", contributionAmount)
        return
    end

    local hasPendingWithdrawal = GTax.pendingWithdrawal
        or (type(GTax.pendingWithdrawalAmount) == "number" and GTax.pendingWithdrawalAmount > 0
            and (type(GTax.pendingWithdrawalExpiresAt) ~= "number" or time() <= GTax.pendingWithdrawalExpiresAt))
    if hasPendingWithdrawal then
        local withdrawalAmount = GTax.pendingWithdrawalAmount
        clearPendingWithdrawalState()
        applyConfirmedWithdrawal(entry, withdrawalAmount)
    end
end
