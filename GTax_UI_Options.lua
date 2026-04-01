-- GTax_UI_Options.lua
-- Options window, checkboxes, slider, reset/purge

local addonName, GTax = ...
GTax = GTax or {}

GTax.UI = GTax.UI or {}

local function createSectionTitle(parent, text, point, relativeTo, relativePoint, x, y)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint(point, relativeTo, relativePoint, x, y)
    title:SetText(text)
    return title
end

local function createActionButton(parent, text, width, height, point, relativeTo, relativePoint, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetPoint(point, relativeTo, relativePoint, x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

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
    opt:SetSize(400, 420)
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
    createSectionTitle(earnedBox, "Earned gold", "TOPLEFT", earnedBox, "TOPLEFT", 0, 0)

    createCheckbox(earnedBox, "Earned today", "earnedToday", -28)
    createCheckbox(earnedBox, "Earned this week", "earnedWeek", -54)
    createCheckbox(earnedBox, "Earned since last contribution", "earned", -80)

    local resetSinceLastBtn = createActionButton(earnedBox, "Reset Since Last", 140, 22, "TOPLEFT", earnedBox, "TOPLEFT", 0, -118, function()
        GTax.resetTracker("manual")
        GTax.printMessage("Earned gold since the last contribution was reset.")
    end)

    local resetTodayBtn = createActionButton(earnedBox, "Reset Today", 140, 22, "TOPLEFT", resetSinceLastBtn, "BOTTOMLEFT", 0, -4, function()
        local entry = GTax.ensureDB()
        GTax.clearEarningsSince(entry, GTax.getStartOfDay())
        if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
        GTax.printMessage("Today's earned gold was reset.")
    end)

    createActionButton(earnedBox, "Reset This Week", 140, 22, "TOPLEFT", resetTodayBtn, "BOTTOMLEFT", 0, -4, function()
        local entry = GTax.ensureDB()
        GTax.clearEarningsSince(entry, GTax.getStartOfWeek())
        if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
        GTax.printMessage("This week's earned gold was reset.")
    end)

    local depositBox = CreateFrame("Frame", nil, opt)
    depositBox:SetSize(180, 120)
    depositBox:SetPoint("TOPRIGHT", opt, "TOPRIGHT", -12, -34)
    createSectionTitle(depositBox, "Guild bank contributions", "TOPLEFT", depositBox, "TOPLEFT", 0, 0)

    createCheckbox(depositBox, "Contributed today", "depositToday", -28)
    createCheckbox(depositBox, "Contributed this week", "depositWeek", -54)
    createCheckbox(depositBox, "Contributed total", "depositTotal", -80)

    createActionButton(depositBox, "Purge History", 140, 22, "TOPLEFT", depositBox, "TOPLEFT", 0, -118, function()
        local entry = GTax.ensureDB()
        entry.depositHistory = {}
        GTax.UI.UpdateWindow()
        GTax.printMessage("Contribution history purged.")
    end)

    createSectionTitle(opt, "Suggested contribution", "TOPLEFT", opt, "TOPLEFT", 14, -270)
    createCheckbox(opt, "Suggest a contribution", "suggestedSinceLast", -296)

    -- Slider (reduce gap below checkbox)
    local sliderLabel = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sliderLabel:SetPoint("TOPLEFT", opt, "TOPLEFT", 14, -330)
    sliderLabel:SetText("Tax %: " .. (GTax.ensureDB().taxPercent or 3))
    local slider = CreateFrame("Slider", "GTaxPercentSlider", opt, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 0, -8)
    slider:SetSize(220, 24)
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

    -- Manually add a track texture for the slider (robust for all WoW versions)
    if slider.SetThumbTexture then
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end
    if slider.track then slider.track:Hide() end -- Remove any previous
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    track:SetPoint("TOPLEFT", 6, -6)
    track:SetPoint("BOTTOMRIGHT", -6, 6)
    slider.track = track

    -- Reset buttons
    -- (no duplicate slider here)

    ui.optionsFrame = opt
    opt:Show()
end
