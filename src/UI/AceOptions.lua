-- AceConfig/AceGUI options and leaderboard UI

local _, GTax = ...
GTax = GTax or {}
GTax.UI = GTax.UI or {}

local AceConfig = LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceGUI = LibStub("AceGUI-3.0", true)

if not (AceConfig and AceConfigDialog) then
    function GTax.UI.ToggleOptions()
        GTax.printMessage("AceConfig not available. Please enable Ace3.")
    end
    return
end

local function getEntry()
    return GTax.ensureDB()
end

local function updateWindows()
    if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
    if GTax.UI and GTax.UI.UpdateLeaderboard then GTax.UI.UpdateLeaderboard() end
end

local function buildLeaderboardLine(record)
    return string.format(
        "%-18s %-18s %-18s %-18s %s",
        record.player or "Unknown",
        GTax.formatMoney(record.total or 0),
        GTax.formatMoney(record.today or 0),
        GTax.formatMoney(record.week or 0),
        GTax.formatMoney(record.unpaidLoans or 0)
    )
end

local function renderLeaderboardRows(container)
    if not (AceGUI and container) then return end
    container:ReleaseChildren()

    local header = AceGUI:Create("Label")
    header:SetText("Player             Total              Today              Week               Loans")
    header:SetFullWidth(true)
    container:AddChild(header)

    local entries = {}
    if GTax.getLeaderboardEntries then
        entries = GTax.getLeaderboardEntries()
    end

    for _, record in ipairs(entries) do
        local line = AceGUI:Create("Label")
        line:SetFullWidth(true)
        line:SetText(buildLeaderboardLine(record))
        container:AddChild(line)
    end
end

function GTax.UI.UpdateLeaderboard()
    if GTax.UI and GTax.UI.aceLeaderboardScroll then
        renderLeaderboardRows(GTax.UI.aceLeaderboardScroll)
    end
end

function GTax.UI.ShowAceLeaderboard()
    if not AceGUI then
        GTax.printMessage("AceGUI not available. Please enable Ace3.")
        return
    end

    if GTax.UI.aceLeaderboardFrame then
        GTax.UI.aceLeaderboardFrame:Show()
        GTax.UI.aceLeaderboardFrame.frame:Raise()
        GTax.UI.UpdateLeaderboard()
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("GTax - Guild Leaderboard")
    frame:SetStatusText("Live guild sync data")
    frame:SetLayout("Fill")
    frame:SetWidth(520)
    frame:SetHeight(420)
    frame:SetCallback("OnClose", function(widget)
        GTax.UI.aceLeaderboardFrame = nil
        GTax.UI.aceLeaderboardScroll = nil
        AceGUI:Release(widget)
    end)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    frame:AddChild(scroll)

    GTax.UI.aceLeaderboardFrame = frame
    GTax.UI.aceLeaderboardScroll = scroll
    GTax.UI.UpdateLeaderboard()
end

local options = {
    type = "group",
    name = "GTax",
    args = {
        description = {
            type = "description",
            name = "Guild tax tracking settings (AceConfig)",
            order = 1,
        },
        taxPercent = {
            type = "range",
            name = "Tax Percent",
            min = 1,
            max = 20,
            step = 1,
            order = 10,
            get = function()
                return getEntry().taxPercent or 3
            end,
            set = function(_, value)
                getEntry().taxPercent = math.floor(value + 0.5)
                updateWindows()
            end,
        },
        showWindow = {
            type = "toggle",
            name = "Show tracker window",
            order = 11,
            get = function() return getEntry().showWindow ~= false end,
            set = function(_, value)
                local entry = getEntry()
                entry.showWindow = value and true or false
                if GTax.UI and GTax.UI.frame then
                    if value then GTax.UI.frame:Show() else GTax.UI.frame:Hide() end
                end
                updateWindows()
            end,
        },
        showMinimap = {
            type = "toggle",
            name = "Show minimap button",
            order = 12,
            get = function() return getEntry().showMinimap ~= false end,
            set = function(_, value)
                local entry = getEntry()
                entry.showMinimap = value and true or false
                if GTax.MinimapButton and GTax.MinimapButton.SetVisible then
                    GTax.MinimapButton.SetVisible(value)
                end
            end,
        },
        earned = {
            type = "toggle",
            name = "Show earned since last contribution",
            order = 20,
            get = function() return getEntry().show.earned ~= false end,
            set = function(_, value)
                getEntry().show.earned = value and true or false
                updateWindows()
            end,
        },
        earnedToday = {
            type = "toggle",
            name = "Show earned today",
            order = 21,
            get = function() return getEntry().show.earnedToday == true end,
            set = function(_, value)
                getEntry().show.earnedToday = value and true or false
                updateWindows()
            end,
        },
        earnedWeek = {
            type = "toggle",
            name = "Show earned this week",
            order = 22,
            get = function() return getEntry().show.earnedWeek == true end,
            set = function(_, value)
                getEntry().show.earnedWeek = value and true or false
                updateWindows()
            end,
        },
        lastDeposit = {
            type = "toggle",
            name = "Show last contribution age",
            order = 23,
            get = function() return getEntry().show.lastDeposit ~= false end,
            set = function(_, value)
                getEntry().show.lastDeposit = value and true or false
                updateWindows()
            end,
        },
        depositToday = {
            type = "toggle",
            name = "Show contributed today",
            order = 30,
            get = function() return getEntry().show.depositToday ~= false end,
            set = function(_, value)
                getEntry().show.depositToday = value and true or false
                updateWindows()
            end,
        },
        depositWeek = {
            type = "toggle",
            name = "Show contributed this week",
            order = 31,
            get = function() return getEntry().show.depositWeek ~= false end,
            set = function(_, value)
                getEntry().show.depositWeek = value and true or false
                updateWindows()
            end,
        },
        depositTotal = {
            type = "toggle",
            name = "Show contributed total",
            order = 32,
            get = function() return getEntry().show.depositTotal ~= false end,
            set = function(_, value)
                getEntry().show.depositTotal = value and true or false
                updateWindows()
            end,
        },
        suggestedSinceLast = {
            type = "toggle",
            name = "Show suggested contribution",
            order = 40,
            get = function() return getEntry().show.suggestedSinceLast ~= false end,
            set = function(_, value)
                getEntry().show.suggestedSinceLast = value and true or false
                updateWindows()
            end,
        },
        openLeaderboard = {
            type = "execute",
            name = "Open AceGUI Leaderboard",
            order = 100,
            func = function()
                GTax.UI.ShowAceLeaderboard()
            end,
        },
    },
}

AceConfig:RegisterOptionsTable("GTax", options)
AceConfigDialog:AddToBlizOptions("GTax", "GTax")

function GTax.UI.ToggleOptions()
    AceConfigDialog:Open("GTax")
end
