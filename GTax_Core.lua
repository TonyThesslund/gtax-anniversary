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
    local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
    local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
    local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
    local str = ""
    if gold > 0 then
        str = str .. gold .. goldIcon .. " "
    end
    if silver > 0 or (gold > 0 and copper > 0) then
        str = str .. silver .. silverIcon .. " "
    end
    str = str .. copper .. copperIcon
    return str
end

function GTax.getCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return realm .. "-" .. name
end

_G.GTax = GTax -- expose for other files
