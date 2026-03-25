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
    local earnedTitle = earnedBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    earnedTitle:SetPoint("TOPLEFT", earnedBox, "TOPLEFT", 0, 0)
    earnedTitle:SetText("Gold earned")

    createCheckbox(earnedBox, "Earned today", "earnedToday", -28)
    createCheckbox(earnedBox, "Earned this week", "earnedWeek", -54)
    createCheckbox(earnedBox, "Earned since last deposit", "earned", -80)

    -- Gold earned reset buttons (stacked vertically)
    local resetSinceLastBtn = CreateFrame("Button", nil, earnedBox, "UIPanelButtonTemplate")
    resetSinceLastBtn:SetSize(140, 22)
    -- Add a small gap (extra 8px) below checkboxes
    resetSinceLastBtn:SetPoint("TOPLEFT", earnedBox, "TOPLEFT", 0, -118)
    resetSinceLastBtn:SetText("Reset Since Last")
    resetSinceLastBtn:SetScript("OnClick", function()
        GTax.resetTracker("manual")
        GTax.printMessage("'Earned since last deposit' reset.")
    end)

    local resetTodayBtn = CreateFrame("Button", nil, earnedBox, "UIPanelButtonTemplate")
    resetTodayBtn:SetSize(140, 22)
    resetTodayBtn:SetPoint("TOPLEFT", resetSinceLastBtn, "BOTTOMLEFT", 0, -4)
    resetTodayBtn:SetText("Reset Today")
    resetTodayBtn:SetScript("OnClick", function()
        local entry = GTax.ensureDB()
        if type(entry.earningsHistory) == "table" then
            local now = time()
            local d = date("*t", now)
            local todayStart = time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
            local newHistory = {}
            for _, record in ipairs(entry.earningsHistory) do
                if (record.timestamp or 0) < todayStart then
                    table.insert(newHistory, record)
                end
            end
            entry.earningsHistory = newHistory
        end
        if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
        GTax.printMessage("'Earned today' reset.")
    end)

    local resetWeekBtn = CreateFrame("Button", nil, earnedBox, "UIPanelButtonTemplate")
    resetWeekBtn:SetSize(140, 22)
    resetWeekBtn:SetPoint("TOPLEFT", resetTodayBtn, "BOTTOMLEFT", 0, -4)
    resetWeekBtn:SetText("Reset This Week")
    resetWeekBtn:SetScript("OnClick", function()
        local entry = GTax.ensureDB()
        if type(entry.earningsHistory) == "table" then
            local now = time()
            local d = date("*t", now)
            local todayStart = time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
            local wday = d.wday -- 1=Sunday
            local dayOffset = (wday == 1) and 6 or (wday - 2)
            local weekStart = todayStart - (dayOffset * 86400)
            local newHistory = {}
            for _, record in ipairs(entry.earningsHistory) do
                if (record.timestamp or 0) < weekStart then
                    table.insert(newHistory, record)
                end
            end
            entry.earningsHistory = newHistory
        end
        if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
        GTax.printMessage("'Earned this week' reset.")
    end)

    local depositBox = CreateFrame("Frame", nil, opt)
    depositBox:SetSize(180, 120)
    depositBox:SetPoint("TOPRIGHT", opt, "TOPRIGHT", -12, -34)
    local depositTitle = depositBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    depositTitle:SetPoint("TOPLEFT", depositBox, "TOPLEFT", 0, 0)
    depositTitle:SetText("Guild bank deposits")

    createCheckbox(depositBox, "Deposited today", "depositToday", -28)
    createCheckbox(depositBox, "Deposited this week", "depositWeek", -54)
    createCheckbox(depositBox, "Deposited total", "depositTotal", -80)

    -- Purge button under Guild bank deposits
    local purgeBtn = CreateFrame("Button", nil, depositBox, "UIPanelButtonTemplate")
    purgeBtn:SetSize(140, 22)
    -- Add a small gap (extra 8px) below checkboxes
    purgeBtn:SetPoint("TOPLEFT", depositBox, "TOPLEFT", 0, -118)
    purgeBtn:SetText("Purge History")
    purgeBtn:SetScript("OnClick", function()
        local entry = GTax.ensureDB()
        entry.depositHistory = {}
        entry.importedFingerprints = {}
        GTax.UI.UpdateWindow()
        GTax.printMessage("Deposit history purged.")
    end)

    -- Suggested % section
    local suggestTitle = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    suggestTitle:SetPoint("TOPLEFT", opt, "TOPLEFT", 14, -270)
    suggestTitle:SetText("Suggested deposit")
    local cbSinceLast = createCheckbox(opt, "Suggest a deposit", "suggestedSinceLast", -296)

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
