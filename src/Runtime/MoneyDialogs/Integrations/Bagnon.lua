-- GTax_Runtime_MoneyDialogs_Integrations_Bagnon.lua
-- Bagnon-specific dialog scanning

local addonName, GTax = ...
GTax = GTax or {}

GTax.MoneyDialogsInternal = GTax.MoneyDialogsInternal or {}
local I = GTax.MoneyDialogsInternal

function I.UpdateVisibleBagnonMoneyDialogs()
    for i = 1, 20 do
        local bagnonDialog = _G["BagnonDialog" .. i]
        if bagnonDialog and bagnonDialog:IsShown() then
            local moneyFrame = bagnonDialog.moneyBox or I.GetPopupMoneyFrame(bagnonDialog)
            if moneyFrame then
                I.UpdateSuggestedContributionMoneyButton(bagnonDialog, moneyFrame)
            end
        end
    end
end
