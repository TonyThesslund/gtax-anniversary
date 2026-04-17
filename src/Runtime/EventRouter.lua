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
GTax.pendingMoneyDialogMode = nil
GTax.pendingMoneyDialogModeExpiresAt = nil

local function registerAddonPrefix()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix("GTax")
    end
end

local function getPrefillAmountAndLabel()
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

local getMoneyInputBoxes
local setMoneyInputFrameCopper

local function setPendingMoneyDialogMode(mode)
    GTax.pendingMoneyDialogMode = mode
    GTax.pendingMoneyDialogModeExpiresAt = time() + 3
end

local function getPendingMoneyDialogMode()
    if type(GTax.pendingMoneyDialogMode) ~= "string" then return nil end
    if type(GTax.pendingMoneyDialogModeExpiresAt) == "number" and time() > GTax.pendingMoneyDialogModeExpiresAt then
        GTax.pendingMoneyDialogMode = nil
        GTax.pendingMoneyDialogModeExpiresAt = nil
        return nil
    end
    return GTax.pendingMoneyDialogMode
end

local function getPopupEditBox(popup)
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

local function getPopupMoneyFrame(popup)
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

local function applySuggestedContributionToPopup(popup)
    local suggestedAmount = getPrefillAmountAndLabel()
    if type(suggestedAmount) ~= "number" then return end

    local moneyFrame = getPopupMoneyFrame(popup)
    if moneyFrame then
        setMoneyInputFrameCopper(moneyFrame, suggestedAmount)
        local goldBox = getMoneyInputBoxes(moneyFrame)
        if goldBox and goldBox.SetFocus then goldBox:SetFocus() end
        return
    end

    local editBox = getPopupEditBox(popup)
    if editBox then
        editBox:SetText(tostring(suggestedAmount))
        if editBox.SetFocus then editBox:SetFocus() end
        if editBox.HighlightText then editBox:HighlightText() end
    end
end

local function ensureSuggestedContributionButton(popup)
    if popup.gtaxSuggestedButton then return popup.gtaxSuggestedButton end

    local button = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    button:SetSize(128, 20)
    button:SetText("Prefill suggested")
    button:SetScript("OnClick", function()
        applySuggestedContributionToPopup(popup)
    end)

    local editBox = getPopupEditBox(popup)
    if editBox then
        button:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -6)
    else
        button:SetPoint("TOP", popup, "BOTTOM", 0, -4)
    end

    popup.gtaxSuggestedButton = button
    return button
end

local function updateSuggestedContributionButton(popup)
    local button = ensureSuggestedContributionButton(popup)
    local _, buttonLabel = getPrefillAmountAndLabel()
    button:SetText(buttonLabel)
    local hasInput = (getPopupMoneyFrame(popup) ~= nil) or (getPopupEditBox(popup) ~= nil)
    local showButton = hasInput
    button:SetShown(showButton)
end

getMoneyInputBoxes = function(moneyFrame)
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

setMoneyInputFrameCopper = function(moneyFrame, amount)
    if type(amount) ~= "number" then return end
    local copper = math.max(0, math.floor(amount))

    if MoneyInputFrame_SetCopper then
        MoneyInputFrame_SetCopper(moneyFrame, copper)
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local coin = copper % 100

    local goldBox, silverBox, copperBox = getMoneyInputBoxes(moneyFrame)
    if goldBox and goldBox.SetText then goldBox:SetText(gold > 0 and tostring(gold) or "") end
    if silverBox and silverBox.SetText then silverBox:SetText((silver > 0 or gold > 0) and tostring(silver) or "") end
    if copperBox and copperBox.SetText then copperBox:SetText(tostring(coin)) end

    -- Some templates only refresh totals when text-changed handlers run.
    if MoneyInputFrame_OnTextChanged then
        if goldBox then MoneyInputFrame_OnTextChanged(goldBox) end
        if silverBox then MoneyInputFrame_OnTextChanged(silverBox) end
        if copperBox then MoneyInputFrame_OnTextChanged(copperBox) end
    end
end

local function isGuildContributionMoneyDialog(dialog)
    if not dialog then return false end
    if dialog.gtaxMoneyDialogMode == "deposit" then return true end
    if dialog.gtaxMoneyDialogMode == "withdraw" then return false end
    if dialog.which == "GUILDBANK_DEPOSIT" then return true end

    if dialog.text and dialog.text.GetText and dialog.text:GetText() == GUILDBANK_DEPOSIT then
        return true
    end

    local dialogName = dialog.GetName and dialog:GetName() or ""
    if string.find(dialogName, "BaganatorDialog", 1, true) then
        local mode = getPendingMoneyDialogMode()
        if mode == "deposit" then return true end
        if mode == "withdraw" then return false end
    end

    local mode = getPendingMoneyDialogMode()
    if mode == "deposit" and GTax.guildBankIsOpen then
        return true
    end
    if mode == "withdraw" then
        return false
    end

    return false
end

local function ensureSuggestedContributionMoneyButton(dialog, moneyFrame)
    if dialog.gtaxSuggestedMoneyButton then return dialog.gtaxSuggestedMoneyButton end

    local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    button:SetSize(128, 20)
    button:SetText("Prefill suggested")
    button:SetScript("OnClick", function()
        local suggestedAmount = getPrefillAmountAndLabel()
        if type(suggestedAmount) ~= "number" then return end
        setMoneyInputFrameCopper(moneyFrame, suggestedAmount)
        local goldBox = getMoneyInputBoxes(moneyFrame)
        if goldBox and goldBox.SetFocus then goldBox:SetFocus() end
    end)

    button:SetFrameStrata(dialog:GetFrameStrata())
    button:SetFrameLevel((dialog.GetFrameLevel and dialog:GetFrameLevel() or 1) + 5)

    dialog.gtaxSuggestedMoneyButton = button
    return button
end

local function isBaganatorMoneyDialog(dialog)
    if not dialog then return false end
    local dialogName = dialog.GetName and dialog:GetName() or ""
    if type(dialogName) == "string" and string.find(dialogName, "BaganatorDialog", 1, true) ~= nil then
        return true
    end

    -- Fallback: Baganator/Sushi-style guild dialogs often expose these fields without stable global names.
    if dialog.moneyBox and dialog.acceptButton and dialog.cancelButton then
        local txt = dialog.text and dialog.text.GetText and dialog.text:GetText() or nil
        if txt == GUILDBANK_DEPOSIT or txt == GUILDBANK_WITHDRAW then
            return true
        end
    end

    return false
end

local function setBaganatorDialogExpandedForButton(dialog, shouldExpand)
    if not (dialog and dialog.GetHeight and dialog.SetHeight) then return end
    if not isBaganatorMoneyDialog(dialog) then return end

    -- Base expansion for an extra in-dialog button row.
    local extraHeight = 40
    if shouldExpand then
        if type(dialog.gtaxOriginalHeight) ~= "number" then
            dialog.gtaxOriginalHeight = dialog:GetHeight()
        end
        local targetHeight = dialog.gtaxOriginalHeight + extraHeight
        local currentHeight = dialog:GetHeight()
        -- During dialog rescans, avoid snapping back down; only grow when needed.
        if type(currentHeight) ~= "number" or currentHeight < targetHeight then
            dialog:SetHeight(targetHeight)
        end
        return
    end

    if type(dialog.gtaxOriginalHeight) == "number" then
        dialog:SetHeight(dialog.gtaxOriginalHeight)
    end
end

local function offsetFramePoint(frame, stateKey, offsetX, offsetY)
    if not (frame and frame.GetPoint and frame.SetPoint and frame.ClearAllPoints) then return end

    if type(frame[stateKey]) ~= "table" then
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
        if not point then return end
        frame[stateKey] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOfs = xOfs or 0,
            yOfs = yOfs or 0,
        }
    end

    local saved = frame[stateKey]
    frame:ClearAllPoints()
    frame:SetPoint(saved.point, saved.relativeTo, saved.relativePoint, (saved.xOfs or 0) + (offsetX or 0), (saved.yOfs or 0) + (offsetY or 0))
end

local function restoreFramePoint(frame, stateKey)
    if not (frame and frame.GetPoint and frame.SetPoint and frame.ClearAllPoints) then return end
    local saved = frame[stateKey]
    if type(saved) ~= "table" then return end

    frame:ClearAllPoints()
    frame:SetPoint(saved.point, saved.relativeTo, saved.relativePoint, saved.xOfs or 0, saved.yOfs or 0)
end

local function setBaganatorRowsOffset(dialog, shouldOffset)
    if not isBaganatorMoneyDialog(dialog) then return end

    local rowLift = 16
    if shouldOffset then
        offsetFramePoint(dialog.moneyBox, "gtaxSavedPoint", 0, rowLift)
        offsetFramePoint(dialog.acceptButton, "gtaxSavedPoint", 0, rowLift)
        offsetFramePoint(dialog.cancelButton, "gtaxSavedPoint", 0, rowLift)
        return
    end

    restoreFramePoint(dialog.moneyBox, "gtaxSavedPoint")
    restoreFramePoint(dialog.acceptButton, "gtaxSavedPoint")
    restoreFramePoint(dialog.cancelButton, "gtaxSavedPoint")
end

local function ensureBaganatorButtonBottomMargin(dialog, button, minPadding)
    if not (dialog and button and dialog.GetBottom and button.GetBottom and dialog.GetHeight and dialog.SetHeight) then return end
    if not isBaganatorMoneyDialog(dialog) then return end

    local dialogBottom = dialog:GetBottom()
    local buttonBottom = button:GetBottom()
    if type(dialogBottom) ~= "number" or type(buttonBottom) ~= "number" then return end

    local targetBottom = dialogBottom + (minPadding or 14)
    if buttonBottom < targetBottom then
        dialog:SetHeight(dialog:GetHeight() + (targetBottom - buttonBottom))
    end
end

local function updateSuggestedContributionMoneyButton(dialog, moneyFrame)
    if not (dialog and moneyFrame) then return end
    if dialog.gtaxSuggestedButton then
        updateSuggestedContributionButton(dialog)
        if dialog.gtaxSuggestedMoneyButton then
            dialog.gtaxSuggestedMoneyButton:Hide()
        end
        setBaganatorDialogExpandedForButton(dialog, false)
        setBaganatorRowsOffset(dialog, false)
        return
    end
    if not isGuildContributionMoneyDialog(dialog) then
        if dialog.gtaxSuggestedMoneyButton then
            dialog.gtaxSuggestedMoneyButton:Hide()
        end
        setBaganatorDialogExpandedForButton(dialog, false)
        setBaganatorRowsOffset(dialog, false)
        return
    end

    local button = ensureSuggestedContributionMoneyButton(dialog, moneyFrame)
    local _, buttonLabel = getPrefillAmountAndLabel()
    button:SetText(buttonLabel)
    button:ClearAllPoints()
    if dialog.acceptButton and dialog.cancelButton and isBaganatorMoneyDialog(dialog) then
        -- Keep the button inside Baganator with clear spacing above and below.
        setBaganatorDialogExpandedForButton(dialog, true)
        setBaganatorRowsOffset(dialog, true)
        local centerOffset = 0
        if dialog.acceptButton.GetCenter and dialog.cancelButton.GetCenter then
            local acceptX = dialog.acceptButton:GetCenter()
            local cancelX = dialog.cancelButton:GetCenter()
            if type(acceptX) == "number" and type(cancelX) == "number" then
                centerOffset = math.floor(((cancelX - acceptX) / 2) + 0.5)
            end
        end
        button:SetPoint("TOP", dialog.acceptButton, "BOTTOM", centerOffset, -8)
        ensureBaganatorButtonBottomMargin(dialog, button, 14)
    elseif dialog.acceptButton and dialog.cancelButton then
        setBaganatorRowsOffset(dialog, false)
        button:SetPoint("TOP", dialog, "BOTTOM", 0, -8)
    elseif dialog.MoneyInput then
        setBaganatorDialogExpandedForButton(dialog, false)
        setBaganatorRowsOffset(dialog, false)
        -- Sushi/Bagnon popup layout: place below the popup to avoid overlapping action buttons.
        button:SetPoint("TOP", dialog, "BOTTOM", 0, -8)
    elseif moneyFrame then
        setBaganatorDialogExpandedForButton(dialog, false)
        setBaganatorRowsOffset(dialog, false)
        button:SetPoint("TOP", moneyFrame, "BOTTOM", 0, -6)
    else
        setBaganatorDialogExpandedForButton(dialog, false)
        setBaganatorRowsOffset(dialog, false)
        button:SetPoint("TOP", dialog, "CENTER", 0, -12)
    end
    button:SetShown(true)
end

local function updateVisibleBaganatorMoneyDialogs()
    for i = 1, 20 do
        local dialog = _G["BaganatorDialog" .. i]
        if dialog and dialog:IsShown() and dialog.moneyBox then
            updateSuggestedContributionMoneyButton(dialog, dialog.moneyBox)
        end
    end
end

local function updateVisibleAddonMoneyDialogs()
    if type(UISpecialFrames) == "table" then
        for _, frameName in ipairs(UISpecialFrames) do
            local dialog = _G[frameName]
            if dialog and dialog.IsShown and dialog:IsShown() then
                local moneyFrame = dialog.moneyBox or getPopupMoneyFrame(dialog)
                if moneyFrame then
                    updateSuggestedContributionMoneyButton(dialog, moneyFrame)
                end
            end
        end
    end

    -- Some addon dialogs are not in UISpecialFrames.
    for i = 1, 20 do
        local bagnonDialog = _G["BagnonDialog" .. i]
        if bagnonDialog and bagnonDialog:IsShown() then
            local moneyFrame = bagnonDialog.moneyBox or getPopupMoneyFrame(bagnonDialog)
            if moneyFrame then
                updateSuggestedContributionMoneyButton(bagnonDialog, moneyFrame)
            end
        end
    end
end

local function scheduleAddonMoneyDialogRescan()
    if GTax.moneyDialogRescanTicker and GTax.moneyDialogRescanTicker.Cancel then
        GTax.moneyDialogRescanTicker:Cancel()
    end
    GTax.moneyDialogRescanTicker = nil

    updateVisibleBaganatorMoneyDialogs()
    updateVisibleAddonMoneyDialogs()

    if C_Timer and C_Timer.NewTicker then
        local remaining = 20 -- ~1 second at 0.05s interval
        GTax.moneyDialogRescanTicker = C_Timer.NewTicker(0.05, function()
            remaining = remaining - 1
            updateVisibleBaganatorMoneyDialogs()
            updateVisibleAddonMoneyDialogs()
            if remaining <= 0 and GTax.moneyDialogRescanTicker and GTax.moneyDialogRescanTicker.Cancel then
                GTax.moneyDialogRescanTicker:Cancel()
                GTax.moneyDialogRescanTicker = nil
            end
        end)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0, updateVisibleAddonMoneyDialogs)
        C_Timer.After(0.1, updateVisibleAddonMoneyDialogs)
        C_Timer.After(0.2, updateVisibleAddonMoneyDialogs)
        C_Timer.After(0.35, updateVisibleAddonMoneyDialogs)
        C_Timer.After(0.5, updateVisibleAddonMoneyDialogs)
    end
end

local function hookBaganatorMoneyDialogMethods()
    if GTax.baganatorMoneyDialogHooked then return end
    if not BaganatorSingleViewGuildViewMixin then return end

    GTax.baganatorMoneyDialogHooked = true

    if BaganatorSingleViewGuildViewMixin.DepositMoney then
        hooksecurefunc(BaganatorSingleViewGuildViewMixin, "DepositMoney", function()
            setPendingMoneyDialogMode("deposit")
            scheduleAddonMoneyDialogRescan()
        end)
    end

    if BaganatorSingleViewGuildViewMixin.WithdrawMoney then
        hooksecurefunc(BaganatorSingleViewGuildViewMixin, "WithdrawMoney", function()
            setPendingMoneyDialogMode("withdraw")
            scheduleAddonMoneyDialogRescan()
        end)
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
                        updateSuggestedContributionMoneyButton(popup, moneyFrame)
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
                updateSuggestedContributionMoneyButton(popup, moneyFrame)
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
                setPendingMoneyDialogMode("deposit")
                applySushiPopupMode("deposit")
                scheduleAddonMoneyDialogRescan()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function() applySushiPopupMode("deposit") end)
                    C_Timer.After(0.05, function() applySushiPopupMode("deposit") end)
                end
            elseif info.text == GUILDBANK_WITHDRAW then
                setPendingMoneyDialogMode("withdraw")
                applySushiPopupMode("withdraw")
                scheduleAddonMoneyDialogRescan()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function() applySushiPopupMode("withdraw") end)
                    C_Timer.After(0.05, function() applySushiPopupMode("withdraw") end)
                end
            end
        end)
    end
end

local function hookGuildBankContributionPopup()
    if GTax.guildBankContributionPopupHooked then return end
    GTax.guildBankContributionPopupHooked = true

    if StaticPopup_Show then
        hooksecurefunc("StaticPopup_Show", function(which)
            if which ~= "GUILDBANK_DEPOSIT" then return end
            local maxDialogs = STATICPOPUP_NUMDIALOGS or 4
            for i = 1, maxDialogs do
                local popup = _G["StaticPopup" .. i]
                if popup and popup:IsShown() and popup.which == "GUILDBANK_DEPOSIT" then
                    updateSuggestedContributionButton(popup)
                end
            end
            updateVisibleAddonMoneyDialogs()
        end)
    end

    local maxDialogs = STATICPOPUP_NUMDIALOGS or 4
    for i = 1, maxDialogs do
        local popup = _G["StaticPopup" .. i]
        if popup and popup.HookScript then
            popup:HookScript("OnShow", function(self)
                if self.which == "GUILDBANK_DEPOSIT" then
                    updateSuggestedContributionButton(self)
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
            updateSuggestedContributionMoneyButton(dialog, moneyFrame)
            scheduleAddonMoneyDialogRescan()
        end)
    end

    hookBaganatorMoneyDialogMethods()
    hookSushiGuildMoneyDialogs()
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

    -- Hook contribution and withdrawal functions here, not on login,
    -- because these are defined in Blizzard_GuildBankUI which loads lazily.
    if DepositGuildBankMoney then
        hooksecurefunc("DepositGuildBankMoney", flagPendingDeposit)
    end
    if WithdrawGuildBankMoney then
        hooksecurefunc("WithdrawGuildBankMoney", flagPendingWithdrawal)
    end

    hookGuildBankContributionPopup()

    GuildBankFrame:HookScript("OnShow", function()
        GTax.guildBankIsOpen = true
        local moneyTab = (MAX_GUILDBANK_TABS or 6) + 1
        if QueryGuildBankLog then QueryGuildBankLog(moneyTab) end
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
    hookGuildBankContributionPopup()

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
            return
        end
        if addon == "Baganator" then
            hookGuildBankContributionPopup()
            return
        end
        if addon == "BagBrother" or addon == "Bagnon" then
            hookGuildBankContributionPopup()
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
        updateVisibleAddonMoneyDialogs()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, updateVisibleAddonMoneyDialogs)
            C_Timer.After(0.2, updateVisibleAddonMoneyDialogs)
        end
        return
    end

    if event == "GUILDBANKFRAME_CLOSED" then
        GTax.guildBankIsOpen = false
        return
    end

    if event == "GUILDBANK_UPDATE_MONEY" then
        -- Guild bank money changed. Confirm pending contribution or withdrawal.
        local entry = GTax.ensureDB()
        local hasPendingDeposit = GTax.pendingDeposit
            or (type(GTax.pendingDepositAmount) == "number" and GTax.pendingDepositAmount > 0
                and (type(GTax.pendingDepositExpiresAt) ~= "number" or time() <= GTax.pendingDepositExpiresAt))
        if hasPendingDeposit then
            local contributionAmount = GTax.pendingDepositAmount
            GTax.pendingDeposit = false
            GTax.pendingDepositAmount = nil
            GTax.pendingDepositExpiresAt = nil
            if GTax.pendingDepositTimer and GTax.pendingDepositTimer.Cancel then
                GTax.pendingDepositTimer:Cancel()
            end
            GTax.pendingDepositTimer = nil
            GTax.resetTracker("guild bank contribution", contributionAmount)
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
