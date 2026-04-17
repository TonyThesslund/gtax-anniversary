-- GTax_Runtime_MoneyDialogs_Integrations_Baganator.lua
-- Baganator-specific detection, layout behavior, visibility scans, and hooks

local addonName, GTax = ...
GTax = GTax or {}

GTax.MoneyDialogsInternal = GTax.MoneyDialogsInternal or {}
local I = GTax.MoneyDialogsInternal

local BAGANATOR_EXTRA_HEIGHT = 40
local BAGANATOR_ROW_LIFT = 16
local BAGANATOR_BOTTOM_PADDING = 14

function I.IsBaganatorMoneyDialog(dialog)
    if not dialog then return false end
    local dialogName = dialog.GetName and dialog:GetName() or ""
    if type(dialogName) == "string" and string.find(dialogName, "BaganatorDialog", 1, true) ~= nil then
        return true
    end

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
    if not I.IsBaganatorMoneyDialog(dialog) then return end

    if shouldExpand then
        if type(dialog.gtaxOriginalHeight) ~= "number" then
            dialog.gtaxOriginalHeight = dialog:GetHeight()
        end
        local targetHeight = dialog.gtaxOriginalHeight + BAGANATOR_EXTRA_HEIGHT
        local currentHeight = dialog:GetHeight()
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
    if not I.IsBaganatorMoneyDialog(dialog) then return end

    if shouldOffset then
        offsetFramePoint(dialog.moneyBox, "gtaxSavedPoint", 0, BAGANATOR_ROW_LIFT)
        offsetFramePoint(dialog.acceptButton, "gtaxSavedPoint", 0, BAGANATOR_ROW_LIFT)
        offsetFramePoint(dialog.cancelButton, "gtaxSavedPoint", 0, BAGANATOR_ROW_LIFT)
        return
    end

    restoreFramePoint(dialog.moneyBox, "gtaxSavedPoint")
    restoreFramePoint(dialog.acceptButton, "gtaxSavedPoint")
    restoreFramePoint(dialog.cancelButton, "gtaxSavedPoint")
end

local function ensureBaganatorButtonBottomMargin(dialog, button, minPadding)
    if not (dialog and button and dialog.GetBottom and button.GetBottom and dialog.GetHeight and dialog.SetHeight) then return end
    if not I.IsBaganatorMoneyDialog(dialog) then return end

    local dialogBottom = dialog:GetBottom()
    local buttonBottom = button:GetBottom()
    if type(dialogBottom) ~= "number" or type(buttonBottom) ~= "number" then return end

    local targetBottom = dialogBottom + (minPadding or BAGANATOR_BOTTOM_PADDING)
    if buttonBottom < targetBottom then
        dialog:SetHeight(dialog:GetHeight() + (targetBottom - buttonBottom))
    end
end

function I.ResetBaganatorDialogLayout(dialog)
    setBaganatorDialogExpandedForButton(dialog, false)
    setBaganatorRowsOffset(dialog, false)
end

function I.ApplyBaganatorDepositLayout(dialog, button)
    if not I.IsBaganatorMoneyDialog(dialog) then return false end
    if not (dialog.acceptButton and dialog.cancelButton) then return false end

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

    button:SetPoint("TOP", dialog.acceptButton, "BOTTOM", centerOffset, I.BOTTOM_BUTTON_ANCHOR_OFFSET_Y)
    ensureBaganatorButtonBottomMargin(dialog, button, BAGANATOR_BOTTOM_PADDING)
    return true
end

function I.UpdateVisibleBaganatorMoneyDialogs()
    for i = 1, 20 do
        local dialog = _G["BaganatorDialog" .. i]
        if dialog and dialog:IsShown() and dialog.moneyBox then
            I.UpdateSuggestedContributionMoneyButton(dialog, dialog.moneyBox)
        end
    end
end

function I.HookBaganatorMoneyDialogMethods()
    if GTax.baganatorMoneyDialogHooked then return end
    if not BaganatorSingleViewGuildViewMixin then return end

    GTax.baganatorMoneyDialogHooked = true

    if BaganatorSingleViewGuildViewMixin.DepositMoney then
        hooksecurefunc(BaganatorSingleViewGuildViewMixin, "DepositMoney", function()
            I.SetPendingMoneyDialogMode("deposit")
            if I.ScheduleAddonMoneyDialogRescan then
                I.ScheduleAddonMoneyDialogRescan()
            end
        end)
    end

    if BaganatorSingleViewGuildViewMixin.WithdrawMoney then
        hooksecurefunc(BaganatorSingleViewGuildViewMixin, "WithdrawMoney", function()
            I.SetPendingMoneyDialogMode("withdraw")
            if I.ScheduleAddonMoneyDialogRescan then
                I.ScheduleAddonMoneyDialogRescan()
            end
        end)
    end
end
