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
    opt:SetSize(400, 400)
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

    -- Flex row: two columns for earned/guild bank
    local earnedBox = CreateFrame("Frame", nil, opt)
    earnedBox:SetSize(180, 120)
    earnedBox:SetPoint("TOPLEFT", opt, "TOPLEFT", 12, -34)
    local earnedTitle = earnedBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    earnedTitle:SetPoint("TOPLEFT", earnedBox, "TOPLEFT", 0, 0)
    earnedTitle:SetText("Gold earned")
    createCheckbox(earnedBox, "Earned today", "earnedToday", -28)
    createCheckbox(earnedBox, "Earned this week", "earnedWeek", -54)
    createCheckbox(earnedBox, "Earned since last deposit", "earned", -80)

    local depositBox = CreateFrame("Frame", nil, opt)
    depositBox:SetSize(180, 120)
    depositBox:SetPoint("TOPRIGHT", opt, "TOPRIGHT", -12, -34)
    local depositTitle = depositBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    depositTitle:SetPoint("TOPLEFT", depositBox, "TOPLEFT", 0, 0)
    depositTitle:SetText("Guild bank deposits")
    createCheckbox(depositBox, "Deposited today", "depositToday", -28)
    createCheckbox(depositBox, "Deposited this week", "depositWeek", -54)
    createCheckbox(depositBox, "Deposited total", "depositTotal", -80)

    -- Suggested % section
    local suggestTitle = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    suggestTitle:SetPoint("TOPLEFT", opt, "TOPLEFT", 14, -170)
    suggestTitle:SetText("Suggested deposit")
    local cbSinceLast = createCheckbox(opt, "Suggest a deposit", "suggestedSinceLast", -196)

    -- Slider
    local sliderLabel = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sliderLabel:SetPoint("TOPLEFT", opt, "TOPLEFT", 14, -280)
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

    -- Reset/Purge buttons
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
