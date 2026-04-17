-- GTax_Runtime_MoneyDialogs_Layout.lua
-- Button creation and layout behavior for guild-bank money dialogs

local addonName, GTax = ...
GTax = GTax or {}

GTax.MoneyDialogs = GTax.MoneyDialogs or {}
GTax.MoneyDialogsInternal = GTax.MoneyDialogsInternal or {}

local I = GTax.MoneyDialogsInternal

function I.ApplySuggestedContributionToPopup(popup)
    local suggestedAmount = I.GetPrefillAmountAndLabel()
    if type(suggestedAmount) ~= "number" then return end

    local moneyFrame = I.GetPopupMoneyFrame(popup)
    if moneyFrame then
        I.SetMoneyInputFrameCopper(moneyFrame, suggestedAmount)
        local goldBox = I.GetMoneyInputBoxes(moneyFrame)
        if goldBox and goldBox.SetFocus then goldBox:SetFocus() end
        return
    end

    local editBox = I.GetPopupEditBox(popup)
    if editBox then
        editBox:SetText(tostring(suggestedAmount))
        if editBox.SetFocus then editBox:SetFocus() end
        if editBox.HighlightText then editBox:HighlightText() end
    end
end

function I.EnsureSuggestedContributionButton(popup)
    if popup.gtaxSuggestedButton then return popup.gtaxSuggestedButton end

    local button = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    button:SetSize(I.PREFILL_BUTTON_WIDTH, I.PREFILL_BUTTON_HEIGHT)
    button:SetText(I.PREFILL_BUTTON_LABEL)
    button:SetScript("OnClick", function()
        I.ApplySuggestedContributionToPopup(popup)
    end)

    local editBox = I.GetPopupEditBox(popup)
    if editBox then
        button:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -6)
    else
        button:SetPoint("TOP", popup, "BOTTOM", 0, -4)
    end

    popup.gtaxSuggestedButton = button
    return button
end

function I.UpdateSuggestedContributionButton(popup)
    local button = I.EnsureSuggestedContributionButton(popup)
    local _, buttonLabel = I.GetPrefillAmountAndLabel()
    button:SetText(buttonLabel)
    local hasInput = (I.GetPopupMoneyFrame(popup) ~= nil) or (I.GetPopupEditBox(popup) ~= nil)
    button:SetShown(hasInput)
end

function I.EnsureSuggestedContributionMoneyButton(dialog, moneyFrame)
    if dialog.gtaxSuggestedMoneyButton then return dialog.gtaxSuggestedMoneyButton end

    local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    button:SetSize(I.PREFILL_BUTTON_WIDTH, I.PREFILL_BUTTON_HEIGHT)
    button:SetText(I.PREFILL_BUTTON_LABEL)
    button:SetScript("OnClick", function()
        local suggestedAmount = I.GetPrefillAmountAndLabel()
        if type(suggestedAmount) ~= "number" then return end
        I.SetMoneyInputFrameCopper(moneyFrame, suggestedAmount)
        local goldBox = I.GetMoneyInputBoxes(moneyFrame)
        if goldBox and goldBox.SetFocus then goldBox:SetFocus() end
    end)

    button:SetFrameStrata(dialog:GetFrameStrata())
    button:SetFrameLevel((dialog.GetFrameLevel and dialog:GetFrameLevel() or 1) + 5)

    dialog.gtaxSuggestedMoneyButton = button
    return button
end

function I.UpdateSuggestedContributionMoneyButton(dialog, moneyFrame)
    if not (dialog and moneyFrame) then return end
    if dialog.gtaxSuggestedButton then
        I.UpdateSuggestedContributionButton(dialog)
        if dialog.gtaxSuggestedMoneyButton then
            dialog.gtaxSuggestedMoneyButton:Hide()
        end
        if I.ResetBaganatorDialogLayout then I.ResetBaganatorDialogLayout(dialog) end
        return
    end
    if not I.IsGuildContributionMoneyDialog(dialog) then
        if dialog.gtaxSuggestedMoneyButton then
            dialog.gtaxSuggestedMoneyButton:Hide()
        end
        if I.ResetBaganatorDialogLayout then I.ResetBaganatorDialogLayout(dialog) end
        return
    end

    local button = I.EnsureSuggestedContributionMoneyButton(dialog, moneyFrame)
    local _, buttonLabel = I.GetPrefillAmountAndLabel()
    button:SetText(buttonLabel)
    button:ClearAllPoints()
    if I.ApplyBaganatorDepositLayout and I.ApplyBaganatorDepositLayout(dialog, button) then
    elseif dialog.acceptButton and dialog.cancelButton then
        if I.ResetBaganatorDialogLayout then I.ResetBaganatorDialogLayout(dialog) end
        button:SetPoint("TOP", dialog, "BOTTOM", I.BOTTOM_BUTTON_ANCHOR_OFFSET_X, I.BOTTOM_BUTTON_ANCHOR_OFFSET_Y)
    elseif dialog.MoneyInput then
        if I.ResetBaganatorDialogLayout then I.ResetBaganatorDialogLayout(dialog) end
        button:SetPoint("TOP", dialog, "BOTTOM", I.BOTTOM_BUTTON_ANCHOR_OFFSET_X, I.BOTTOM_BUTTON_ANCHOR_OFFSET_Y)
    elseif moneyFrame then
        if I.ResetBaganatorDialogLayout then I.ResetBaganatorDialogLayout(dialog) end
        button:SetPoint("TOP", moneyFrame, "BOTTOM", 0, I.DEFAULT_MONEY_FRAME_ANCHOR_OFFSET_Y)
    else
        if I.ResetBaganatorDialogLayout then I.ResetBaganatorDialogLayout(dialog) end
        button:SetPoint("TOP", dialog, "CENTER", 0, I.DEFAULT_CENTER_ANCHOR_OFFSET_Y)
    end
    button:SetShown(true)
end
