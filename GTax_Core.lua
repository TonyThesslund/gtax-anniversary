-- GTax_Core.lua
-- Core addon table, print helpers, money formatting, character key

local addonName, GTax = ...
GTax = GTax or {}

GTax.addonPrefix = "|cff5fd7ffGTax|r"

function GTax.printMessage(text)
    print(string.format("%s %s", GTax.addonPrefix, text))
end

function GTax.formatMoney(money)
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    return string.format("%dg %ds %dc", gold, silver, copper)
end

function GTax.getCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return realm .. "-" .. name
end

_G.GTax = GTax -- expose for other files
