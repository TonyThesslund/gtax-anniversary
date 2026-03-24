local addonName = ...
local addonPrefix = "|cff5fd7ffGTax|r"

local frame = CreateFrame("Frame")
local playerNameLower = nil
local characterKey = nil
local guildBankIsOpen = false
local pendingDeposit = false
local pendingDepositTimer = nil
local resetTracker
local ui = {
    frame = nil,
    title = nil,
    earnedText = nil,
    suggestText = nil,
    lastDepositText = nil,
    depositTodayText = nil,
    depositWeekText = nil,
    depositTotalText = nil,
    optionsFrame = nil,
}

local defaults = {
    earnedSinceDeposit = 0,
    lastKnownMoney = nil,
    lastResetAt = 0,
    lastDepositFingerprint = nil,
    depositHistory = {},
    taxPercent = 3,
    minimapAngle = 220,
    showMinimap = true,
    show = {
        earned = true,
        lastDeposit = true,
        suggested = true,
        depositToday = true,
        depositWeek = true,
        depositTotal = true,
    },
}

local function getCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return realm .. "-" .. name
end

local function ensureDB()
    if type(GTaxDB) ~= "table" then
        GTaxDB = {}
    end

    if type(GTaxDB.characters) ~= "table" then
        GTaxDB.characters = {}
    end

    characterKey = getCharacterKey()

    if type(GTaxDB.characters[characterKey]) ~= "table" then
        GTaxDB.characters[characterKey] = {}
    end

    local entry = GTaxDB.characters[characterKey]
    for k, v in pairs(defaults) do
        if entry[k] == nil then
            entry[k] = v
        end
    end

    return entry
end

local function formatMoney(money)
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    return string.format("%dg %ds %dc", gold, silver, copper)
end

local function printMessage(text)
    print(string.format("%s %s", addonPrefix, text))
end

local function getSuggestedDeposit(money, pct)
    if type(money) ~= "number" or money <= 0 then
        return 0
    end

    local rate = (pct or 3) / 100
    -- Rounded to nearest copper.
    return math.floor((money * rate) + 0.5)
end

local function formatTimeSinceDeposit(timestamp)
    if type(timestamp) ~= "number" or timestamp <= 0 then
        return "Never"
    end

    local now = time()
    if type(now) ~= "number" then
        return "Unknown"
    end

    local elapsed = now - timestamp
    if elapsed < 0 then
        elapsed = 0
    end

    local days = math.floor(elapsed / 86400)
    local hours = math.floor((elapsed % 86400) / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)

    return string.format("%dd %dh %dm ago", days, hours, minutes)
end

local function showLastDeposit()
    local entry = ensureDB()
    printMessage("Time since last deposit: " .. formatTimeSinceDeposit(entry.lastResetAt))
end

local function getStartOfDay()
    local d = date("*t")
    return time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
end

local function getStartOfWeek()
    local d = date("*t")
    local wday = d.wday -- 1=Sunday
    local dayOffset = (wday == 1) and 6 or (wday - 2) -- Monday as start
    local startOfDay = time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
    return startOfDay - (dayOffset * 86400)
end

local function getDepositSums(entry)
    local history = entry.depositHistory
    if type(history) ~= "table" then
        return 0, 0, 0
    end

    local todayStart = getStartOfDay()
    local weekStart = getStartOfWeek()
    local today, week, total = 0, 0, 0

    for _, record in ipairs(history) do
        local amt = record.amount or 0
        local ts = record.timestamp or 0
        total = total + amt
        if ts >= weekStart then
            week = week + amt
        end
        if ts >= todayStart then
            today = today + amt
        end
    end

    return today, week, total
end

local function getDepositColor(timestamp)
    if type(timestamp) ~= "number" or timestamp <= 0 then
        return 1, 0, 0
    end

    local elapsed = time() - timestamp
    local days = elapsed / 86400

    if days <= 1 then
        return 0, 1, 0
    elseif days >= 7 then
        return 1, 0, 0
    end

    local t = (days - 1) / 6
    return t, 1 - t, 0
end

local function updateWindow()
    if not ui.frame then
        return
    end

    local entry = ensureDB()
    if type(entry.show) ~= "table" then
        entry.show = {}
        for k, v in pairs(defaults.show) do
            entry.show[k] = v
        end
    end

    local showEarned = entry.show.earned ~= false
    local showLastDep = entry.show.lastDeposit ~= false
    local showSuggested = entry.show.suggested ~= false
    local showToday = entry.show.depositToday ~= false
    local showWeek = entry.show.depositWeek ~= false
    local showTotal = entry.show.depositTotal ~= false

    ui.earnedText:SetText("Earned since last deposit: " .. formatMoney(entry.earnedSinceDeposit))
    ui.earnedText:SetShown(showEarned)

    ui.lastDepositText:SetText("Last deposit: " .. formatTimeSinceDeposit(entry.lastResetAt))
    local r, g, b = getDepositColor(entry.lastResetAt)
    ui.lastDepositText:SetTextColor(r, g, b)
    ui.lastDepositText:SetShown(showLastDep)

    local pct = entry.taxPercent or 3
    ui.suggestText:SetText("Suggested " .. pct .. "%: " .. formatMoney(getSuggestedDeposit(entry.earnedSinceDeposit, pct)))
    ui.suggestText:SetShown(showSuggested)

    local today, week, total = getDepositSums(entry)
    ui.depositTodayText:SetText("Deposited today: " .. formatMoney(today))
    ui.depositTodayText:SetTextColor(today > 0 and 0 or 1, today > 0 and 1 or 0, 0)
    ui.depositTodayText:SetShown(showToday)

    ui.depositWeekText:SetText("Deposited this week: " .. formatMoney(week))
    ui.depositWeekText:SetTextColor(week > 0 and 0 or 1, week > 0 and 1 or 0, 0)
    ui.depositWeekText:SetShown(showWeek)

    ui.depositTotalText:SetText("Deposited total: " .. formatMoney(total))
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
            if el.gap and count > 1 then
                gaps = gaps + 1
            end
        end
    end
    local height = 10 + 16 + 8 + (count * 22) + (gaps * 6) + 10
    ui.frame:SetSize(300, height)
end

local function createWindow()
    if ui.frame then
        return
    end

    local win = CreateFrame("Frame", "GTaxWindow", UIParent)
    win:SetSize(300, 175)
    win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

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
            updateWindow()
        end
    end)

    updateWindow()
end

local function createCheckbox(parent, label, settingKey, yOffset)
    local entry = ensureDB()
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    cb:SetChecked(entry.show[settingKey] ~= false)
    cb:SetScript("OnClick", function(self)
        local e = ensureDB()
        if type(e.show) ~= "table" then
            e.show = {}
        end
        e.show[settingKey] = self:GetChecked() and true or false
        updateWindow()
    end)

    return cb
end

local function toggleOptions()
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
            tile = true,
            tileSize = 16,
            edgeSize = 12,
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
    sliderLabel:SetText("Tax %: " .. (ensureDB().taxPercent or 3))

    local slider = CreateFrame("Slider", "GTaxPercentSlider", opt, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 0, -8)
    slider:SetSize(220, 17)
    slider:SetMinMaxValues(1, 20)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(ensureDB().taxPercent or 3)
    slider.Low:SetText("1%")
    slider.High:SetText("20%")
    slider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value + 0.5)
        local e = ensureDB()
        e.taxPercent = val
        sliderLabel:SetText("Tax %: " .. val)
        updateWindow()
    end)

    local resetBtn = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
    resetBtn:SetSize(110, 24)
    resetBtn:SetPoint("BOTTOMLEFT", opt, "BOTTOMLEFT", 12, 12)
    resetBtn:SetText("Reset Tracker")
    resetBtn:SetScript("OnClick", function()
        resetTracker("manual")
    end)

    local purgeBtn = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
    purgeBtn:SetSize(110, 24)
    purgeBtn:SetPoint("BOTTOMRIGHT", opt, "BOTTOMRIGHT", -12, 12)
    purgeBtn:SetText("Purge History")
    purgeBtn:SetScript("OnClick", function()
        local entry = ensureDB()
        entry.depositHistory = {}
        entry.importedFingerprints = {}
        updateWindow()
        printMessage("Deposit history purged.")
    end)

    ui.optionsFrame = opt
    opt:Show()
end

local function toggleWindow()
    if not ui.frame then
        createWindow()
    end

    if ui.frame:IsShown() then
        ui.frame:Hide()
        printMessage("Window hidden.")
    else
        updateWindow()
        ui.frame:Show()
        printMessage("Window shown.")
    end
end

local function showEarned()
    local entry = ensureDB()
    printMessage("Earned since last guild bank deposit: " .. formatMoney(entry.earnedSinceDeposit))
    printMessage("Suggested guild bank deposit (3%): " .. formatMoney(getSuggestedDeposit(entry.earnedSinceDeposit)))
    printMessage("Time since last deposit: " .. formatTimeSinceDeposit(entry.lastResetAt))
    updateWindow()
end

local function recordDeposit(entry, amount)
    if type(entry.depositHistory) ~= "table" then
        entry.depositHistory = {}
    end
    if type(amount) == "number" and amount > 0 then
        table.insert(entry.depositHistory, { amount = amount, timestamp = time() })
    end
end

resetTracker = function(reason, fingerprint, depositAmount)
    local entry = ensureDB()
    local timeSince = formatTimeSinceDeposit(entry.lastResetAt)

    if depositAmount then
        recordDeposit(entry, depositAmount)

        -- Send guild chat message
        if IsInGuild and IsInGuild() and SendChatMessage then
            local name = UnitName("player") or "Unknown"
            local msg = "[GTax] " .. name .. " deposited " .. formatMoney(depositAmount) .. "! Their previous deposit was " .. timeSince .. "."
            SendChatMessage(msg, "GUILD")
        end

        entry.lastResetAt = time()
    else
        entry.lastResetAt = 0
    end

    entry.earnedSinceDeposit = 0

    if fingerprint then
        entry.lastDepositFingerprint = fingerprint
    end

    updateWindow()
    printMessage("Tracker reset" .. (reason and (" (" .. reason .. ")") or "") .. ".")
end

local function isLikelyDeposit(txType, who, amount)
    if type(amount) ~= "number" or amount <= 0 then
        return false
    end

    if type(who) ~= "string" or who == "" then
        return false
    end

    local whoShort = Ambiguate(who, "short")
    if string.lower(whoShort or "") ~= playerNameLower then
        return false
    end

    local tx = string.lower(tostring(txType or ""))

    if tx:find("withdraw", 1, true) or tx:find("repair", 1, true) then
        return false
    end

    if tx == "" then
        return true
    end

    return tx:find("deposit", 1, true) ~= nil or tx == "money"
end

local function scanGuildBankMoneyLog()
    if type(GetNumGuildBankMoneyTransactions) ~= "function" then
        return
    end

    if type(GetGuildBankMoneyTransaction) ~= "function" then
        return
    end

    local entry = ensureDB()

    local num = GetNumGuildBankMoneyTransactions()
    if type(num) ~= "number" or num <= 0 then
        return
    end

    local newestDepositFingerprint = nil

    for i = 1, num do
        local txType, who, amount, whenText = GetGuildBankMoneyTransaction(i)
        if isLikelyDeposit(txType, who, amount) then
            local fingerprint = table.concat({
                tostring(txType),
                tostring(who),
                tostring(amount),
                tostring(whenText),
            }, "|")

            if not newestDepositFingerprint then
                newestDepositFingerprint = fingerprint
            end
            break
        end
    end

    if newestDepositFingerprint and newestDepositFingerprint ~= entry.lastDepositFingerprint then
        entry.lastDepositFingerprint = newestDepositFingerprint
        entry.earnedSinceDeposit = 0
        entry.lastResetAt = time()
        printMessage("Tracker reset (guild bank deposit detected).")
    end

    updateWindow()
end

local function onPlayerMoneyChanged()
    local entry = ensureDB()
    local current = GetMoney() or 0

    if type(entry.lastKnownMoney) ~= "number" then
        entry.lastKnownMoney = current
        return
    end

    local delta = current - entry.lastKnownMoney
    if delta > 0 then
        entry.earnedSinceDeposit = entry.earnedSinceDeposit + delta
    elseif delta < 0 then
        -- Only treat as a deposit if the guild bank is open and pendingDeposit is true
        if pendingDeposit and guildBankIsOpen then
            local depositAmount = math.abs(delta)
            pendingDeposit = false
            if pendingDepositTimer then
                pendingDepositTimer = nil
            end
            resetTracker("guild bank deposit detected", nil, depositAmount)
        end
        -- Otherwise, ignore the gold loss (could be flight path, buyback, etc)
    end

    entry.lastKnownMoney = current
    updateWindow()
end

local function handleSlash(msg)
    local command = string.lower(strtrim(msg or ""))
    print("[GTax DEBUG] handleSlash received command:", command)

    if command == "" or command == "window" or command == "toggle" then
        toggleWindow()
        return
    end

    if command == "options" or command == "config" or command == "settings" then
        toggleOptions()
        return
    end

    if command == "reset" or command == "deposit" then
        resetTracker("manual")
        return
    end

    if command == "purge" then
        local entry = ensureDB()
        entry.depositHistory = {}
        entry.importedFingerprints = {}
        updateWindow()
        printMessage("Deposit history purged.")
        return
    end

    if command == "audit" then
        if not (IsInGuild and IsInGuild() and SendChatMessage) then
            printMessage("You are not in a guild.")
            return
        end
        local entry = ensureDB()
        local today, week, total = getDepositSums(entry)
        local lastDeposit = formatTimeSinceDeposit(entry.lastResetAt)
        local name = UnitName("player") or "Unknown"
        local messages = {
            "[GTax] " .. name,
            "Last deposit: " .. lastDeposit,
            "Today: " .. formatMoney(today),
            "Week: " .. formatMoney(week),
            "Total: " .. formatMoney(total),
        }
        local function sendNext(i)
            if i > #messages then return end
            SendChatMessage(messages[i], "GUILD")
            if i < #messages then
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.2, function() sendNext(i+1) end)
                else
                    -- fallback: try to send immediately (may be out of order)
                    sendNext(i+1)
                end
            end
        end
        sendNext(1)
        return
    end

    if command == "help" then
        printMessage("Commands: /gtax (toggle window), /gtax options, /gtax reset, /gtax purge, /gtax audit, /gtax help")
        return
    end

    printMessage("Unknown command. Use /gtax help")
end

-- Minimap button
local minimapButton

local function updateMinimapButtonPosition()
    local entry = ensureDB()
    local angle = math.rad(entry.minimapAngle or 220)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function createMinimapButton()
    if minimapButton then return end

    local btn = CreateFrame("Button", "GTaxMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(54, 54)
    overlay:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            toggleOptions()
        else
            toggleWindow()
        end
    end)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Guild Tax")
        GameTooltip:AddLine("|cffffffffLeft-click|r to toggle window", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffffffRight-click|r to open options", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetMovable(true)
    btn:SetScript("OnDragStart", function(self)
        self.isDragging = true
    end)
    btn:SetScript("OnDragStop", function(self)
        self.isDragging = false
    end)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnUpdate", function(self)
        if not self.isDragging then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.atan2(cy - my, cx - mx)
        local entry = ensureDB()
        entry.minimapAngle = math.deg(angle)
        updateMinimapButtonPosition()
    end)

    minimapButton = btn
    updateMinimapButtonPosition()

    local entry = ensureDB()
    if entry.showMinimap == false then
        btn:Hide()
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        local entry = ensureDB()
        playerNameLower = string.lower(UnitName("player") or "")

        if type(entry.lastKnownMoney) ~= "number" then
            entry.lastKnownMoney = GetMoney() or 0
        end

        if DepositGuildBankMoney then
            hooksecurefunc("DepositGuildBankMoney", function()
                pendingDeposit = true
                -- Set a timer to clear pendingDeposit after 2 seconds if no deposit occurs
                if pendingDepositTimer and C_Timer and C_Timer.After and pendingDepositTimer.Cancel then
                    pendingDepositTimer:Cancel()
                end
                if C_Timer and C_Timer.After then
                    pendingDepositTimer = C_Timer.After(2, function()
                        pendingDeposit = false
                        pendingDepositTimer = nil
                    end)
                end
            end)
        end

        createWindow()
        createMinimapButton()
        ui.frame:Show()

        return
    end

    if event == "ADDON_LOADED" then
        local addon = select(1, ...)
        if addon == "Blizzard_GuildBankUI" and not ui.guildBankHooked then
            ui.guildBankHooked = true

            if GuildBankFrame then
                GuildBankFrame:HookScript("OnShow", function()
                    guildBankIsOpen = true
                    local moneyTab = (MAX_GUILDBANK_TABS or 6) + 1
                    if QueryGuildBankLog then
                        QueryGuildBankLog(moneyTab)
                    end
                    scanGuildBankMoneyLog()
                end)
                GuildBankFrame:HookScript("OnHide", function()
                    guildBankIsOpen = false
                end)
            end
        end
        return
    end

    if event == "PLAYER_MONEY" then
        onPlayerMoneyChanged()
        return
    end

    if event == "GUILDBANKFRAME_OPENED" then
        guildBankIsOpen = true
        local moneyTab = (MAX_GUILDBANK_TABS or 6) + 1
        if QueryGuildBankLog then
            QueryGuildBankLog(moneyTab)
        end
        scanGuildBankMoneyLog()
        return
    end

    if event == "GUILDBANKFRAME_CLOSED" then
        guildBankIsOpen = false
        if depositPrompt then depositPrompt:Hide() end
        return
    end

    if event == "GUILDBANK_UPDATE_MONEY" then
        local moneyTab = (MAX_GUILDBANK_TABS or 6) + 1
        if QueryGuildBankLog then
            QueryGuildBankLog(moneyTab)
        end
        scanGuildBankMoneyLog()
        return
    end

    if event == "GUILDBANKLOG_UPDATE" then
        scanGuildBankMoneyLog()
        return
    end
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("GUILDBANKFRAME_OPENED")
frame:RegisterEvent("GUILDBANKFRAME_CLOSED")
frame:RegisterEvent("GUILDBANKLOG_UPDATE")
frame:RegisterEvent("GUILDBANK_UPDATE_MONEY")

SLASH_GUILDBANKEARNINGS1 = "/gtax"
SLASH_GUILDBANKEARNINGS2 = "/gt"
SLASH_GUILDBANKEARNINGS3 = "/gbe"
SLASH_GUILDBANKEARNINGS4 = "/gbearn"
SlashCmdList.GUILDBANKEARNINGS = handleSlash
