-- GTax_Runtime_MoneyDialogs_Shared.lua
-- Shared state, constants, and utility helpers for money dialogs

local addonName, GTax = ...
GTax = GTax or {}

GTax.MoneyDialogs = GTax.MoneyDialogs or {}
GTax.MoneyDialogsInternal = GTax.MoneyDialogsInternal or {}

local I = GTax.MoneyDialogsInternal

I.PREFILL_BUTTON_WIDTH = 128
I.PREFILL_BUTTON_HEIGHT = 20
I.PREFILL_BUTTON_LABEL = "Prefill suggested"

I.PENDING_DIALOG_MODE_TTL_SECONDS = 3

I.BOTTOM_BUTTON_ANCHOR_OFFSET_X = 0
I.BOTTOM_BUTTON_ANCHOR_OFFSET_Y = -8
I.DEFAULT_MONEY_FRAME_ANCHOR_OFFSET_Y = -6
I.DEFAULT_CENTER_ANCHOR_OFFSET_Y = -12

I.RESCAN_TICK_SECONDS = 0.05
I.RESCAN_TICK_COUNT = 20
I.RESCAN_AFTER_DELAYS = { 0, 0.1, 0.2, 0.35, 0.5 }

GTax.pendingMoneyDialogMode = GTax.pendingMoneyDialogMode or nil
GTax.pendingMoneyDialogModeExpiresAt = GTax.pendingMoneyDialogModeExpiresAt or nil

function I.GetPrefillAmountAndLabel()
    local entry = GTax.ensureDB()
    local unpaidLoans = tonumber(entry.unpaidLoans) or 0
    if unpaidLoans > 0 then
        return math.floor(unpaidLoans), "Prefill loan"
    end

    local earned = entry.earnedSinceDeposit or 0
    local pct = entry.taxPercent or 3
    if GTax.getSuggestedDeposit then
        return GTax.getSuggestedDeposit(earned, pct), "Prefill suggested"
    end
    return 0, "Prefill suggested"
end

function I.SetPendingMoneyDialogMode(mode)
    GTax.pendingMoneyDialogMode = mode
    GTax.pendingMoneyDialogModeExpiresAt = time() + I.PENDING_DIALOG_MODE_TTL_SECONDS
end

function I.GetPendingMoneyDialogMode()
    if type(GTax.pendingMoneyDialogMode) ~= "string" then return nil end
    if type(GTax.pendingMoneyDialogModeExpiresAt) == "number" and time() > GTax.pendingMoneyDialogModeExpiresAt then
        GTax.pendingMoneyDialogMode = nil
        GTax.pendingMoneyDialogModeExpiresAt = nil
        return nil
    end
    return GTax.pendingMoneyDialogMode
end

function I.GetPopupEditBox(popup)
    if not popup then return nil end
    if popup.editBox and popup.editBox.SetText then
        return popup.editBox
    end
    local popupName = popup.GetName and popup:GetName()
    if type(popupName) == "string" then
        local namedEditBox = _G[popupName .. "EditBox"]
        if namedEditBox and namedEditBox.SetText then
            return namedEditBox
        end
    end
    return nil
end

function I.GetPopupMoneyFrame(popup)
    if not popup then return nil end
    if popup.moneyInputFrame then
        return popup.moneyInputFrame
    end
    local popupName = popup.GetName and popup:GetName()
    if type(popupName) == "string" then
        local namedMoneyFrame = _G[popupName .. "MoneyInputFrame"]
        if namedMoneyFrame then
            return namedMoneyFrame
        end
    end
    return nil
end

function I.GetMoneyInputBoxes(moneyFrame)
    if not moneyFrame then return nil, nil, nil end

    local gold = moneyFrame.gold or moneyFrame.GoldBox
    local silver = moneyFrame.silver or moneyFrame.SilverBox
    local copper = moneyFrame.copper or moneyFrame.CopperBox

    local moneyFrameName = moneyFrame.GetName and moneyFrame:GetName()
    if type(moneyFrameName) == "string" then
        gold = gold or _G[moneyFrameName .. "Gold"]
        silver = silver or _G[moneyFrameName .. "Silver"]
        copper = copper or _G[moneyFrameName .. "Copper"]
    end

    return gold, silver, copper
end

function I.SetMoneyInputFrameCopper(moneyFrame, amount)
    if type(amount) ~= "number" then return end
    local copper = math.max(0, math.floor(amount))

    if MoneyInputFrame_SetCopper then
        MoneyInputFrame_SetCopper(moneyFrame, copper)
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local coin = copper % 100

    local goldBox, silverBox, copperBox = I.GetMoneyInputBoxes(moneyFrame)
    if goldBox and goldBox.SetText then goldBox:SetText(gold > 0 and tostring(gold) or "") end
    if silverBox and silverBox.SetText then silverBox:SetText((silver > 0 or gold > 0) and tostring(silver) or "") end
    if copperBox and copperBox.SetText then copperBox:SetText(tostring(coin)) end

    if MoneyInputFrame_OnTextChanged then
        if goldBox then MoneyInputFrame_OnTextChanged(goldBox) end
        if silverBox then MoneyInputFrame_OnTextChanged(silverBox) end
        if copperBox then MoneyInputFrame_OnTextChanged(copperBox) end
    end
end

function I.IsGuildContributionMoneyDialog(dialog)
    if not dialog then return false end
    if dialog.gtaxMoneyDialogMode == "deposit" then return true end
    if dialog.gtaxMoneyDialogMode == "withdraw" then return false end
    if dialog.which == "GUILDBANK_DEPOSIT" then return true end

    if dialog.text and dialog.text.GetText and dialog.text:GetText() == GUILDBANK_DEPOSIT then
        return true
    end

    if I.IsBaganatorMoneyDialog and I.IsBaganatorMoneyDialog(dialog) then
        local mode = I.GetPendingMoneyDialogMode()
        if mode == "deposit" then return true end
        if mode == "withdraw" then return false end
    end

    local mode = I.GetPendingMoneyDialogMode()
    if mode == "deposit" and GTax.guildBankIsOpen then
        return true
    end
    if mode == "withdraw" then
        return false
    end

    return false
end
