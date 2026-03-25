-- GTax_UI_Main.lua
-- Main window creation, update logic

local addonName, GTax = ...
GTax = GTax or {}

GTax.UI = GTax.UI or {}

function GTax.UI.UpdateWindow()
    local ui = GTax.UI
    if not ui.frame then return end
    local entry = GTax.ensureDB()
    if type(entry.show) ~= "table" then
        entry.show = {}
        for k, v in pairs(GTax.defaults.show) do entry.show[k] = v end
    end
    local showEarned = entry.show.earned ~= false
    local showLastDep = entry.show.lastDeposit ~= false
    local showSuggested = entry.show.suggested ~= false
    local showToday = entry.show.depositToday ~= false
    local showWeek = entry.show.depositWeek ~= false
    local showTotal = entry.show.depositTotal ~= false
    ui.earnedText:SetText("Earned since last deposit: " .. GTax.formatMoney(entry.earnedSinceDeposit))
    ui.earnedText:SetShown(showEarned)
    ui.lastDepositText:SetText("Last deposit: " .. GTax.formatTimeSinceDeposit(entry.lastResetAt))
    local r, g, b = GTax.getDepositColor(entry.lastResetAt)
    ui.lastDepositText:SetTextColor(r, g, b)
    ui.lastDepositText:SetShown(showLastDep)
    local pct = entry.taxPercent or 3
    ui.suggestText:SetText("Suggested " .. pct .. "%: " .. GTax.formatMoney(GTax.getSuggestedDeposit(entry.earnedSinceDeposit, pct)))
    ui.suggestText:SetShown(showSuggested)
    local today, week, total = GTax.getDepositSums(entry)
    ui.depositTodayText:SetText("Deposited today: " .. GTax.formatMoney(today))
    ui.depositTodayText:SetTextColor(today > 0 and 0 or 1, today > 0 and 1 or 0, 0)
    ui.depositTodayText:SetShown(showToday)
    ui.depositWeekText:SetText("Deposited this week: " .. GTax.formatMoney(week))
    ui.depositWeekText:SetTextColor(week > 0 and 0 or 1, week > 0 and 1 or 0, 0)
    ui.depositWeekText:SetShown(showWeek)
    ui.depositTotalText:SetText("Deposited total: " .. GTax.formatMoney(total))
    ui.depositTotalText:SetTextColor(total > 0 and 0 or 1, total > 0 and 1 or 0, 0)
    ui.depositTotalText:SetShown(showTotal)
    -- Re-anchor visible elements
    local elements = {
        { text = ui.earnedText, visible = showEarned, gap = false },
        { text = ui.lastDepositText, visible = showLastDep, gap = false },
        { text = ui.suggestText, visible = showSuggested, gap = false },
        { text = ui.depositTodayText, visible = showToday, gap = true },
        { text = ui.depositWeekText, visible = showWeek, gap = false },
        { text = ui.depositTotalText, visible = showTotal, gap = false },
    }
    local prev = ui.title
    for _, el in ipairs(elements) do
        if el.visible then
            el.text:ClearAllPoints()
            local spacing = (el.gap and prev ~= ui.title) and -14 or -8
            el.text:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, spacing)
            prev = el.text
        end
    end
    -- Auto-resize window height
    local count = 0
    local gaps = 0
    for _, el in ipairs(elements) do
        if el.visible then
            count = count + 1
            if el.gap and count > 1 then gaps = gaps + 1 end
        end
    end
    local height = 10 + 16 + 8 + (count * 22) + (gaps * 6) + 10
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
    title:SetText("Guild Tax")
    ui.title = title
    local earnedText = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    earnedText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    earnedText:SetJustifyH("LEFT")
    earnedText:SetText("Earned since last deposit: 0g 0s 0c")
    local lastDepositText = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lastDepositText:SetPoint("TOPLEFT", earnedText, "BOTTOMLEFT", 0, -8)
    lastDepositText:SetJustifyH("LEFT")
    lastDepositText:SetText("Last deposit: Never")
    local suggestText = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    suggestText:SetPoint("TOPLEFT", lastDepositText, "BOTTOMLEFT", 0, -8)
    suggestText:SetJustifyH("LEFT")
    suggestText:SetText("Suggested %: 0g 0s 0c")
    local depositTodayText = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    depositTodayText:SetPoint("TOPLEFT", suggestText, "BOTTOMLEFT", 0, -14)
    depositTodayText:SetJustifyH("LEFT")
    depositTodayText:SetText("Deposited today: 0g 0s 0c")
    local depositWeekText = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    depositWeekText:SetPoint("TOPLEFT", depositTodayText, "BOTTOMLEFT", 0, -8)
    depositWeekText:SetJustifyH("LEFT")
    depositWeekText:SetText("Deposited this week: 0g 0s 0c")
    local depositTotalText = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    depositTotalText:SetPoint("TOPLEFT", depositWeekText, "BOTTOMLEFT", 0, -8)
    depositTotalText:SetJustifyH("LEFT")
    depositTotalText:SetText("Deposited total: 0g 0s 0c")
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
end

function GTax.UI.ToggleWindow()
    local ui = GTax.UI
    if not ui.frame then GTax.UI.CreateWindow() end
    if ui.frame:IsShown() then
        ui.frame:Hide()
        GTax.printMessage("Window hidden.")
    else
        GTax.UI.UpdateWindow()
        ui.frame:Show()
        GTax.printMessage("Window shown.")
    end
end
