-- GTax_Events.lua
-- Thin runtime event router and startup orchestration

local addonName, GTax = ...
GTax = GTax or {}

local INITIAL_SYNC_DELAY_SECONDS = 2
local GUILDBANK_DIALOG_REFRESH_DELAYS = { 0, 0.2 }

local function initializeAddon()
    local entry = GTax.ensureDB()
    entry.lastKnownMoney = entry.lastKnownMoney or (GetMoney() or 0)

    if GTax.UI and GTax.UI.CreateWindow then GTax.UI.CreateWindow() end
    if GTax.MinimapButton and GTax.MinimapButton.Create then GTax.MinimapButton.Create() end

    if GTax.MoneyDialogs and GTax.MoneyDialogs.EnsureHooks then
        GTax.MoneyDialogs.EnsureHooks()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(INITIAL_SYNC_DELAY_SECONDS, function()
            if GTax.sendLeaderboardData then GTax.sendLeaderboardData() end
            if GTax.sendLeaderboardRequest then GTax.sendLeaderboardRequest() end
        end)
    end
end

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
            if GTax.RegisterAddonPrefix then GTax.RegisterAddonPrefix() end
            return
        end

        if addon == "Blizzard_GuildBankUI" then
            if GTax.GuildBankTracker and GTax.GuildBankTracker.HookGuildBankFrame then
                GTax.GuildBankTracker.HookGuildBankFrame()
            end
            return
        end

        if addon == "Baganator" or addon == "BagBrother" or addon == "Bagnon" then
            if GTax.MoneyDialogs and GTax.MoneyDialogs.EnsureHooks then
                GTax.MoneyDialogs.EnsureHooks()
            end
        end
        return
    end

    if event == "PLAYER_MONEY" then
        if GTax.GuildBankTracker and GTax.GuildBankTracker.OnPlayerMoneyChanged then
            GTax.GuildBankTracker.OnPlayerMoneyChanged()
        end
        return
    end

    if event == "GUILDBANKFRAME_OPENED" then
        if GTax.GuildBankTracker and GTax.GuildBankTracker.HandleGuildBankFrameOpened then
            GTax.GuildBankTracker.HandleGuildBankFrameOpened()
        end
        if GTax.MoneyDialogs and GTax.MoneyDialogs.RefreshVisibleDialogs then
            GTax.MoneyDialogs.RefreshVisibleDialogs()
            if C_Timer and C_Timer.After then
                for _, delay in ipairs(GUILDBANK_DIALOG_REFRESH_DELAYS) do
                    C_Timer.After(delay, GTax.MoneyDialogs.RefreshVisibleDialogs)
                end
            end
        end
        return
    end

    if event == "GUILDBANKFRAME_CLOSED" then
        if GTax.GuildBankTracker and GTax.GuildBankTracker.HandleGuildBankFrameClosed then
            GTax.GuildBankTracker.HandleGuildBankFrameClosed()
        end
        return
    end

    if event == "GUILDBANK_UPDATE_MONEY" then
        if GTax.GuildBankTracker and GTax.GuildBankTracker.HandleGuildBankMoneyUpdate then
            GTax.GuildBankTracker.HandleGuildBankMoneyUpdate()
        end
        return
    end

    if event == "GUILDBANKLOG_UPDATE" then
        return -- reserved for future use
    end
end)
