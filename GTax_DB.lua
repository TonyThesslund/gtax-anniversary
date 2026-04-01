-- GTax_DB.lua
-- Saved variable helpers, defaults, ensureDB

local addonName, GTax = ...
GTax = GTax or {}

GTax.defaults = {
    earnedSinceDeposit = 0,
    earningsHistory = {},
    lastKnownMoney = nil,
    lastResetAt = 0,
    lastDepositFingerprint = nil,
    lastWithdrawalFingerprint = nil,
    depositHistory = {},
    unpaidLoans = 0,
    leaderboardCache = {}, -- Persisted guild leaderboard data from other players
    taxPercent = 3,
    minimapAngle = 220,
    showMinimap = true,
    showWindow = true, -- Track if main window should be visible (default: visible)
    show = {
        earned = true,
        earnedToday = false,
        earnedWeek = false,
        lastDeposit = true,
        suggestedSinceLast = true,
        depositToday = true,
        depositWeek = false,
        depositTotal = false,
    },
}

function GTax.ensureDB()
    if type(GTaxDB) ~= "table" then
        GTaxDB = {}
    end
    if type(GTaxDB.characters) ~= "table" then
        GTaxDB.characters = {}
    end
    local characterKey = GTax.getCharacterKey()
    if type(GTaxDB.characters[characterKey]) ~= "table" then
        GTaxDB.characters[characterKey] = {}
    end
    local entry = GTaxDB.characters[characterKey]
    for k, v in pairs(GTax.defaults) do
        if entry[k] == nil then
            -- Always assign a fresh table copy to avoid aliasing the shared defaults reference
            if type(v) == "table" then
                entry[k] = {}
            else
                entry[k] = v
            end
        end
    end
    -- Ensure all show options are present and correct
    if type(entry.show) ~= "table" then
        entry.show = {}
    end
    for k, v in pairs(GTax.defaults.show) do
        if entry.show[k] == nil then
            entry.show[k] = v
        end
    end
    return entry
end
