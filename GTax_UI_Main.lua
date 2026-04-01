-- GTax_UI_Main.lua
-- Main window creation, update logic

local addonName, GTax = ...
GTax = GTax or {}

GTax.UI = GTax.UI or {}

local function createLeftLabel(parent, previous, offsetY, text, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    label:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, offsetY)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end


function GTax.UI.UpdateWindow()
    local ui = GTax.UI
    if not ui.frame then return end
    local entry = GTax.ensureDB()
    if type(entry.show) ~= "table" then
        entry.show = {}
        for k, v in pairs(GTax.defaults.show) do entry.show[k] = v end
    end
    local showEarned = entry.show.earned ~= false
    local showEarnedToday = entry.show.earnedToday == true
    local showEarnedWeek = entry.show.earnedWeek == true
    local showLastDep = entry.show.lastDeposit ~= false
    local showSuggestedSinceLast = entry.show.suggestedSinceLast ~= false
    local showToday = entry.show.depositToday ~= false
    local showWeek = entry.show.depositWeek ~= false
    local showTotal = entry.show.depositTotal ~= false

    local earnedToday, earnedWeek = GTax.getEarningsSums(entry)

    ui.earnedText:SetText("Earned since last contribution: " .. GTax.formatMoney(entry.earnedSinceDeposit))
    ui.earnedText:SetShown(showEarned)

    -- Earned today/week text
    if not ui.earnedTodayText then
        ui.earnedTodayText = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ui.earnedTodayText:SetJustifyH("LEFT")
    end
    ui.earnedTodayText:SetText("Earned today: " .. GTax.formatMoney(earnedToday))
    ui.earnedTodayText:SetShown(showEarnedToday)

    if not ui.earnedWeekText then
        ui.earnedWeekText = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ui.earnedWeekText:SetJustifyH("LEFT")
    end
    ui.earnedWeekText:SetText("Earned this week: " .. GTax.formatMoney(earnedWeek))
    ui.earnedWeekText:SetShown(showEarnedWeek)

    ui.lastDepositText:SetText("Last contribution: " .. GTax.formatTimeSinceDeposit(entry.lastResetAt))
    local r, g, b = GTax.getDepositColor(entry.lastResetAt)
    ui.lastDepositText:SetTextColor(r, g, b)
    ui.lastDepositText:SetShown(showLastDep)
    local pct = entry.taxPercent or 3

    local today, week, total = GTax.getDepositSums(entry)
    if showSuggestedSinceLast then
        ui.suggestText:SetText("Suggested contribution at " .. pct .. "%: " .. GTax.formatMoney(GTax.getSuggestedDeposit(entry.earnedSinceDeposit, pct)))
        ui.suggestText:Show()
    else
        ui.suggestText:Hide()
    end

    ui.depositTodayText:SetText("Contributed today: " .. GTax.formatMoney(today))
    ui.depositTodayText:SetTextColor(today > 0 and 0 or 1, today > 0 and 1 or 0, 0)
    ui.depositTodayText:SetShown(showToday)
    ui.depositWeekText:SetText("Contributed this week: " .. GTax.formatMoney(week))
    ui.depositWeekText:SetTextColor(week > 0 and 0 or 1, week > 0 and 1 or 0, 0)
    ui.depositWeekText:SetShown(showWeek)
    ui.depositTotalText:SetText("Contributed total: " .. GTax.formatMoney(total))
    ui.depositTotalText:SetTextColor(total > 0 and 0 or 1, total > 0 and 1 or 0, 0)
    ui.depositTotalText:SetShown(showTotal)

    -- Re-anchor visible elements
    local elements = {
        { text = ui.earnedText, visible = showEarned, gap = false },
        { text = ui.earnedTodayText, visible = showEarnedToday, gap = false },
        { text = ui.earnedWeekText, visible = showEarnedWeek, gap = false },
        { text = nil, visible = true, gap = true },
        { text = ui.depositTodayText, visible = showToday, gap = false },
        { text = ui.depositWeekText, visible = showWeek, gap = false },
        { text = ui.depositTotalText, visible = showTotal, gap = false },
        { text = nil, visible = true, gap = true },
        { text = ui.lastDepositText, visible = showLastDep, gap = false },
    }

    local prev = ui.title
    local pendingGap = false
    local visibleTextCount = 0
    local gapCount = 0
    for _, el in ipairs(elements) do
        if el.visible and el.gap then
            if visibleTextCount > 0 then
                pendingGap = true
            end
        elseif el.visible and el.text then
            el.text:ClearAllPoints()
            local spacing = (pendingGap and prev ~= ui.title) and -14 or -8
            el.text:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, spacing)
            prev = el.text
            visibleTextCount = visibleTextCount + 1
            if pendingGap then
                gapCount = gapCount + 1
                pendingGap = false
            end
        end
    end

    -- Auto-resize window height
    local height = 10 + 16 + 8 + (visibleTextCount * 22) + (gapCount * 6) + 10
    ui.frame:SetSize(300, height)
end

function GTax.UI.CreateWindow()
    local ui = GTax.UI
    if ui.frame then return end

    local win = CreateFrame("Frame", "GTaxWindow", UIParent)
    win:SetSize(300, 175)
    win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -10)
    title:SetJustifyH("LEFT")
    title:SetText("Guild Tax Tracker")
    ui.title = title

    local earnedText = createLeftLabel(win, title, -8, "Earned since last contribution: 0g 0s 0c")
    local lastDepositText = createLeftLabel(win, earnedText, -8, "Last contribution: Never")
    local suggestText = createLeftLabel(win, lastDepositText, -8, "Suggested contribution at 3%: 0g 0s 0c")
    local depositTodayText = createLeftLabel(win, suggestText, -14, "Contributed today: 0g 0s 0c")
    local depositWeekText = createLeftLabel(win, depositTodayText, -8, "Contributed this week: 0g 0s 0c")
    local depositTotalText = createLeftLabel(win, depositWeekText, -8, "Contributed total: 0g 0s 0c")

    ui.frame = win
    ui.earnedText = earnedText
    ui.suggestText = suggestText
    ui.lastDepositText = lastDepositText
    ui.depositTodayText = depositTodayText
    ui.depositWeekText = depositWeekText
    ui.depositTotalText = depositTotalText
    local elapsed = 0
    win:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 60 then
            elapsed = 0
            GTax.UI.UpdateWindow()
        end
    end)
    GTax.UI.UpdateWindow()
    -- Show or hide based on saved setting
    local entry = GTax.ensureDB()
    if entry.showWindow == false then
        win:Hide()
    else
        win:Show()
    end
end

function GTax.UI.ToggleWindow()
    local ui = GTax.UI
    local entry = GTax.ensureDB()
    if not ui.frame then GTax.UI.CreateWindow() end
    if ui.frame:IsShown() then
        ui.frame:Hide()
        entry.showWindow = false
        GTax.printMessage("Tracker window hidden.")
    else
        GTax.UI.UpdateWindow()
        ui.frame:Show()
        entry.showWindow = true
        GTax.printMessage("Tracker window shown.")
    end
end
