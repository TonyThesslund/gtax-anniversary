-- Saved variable helpers, defaults, AceDB bootstrap

local _, GTax = ...
GTax = GTax or {}

GTax.defaults = {
    char = {
        earnedSinceDeposit = 0,
        earningsHistory = {},
        lastKnownMoney = nil,
        lastResetAt = 0,
        depositHistory = {},
        unpaidLoans = 0,
        leaderboardCache = {},
        taxPercent = 3,
        minimapAngle = 220,
        showMinimap = true,
        showWindow = true,
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
    },
}

-- Compatibility aliases for existing modules still reading top-level defaults.
GTax.defaults.show = GTax.defaults.char.show

local function copyMissing(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                copyMissing(dst[k], v)
            else
                dst[k] = v
            end
        elseif type(dst[k]) == "table" and type(v) == "table" then
            copyMissing(dst[k], v)
        end
    end
end

function GTax.initDB()
    if GTax.db then return GTax.db.char end

    local characterKey = GTax.getCharacterKey()
    local legacyCurrent
    if type(GTaxDB) == "table" and type(GTaxDB.characters) == "table" then
        legacyCurrent = GTaxDB.characters[characterKey]
        -- Reset legacy layout before AceDB initializes schema.
        GTaxDB = {}
    end

    local aceDB = LibStub("AceDB-3.0", true)
    if not aceDB then
        GTax.printMessage("AceDB-3.0 missing; database unavailable.")
        GTax.db = { char = {} }
        return GTax.db.char
    end

    GTax.db = aceDB:New("GTaxDB", GTax.defaults, true)
    local entry = GTax.db.char

    if type(legacyCurrent) == "table" then
        copyMissing(entry, legacyCurrent)
    end

    if type(entry.show) ~= "table" then entry.show = {} end
    copyMissing(entry.show, GTax.defaults.char.show)

    return entry
end

function GTax.ensureDB()
    if not GTax.db then
        return GTax.initDB()
    end
    return GTax.db.char
end
