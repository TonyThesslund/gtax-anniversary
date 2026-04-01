-- GTax_UI_Options.lua
-- Options window, checkboxes, slider, reset/purge

local addonName, GTax = ...
GTax = GTax or {}

GTax.UI = GTax.UI or {}

local LEADERBOARD_ROWS = 20
local LB_PLAYER_X = 0
local LB_TOTAL_X = 112
local LB_TODAY_X = 272
local LB_WEEK_X = 432
local LB_LAST_X = 600
local LB_LOANS_X = 765
local LB_PLAYER_W = 100
local LB_TOTAL_W = 150
local LB_TODAY_W = 150
local LB_WEEK_W = 155
local LB_LAST_W = 155
local LB_LOANS_W = 90
local LB_ROW_H = 20
local LB_ROW_W = LB_LOANS_X + LB_LOANS_W - 8
local LEFT_SECTION_GAP = -18

local function getGuildLeaderboardTitle()
    local guildName = GetGuildInfo and GetGuildInfo("player")
    if type(guildName) == "string" and guildName ~= "" then
        return guildName .. " Guild Leaderboard"
    end
    return "Guild Leaderboard"
end

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

local function createLeaderboardCell(parent, template, point, relativeTo, relativePoint, x, y)
    local cell = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    cell:SetPoint(point, relativeTo, relativePoint, x, y)
    cell:SetJustifyH("LEFT")
    return cell
end

local function createLeaderboardRow(parent, anchor, yOffset)
    local row = {}
    local rowAnchor = CreateFrame("Frame", nil, parent)
    rowAnchor:SetSize(LB_ROW_W, LB_ROW_H)
    rowAnchor:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    row.anchor = rowAnchor

    row.strip = rowAnchor:CreateTexture(nil, "BACKGROUND")
    row.strip:SetAllPoints(rowAnchor)
    row.strip:SetColorTexture(1, 1, 1, 0)

    row.player = createLeaderboardCell(parent, "GameFontNormalSmall", "LEFT", rowAnchor, "LEFT", LB_PLAYER_X, 0)
    row.total = createLeaderboardCell(parent, "GameFontNormalSmall", "LEFT", rowAnchor, "LEFT", LB_TOTAL_X, 0)
    row.today = createLeaderboardCell(parent, "GameFontNormalSmall", "LEFT", rowAnchor, "LEFT", LB_TODAY_X, 0)
    row.week = createLeaderboardCell(parent, "GameFontNormalSmall", "LEFT", rowAnchor, "LEFT", LB_WEEK_X, 0)
    row.last = createLeaderboardCell(parent, "GameFontNormalSmall", "LEFT", rowAnchor, "LEFT", LB_LAST_X, 0)
    row.loans = createLeaderboardCell(parent, "GameFontNormalSmall", "LEFT", rowAnchor, "LEFT", LB_LOANS_X, 0)
    return row
end

local function createSortableLeaderboardHeader(parent, text, sortKey, width, point, relativeTo, relativePoint, x, y)
    local header = CreateFrame("Button", nil, parent)
    header:SetSize(width, 16)
    header:SetPoint(point, relativeTo, relativePoint, x, y)
    header.sortKey = sortKey
    header.baseText = text

    local label = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", header, "LEFT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    header.label = label

    header:SetScript("OnClick", function(self)
        local ui = GTax.UI
        if ui.leaderboardSortKey == self.sortKey then
            ui.leaderboardSortAsc = not ui.leaderboardSortAsc
        else
            ui.leaderboardSortKey = self.sortKey
            ui.leaderboardSortAsc = (self.sortKey == "player")
        end
        GTax.UI.UpdateLeaderboard()
    end)

    return header
end

function GTax.UI.UpdateLeaderboard()
    local ui = GTax.UI
    if not ui.optionsFrame or not ui.leaderboardRows then return end

    ui.leaderboardSortKey = ui.leaderboardSortKey or "total"
    if ui.leaderboardSortAsc == nil then
        ui.leaderboardSortAsc = false
    end

    local entries = {}
    if GTax.getLeaderboardEntries then
        entries = GTax.getLeaderboardEntries()
    end

    local sortKey = ui.leaderboardSortKey
    local sortAsc = ui.leaderboardSortAsc
    table.sort(entries, function(a, b)
        if sortKey == "player" then
            local av = string.lower(a.player or "")
            local bv = string.lower(b.player or "")
            if av ~= bv then
                if sortAsc then return av < bv end
                return av > bv
            end
        else
            local av = tonumber(a[sortKey]) or 0
            local bv = tonumber(b[sortKey]) or 0
            if av ~= bv then
                if sortAsc then return av < bv end
                return av > bv
            end
        end

        local at = tonumber(a.total) or 0
        local bt = tonumber(b.total) or 0
        if at ~= bt then return at > bt end
        return string.lower(a.player or "") < string.lower(b.player or "")
    end)

    local scrollOffset = 0
    local maxOffset = math.max(0, #entries - LEADERBOARD_ROWS)
    ui.leaderboardScrollOffset = math.min(math.max(ui.leaderboardScrollOffset or 0, 0), maxOffset)

    if ui.leaderboardScrollFrame and FauxScrollFrame_Update then
        FauxScrollFrame_Update(ui.leaderboardScrollFrame, #entries, LEADERBOARD_ROWS, LB_ROW_H)
        if FauxScrollFrame_GetOffset then
            scrollOffset = FauxScrollFrame_GetOffset(ui.leaderboardScrollFrame)
        else
            scrollOffset = ui.leaderboardScrollOffset
        end
    else
        scrollOffset = ui.leaderboardScrollOffset
    end

    if ui.leaderboardHeaders then
        for _, header in ipairs(ui.leaderboardHeaders) do
            local suffix = ""
            if header.sortKey == sortKey then
                suffix = sortAsc and " ^" or " v"
                header.label:SetTextColor(1, 0.82, 0)
            else
                header.label:SetTextColor(1, 1, 1)
            end
            header.label:SetText(header.baseText .. suffix)
        end
    end

    local myName = UnitName("player") or ""
    for i, row in ipairs(ui.leaderboardRows) do
        local record = entries[scrollOffset + i]

        if record then
            row.strip:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.09 or 0)
            row.player:SetText(record.player)
            row.total:SetText(GTax.formatMoney(record.total))
            row.today:SetText(GTax.formatMoney(record.today))
            row.week:SetText(GTax.formatMoney(record.week))
            row.last:SetText(GTax.formatTimeSinceDeposit(record.lastContributionAt))
            row.loans:SetText(GTax.formatMoney(record.unpaidLoans or 0))

            row.total:SetTextColor(1, 1, 1)
            row.today:SetTextColor(1, 1, 1)
            row.week:SetTextColor(1, 1, 1)
            row.last:SetTextColor(1, 1, 1)

            if (record.unpaidLoans or 0) > 0 then
                row.loans:SetTextColor(1, 0.2, 0.2)
            else
                row.loans:SetTextColor(1, 1, 1)
            end

            if record.player == myName then
                row.player:SetTextColor(1, 0.82, 0)
            else
                row.player:SetTextColor(1, 1, 1)
            end

            row.total:Show()
            row.today:Show()
            row.week:Show()
            row.last:Show()
            row.loans:Show()
            row.player:Show()
        else
            row.player:SetText("")
            row.total:SetText("")
            row.today:SetText("")
            row.week:SetText("")
            row.last:SetText("")
            row.loans:SetText("")
            row.strip:SetColorTexture(1, 1, 1, 0)
        end
    end
end

local function createCheckbox(parent, label, settingKey, yOffset)
    local entry = GTax.ensureDB()
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
    ui.leaderboardSortKey = ui.leaderboardSortKey or "total"
    if ui.leaderboardSortAsc == nil then
        ui.leaderboardSortAsc = false
    end

    if ui.optionsFrame then
        if ui.optionsFrame:IsShown() then
            ui.optionsFrame:Hide()
        else
            if ui.leaderboardTitle then
                ui.leaderboardTitle:SetText(getGuildLeaderboardTitle())
            end
            ui.optionsFrame:SetFrameStrata("DIALOG")
            ui.optionsFrame:Show()
            ui.optionsFrame:Raise()
            GTax.UI.UpdateLeaderboard()
        end
        return
    end
    local opt = CreateFrame("Frame", "GTaxOptionsWindow", UIParent, "BasicFrameTemplateWithInset")
    opt:SetSize(950, 540)
    opt:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    opt:SetMovable(true)
    opt:EnableMouse(true)
    opt:SetToplevel(true)
    opt:SetFrameStrata("DIALOG")
    opt:RegisterForDrag("LeftButton")
    opt:SetScript("OnDragStart", function(self) self:StartMoving() end)
    opt:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    opt:HookScript("OnShow", function(self)
        self:SetFrameStrata("DIALOG")
        self:Raise()
    end)
    if opt.Inset and opt.Inset.SetBackdropColor then
        opt.Inset:SetBackdropColor(0.03, 0.03, 0.03, 0.78)
    end
    if opt.TitleText then
        opt.TitleText:SetText("GTax - Options & Leaderboard")
    end

    -- Flex row: two columns for earned/guild bank
    local earnedBox = CreateFrame("Frame", nil, opt)
    earnedBox:SetSize(170, 110)
    earnedBox:SetPoint("TOPLEFT", opt, "TOPLEFT", 12, -34)
    createSectionTitle(earnedBox, "Earned gold", "TOPLEFT", earnedBox, "TOPLEFT", 0, 0)

    createCheckbox(earnedBox, "Earned today", "earnedToday", -28)
    createCheckbox(earnedBox, "Earned this week", "earnedWeek", -54)
    createCheckbox(earnedBox, "Earned since last contribution", "earned", -80)

    local resetSinceLastBtn = createActionButton(earnedBox, "Reset Since Last", 132, 20, "TOPLEFT", earnedBox, "TOPLEFT", 0, -112, function()
        GTax.resetTracker("manual")
        GTax.printMessage("Earned gold since the last contribution was reset.")
    end)

    local resetTodayBtn = createActionButton(earnedBox, "Reset Today", 132, 20, "TOPLEFT", resetSinceLastBtn, "BOTTOMLEFT", 0, -3, function()
        local entry = GTax.ensureDB()
        GTax.clearEarningsSince(entry, GTax.getStartOfDay())
        if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
        GTax.printMessage("Today's earned gold was reset.")
    end)

    local resetWeekBtn = createActionButton(earnedBox, "Reset This Week", 132, 20, "TOPLEFT", resetTodayBtn, "BOTTOMLEFT", 0, -3, function()
        local entry = GTax.ensureDB()
        GTax.clearEarningsSince(entry, GTax.getStartOfWeek())
        if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
        GTax.printMessage("This week's earned gold was reset.")
    end)

    local depositBox = CreateFrame("Frame", nil, opt)
    depositBox:SetSize(170, 110)
    depositBox:SetPoint("TOPLEFT", resetWeekBtn, "BOTTOMLEFT", 0, LEFT_SECTION_GAP)
    createSectionTitle(depositBox, "Guild bank contributions", "TOPLEFT", depositBox, "TOPLEFT", 0, 0)

    createCheckbox(depositBox, "Contributed today", "depositToday", -28)
    createCheckbox(depositBox, "Contributed this week", "depositWeek", -54)
    createCheckbox(depositBox, "Contributed total", "depositTotal", -80)

    local purgeBtn = createActionButton(depositBox, "Purge History", 132, 20, "TOPLEFT", depositBox, "TOPLEFT", 0, -112, function()
        local entry = GTax.ensureDB()
        entry.depositHistory = {}
        GTax.UI.UpdateWindow()
        GTax.printMessage("Contribution history purged.")
    end)

    local suggestTitle = createSectionTitle(opt, "Suggested contribution", "TOPLEFT", purgeBtn, "BOTTOMLEFT", 0, LEFT_SECTION_GAP)

    local suggestBox = CreateFrame("Frame", nil, opt)
    suggestBox:SetSize(220, 30)
    suggestBox:SetPoint("TOPLEFT", suggestTitle, "BOTTOMLEFT", 0, -6)
    createCheckbox(suggestBox, "Suggest a contribution", "suggestedSinceLast", 0)

    local sliderLabel = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sliderLabel:SetPoint("TOPLEFT", suggestBox, "BOTTOMLEFT", 0, -2)
    sliderLabel:SetText("Tax %: " .. (GTax.ensureDB().taxPercent or 3))
    local slider = CreateFrame("Slider", "GTaxPercentSlider", opt, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 0, -8)
    slider:SetSize(190, 20)
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

    local divider = opt:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.35, 0.35, 0.35, 0.85)
    divider:SetWidth(2)
    divider:SetPoint("TOPLEFT", opt, "TOPLEFT", 248, -34)
    divider:SetPoint("BOTTOMLEFT", opt, "BOTTOMLEFT", 248, 30)

    local leaderboardTitle = createSectionTitle(opt, getGuildLeaderboardTitle(), "TOPLEFT", opt, "TOPLEFT", 270, -34)
    ui.leaderboardTitle = leaderboardTitle
    local headers = {
        createSortableLeaderboardHeader(opt, "Player", "player", 100, "TOPLEFT", leaderboardTitle, "BOTTOMLEFT", LB_PLAYER_X, -14),
        createSortableLeaderboardHeader(opt, "Contributed Total", "total", 150, "TOPLEFT", leaderboardTitle, "BOTTOMLEFT", LB_TOTAL_X, -14),
        createSortableLeaderboardHeader(opt, "Contributed Today", "today", 150, "TOPLEFT", leaderboardTitle, "BOTTOMLEFT", LB_TODAY_X, -14),
        createSortableLeaderboardHeader(opt, "Contributed This Week", "week", 155, "TOPLEFT", leaderboardTitle, "BOTTOMLEFT", LB_WEEK_X, -14),
        createSortableLeaderboardHeader(opt, "Last Contribution", "lastContributionAt", 155, "TOPLEFT", leaderboardTitle, "BOTTOMLEFT", LB_LAST_X, -14),
        createSortableLeaderboardHeader(opt, "Unpaid Loans", "unpaidLoans", 90, "TOPLEFT", leaderboardTitle, "BOTTOMLEFT", LB_LOANS_X, -14),
    }
    ui.leaderboardHeaders = headers

    local headerDivider = opt:CreateTexture(nil, "ARTWORK")
    headerDivider:SetColorTexture(0.62, 0.62, 0.62, 0.8)
    headerDivider:SetSize(LB_ROW_W, 1)
    headerDivider:SetPoint("TOPLEFT", leaderboardTitle, "BOTTOMLEFT", 0, -30)

    local rows = {}
    local anchor = headerDivider
    for i = 1, LEADERBOARD_ROWS do
        local yOffset = (i == 1) and -2 or 0
        local row = createLeaderboardRow(opt, anchor, yOffset)
        table.insert(rows, row)
        anchor = row.anchor
    end
    ui.leaderboardRows = rows

    local scrollFrame = CreateFrame("ScrollFrame", "GTaxLeaderboardScrollFrame", opt, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerDivider, "BOTTOMLEFT", LB_ROW_W + 3, -2)
    scrollFrame:SetPoint("BOTTOMLEFT", rows[#rows].anchor, "BOTTOMLEFT", LB_ROW_W + 3, 0)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        if FauxScrollFrame_OnVerticalScroll then
            FauxScrollFrame_OnVerticalScroll(self, offset, LB_ROW_H, function()
                if FauxScrollFrame_GetOffset then
                    ui.leaderboardScrollOffset = FauxScrollFrame_GetOffset(self)
                end
                GTax.UI.UpdateLeaderboard()
            end)
        end
    end)
    ui.leaderboardScrollFrame = scrollFrame
    ui.leaderboardScrollOffset = 0

    ui.optionsFrame = opt
    opt:Show()
    GTax.UI.UpdateLeaderboard()
end
