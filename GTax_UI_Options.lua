-- GTax_UI_Options.lua
-- Options window, checkboxes, slider, reset/purge

local addonName, GTax = ...
GTax = GTax or {}

GTax.UI = GTax.UI or {}

local function createCheckbox(parent, label, settingKey, yOffset)
    local entry = GTax.ensureDB()
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    cb:SetChecked(entry.show[settingKey] ~= false)
    cb:SetScript("OnClick", function(self)
        local e = GTax.ensureDB()
        if type(e.show) ~= "table" then e.show = {} end
        e.show[settingKey] = self:GetChecked() and true or false
        GTax.UI.UpdateWindow()
    end)
    return cb
end

function GTax.UI.ToggleOptions()
    local ui = GTax.UI
    if ui.optionsFrame then
        if ui.optionsFrame:IsShown() then
            ui.optionsFrame:Hide()
        else
            ui.optionsFrame:Show()
        end
        return
    end
    local opt = CreateFrame("Frame", "GTaxOptionsWindow", UIParent, "BackdropTemplate")
    opt:SetSize(260, 340)
    opt:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    opt:SetMovable(true)
    opt:EnableMouse(true)
    opt:RegisterForDrag("LeftButton")
    opt:SetScript("OnDragStart", function(self) self:StartMoving() end)
    opt:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if opt.SetBackdrop then
        opt:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        opt:SetBackdropColor(0, 0, 0, 0.7)
    end
    local title = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", opt, "TOP", 0, -10)
    title:SetText("GTax - Options")
    local closeBtn = CreateFrame("Button", nil, opt, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", opt, "TOPRIGHT", -2, -2)
    createCheckbox(opt, "Earned since last deposit", "earned", -34)
    createCheckbox(opt, "Last deposit", "lastDeposit", -60)
    createCheckbox(opt, "Suggested %", "suggested", -86)
    createCheckbox(opt, "Deposited today", "depositToday", -112)
    createCheckbox(opt, "Deposited this week", "depositWeek", -138)
    createCheckbox(opt, "Deposited total", "depositTotal", -164)
    local sliderLabel = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sliderLabel:SetPoint("TOPLEFT", opt, "TOPLEFT", 14, -194)
    sliderLabel:SetText("Tax %: " .. (GTax.ensureDB().taxPercent or 3))
    local slider = CreateFrame("Slider", "GTaxPercentSlider", opt, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 0, -8)
    slider:SetSize(220, 17)
    slider:SetMinMaxValues(1, 20)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(GTax.ensureDB().taxPercent or 3)
    slider.Low:SetText("1%")
    slider.High:SetText("20%")
    slider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value + 0.5)
        local e = GTax.ensureDB()
        e.taxPercent = val
        sliderLabel:SetText("Tax %: " .. val)
        GTax.UI.UpdateWindow()
    end)
    local resetBtn = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
    resetBtn:SetSize(110, 24)
    resetBtn:SetPoint("BOTTOMLEFT", opt, "BOTTOMLEFT", 12, 12)
    resetBtn:SetText("Reset Tracker")
    resetBtn:SetScript("OnClick", function()
        GTax.resetTracker("manual")
    end)
    local purgeBtn = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
    purgeBtn:SetSize(110, 24)
    purgeBtn:SetPoint("BOTTOMRIGHT", opt, "BOTTOMRIGHT", -12, 12)
    purgeBtn:SetText("Purge History")
    purgeBtn:SetScript("OnClick", function()
        local entry = GTax.ensureDB()
        entry.depositHistory = {}
        entry.importedFingerprints = {}
        GTax.UI.UpdateWindow()
        GTax.printMessage("Deposit history purged.")
    end)
    ui.optionsFrame = opt
    opt:Show()
end
