-- GTax_Runtime_MoneyDialogs_Hooks.lua
-- Hooks and rescans for dialog integration across Blizzard/addons

local addonName, GTax = ...
GTax = GTax or {}

GTax.MoneyDialogs = GTax.MoneyDialogs or {}
GTax.MoneyDialogsInternal = GTax.MoneyDialogsInternal or {}

local I = GTax.MoneyDialogsInternal

function I.UpdateVisibleAddonMoneyDialogs()
    if type(UISpecialFrames) == "table" then
        for _, frameName in ipairs(UISpecialFrames) do
            local dialog = _G[frameName]
            if dialog and dialog.IsShown and dialog:IsShown() then
                local moneyFrame = dialog.moneyBox or I.GetPopupMoneyFrame(dialog)
                if moneyFrame then
                    I.UpdateSuggestedContributionMoneyButton(dialog, moneyFrame)
                end
            end
        end
    end

    if I.UpdateVisibleBagnonMoneyDialogs then
        I.UpdateVisibleBagnonMoneyDialogs()
    end
end

function I.ScheduleAddonMoneyDialogRescan()
    if GTax.moneyDialogRescanTicker and GTax.moneyDialogRescanTicker.Cancel then
        GTax.moneyDialogRescanTicker:Cancel()
    end
    GTax.moneyDialogRescanTicker = nil

    if I.UpdateVisibleBaganatorMoneyDialogs then
        I.UpdateVisibleBaganatorMoneyDialogs()
    end
    I.UpdateVisibleAddonMoneyDialogs()

    if C_Timer and C_Timer.NewTicker then
        local remaining = I.RESCAN_TICK_COUNT
        GTax.moneyDialogRescanTicker = C_Timer.NewTicker(I.RESCAN_TICK_SECONDS, function()
            remaining = remaining - 1
            if I.UpdateVisibleBaganatorMoneyDialogs then
                I.UpdateVisibleBaganatorMoneyDialogs()
            end
            I.UpdateVisibleAddonMoneyDialogs()
            if remaining <= 0 and GTax.moneyDialogRescanTicker and GTax.moneyDialogRescanTicker.Cancel then
                GTax.moneyDialogRescanTicker:Cancel()
                GTax.moneyDialogRescanTicker = nil
            end
        end)
    elseif C_Timer and C_Timer.After then
        for _, delay in ipairs(I.RESCAN_AFTER_DELAYS) do
            C_Timer.After(delay, I.UpdateVisibleAddonMoneyDialogs)
        end
    end
end

local function hookSushiGuildMoneyDialogs()
    if GTax.sushiMoneyDialogHooked then return end

    local ok, Sushi = pcall(function()
        if not LibStub then return nil end
        return LibStub("Sushi-3.2", true)
    end)
    if not ok or not Sushi or not Sushi.Popup then return end

    GTax.sushiMoneyDialogHooked = true

    local function applySushiPopupMode(mode)
        if not Sushi or not Sushi.Popup then return end
        local targetId = (mode == "deposit") and GUILDBANK_DEPOSIT or GUILDBANK_WITHDRAW
        local handled = false

        if Sushi.Popup.IterateActive then
            for _, popup in Sushi.Popup:IterateActive() do
                if popup and popup.moneyInput and popup.text == targetId then
                    popup.gtaxMoneyDialogMode = mode
                    local moneyFrame = popup.MoneyInput or popup.moneyInputFrame or popup.moneyBox
                    if moneyFrame then
                        I.UpdateSuggestedContributionMoneyButton(popup, moneyFrame)
                        if mode == "withdraw" then
                            if popup.gtaxSuggestedButton then popup.gtaxSuggestedButton:Hide() end
                            if popup.gtaxSuggestedMoneyButton then popup.gtaxSuggestedMoneyButton:Hide() end
                        end
                    end
                    handled = true
                end
            end
        end

        if not handled and Sushi.Popup.GetActive then
            local popup = Sushi.Popup:GetActive(targetId)
            if not popup then return end

            popup.gtaxMoneyDialogMode = mode
            local moneyFrame = popup.MoneyInput or popup.moneyInputFrame or popup.moneyBox
            if moneyFrame then
                I.UpdateSuggestedContributionMoneyButton(popup, moneyFrame)
                if mode == "withdraw" then
                    if popup.gtaxSuggestedButton then popup.gtaxSuggestedButton:Hide() end
                    if popup.gtaxSuggestedMoneyButton then popup.gtaxSuggestedMoneyButton:Hide() end
                end
            end
        end
    end

    if Sushi.Popup.Toggle then
        hooksecurefunc(Sushi.Popup, "Toggle", function(_, info)
            if type(info) ~= "table" then return end
            if info.moneyInput == nil then return end
            if info.text == GUILDBANK_DEPOSIT then
                I.SetPendingMoneyDialogMode("deposit")
                applySushiPopupMode("deposit")
                I.ScheduleAddonMoneyDialogRescan()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function() applySushiPopupMode("deposit") end)
                    C_Timer.After(0.05, function() applySushiPopupMode("deposit") end)
                end
            elseif info.text == GUILDBANK_WITHDRAW then
                I.SetPendingMoneyDialogMode("withdraw")
                applySushiPopupMode("withdraw")
                I.ScheduleAddonMoneyDialogRescan()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function() applySushiPopupMode("withdraw") end)
                    C_Timer.After(0.05, function() applySushiPopupMode("withdraw") end)
                end
            end
        end)
    end
end

function GTax.MoneyDialogs.EnsureHooks()
    if GTax.guildBankContributionPopupHooked then return end
    GTax.guildBankContributionPopupHooked = true

    if StaticPopup_Show then
        hooksecurefunc("StaticPopup_Show", function(which)
            if which ~= "GUILDBANK_DEPOSIT" then return end
            local maxDialogs = STATICPOPUP_NUMDIALOGS or 4
            for i = 1, maxDialogs do
                local popup = _G["StaticPopup" .. i]
                if popup and popup:IsShown() and popup.which == "GUILDBANK_DEPOSIT" then
                    I.UpdateSuggestedContributionButton(popup)
                end
            end
            I.UpdateVisibleAddonMoneyDialogs()
        end)
    end

    local maxDialogs = STATICPOPUP_NUMDIALOGS or 4
    for i = 1, maxDialogs do
        local popup = _G["StaticPopup" .. i]
        if popup and popup.HookScript then
            popup:HookScript("OnShow", function(self)
                if self.which == "GUILDBANK_DEPOSIT" then
                    I.UpdateSuggestedContributionButton(self)
                elseif self.gtaxSuggestedButton then
                    self.gtaxSuggestedButton:Hide()
                end
            end)
        end
    end

    if MoneyInputFrame_ResetMoney then
        hooksecurefunc("MoneyInputFrame_ResetMoney", function(moneyFrame)
            if not moneyFrame or not moneyFrame.GetParent then return end
            local dialog = moneyFrame:GetParent()
            I.UpdateSuggestedContributionMoneyButton(dialog, moneyFrame)
            I.ScheduleAddonMoneyDialogRescan()
        end)
    end

    if I.HookBaganatorMoneyDialogMethods then
        I.HookBaganatorMoneyDialogMethods()
    end
    hookSushiGuildMoneyDialogs()
end

function GTax.MoneyDialogs.RefreshVisibleDialogs()
    I.UpdateVisibleAddonMoneyDialogs()
end
