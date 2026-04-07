-- Core addon object, print helpers, money formatting, character key

local addonName = ...
local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
if not AceAddon then
    local fallback = _G.GTax or {}
    fallback.addonPrefix = "|cff5fd7ffGTax|r"
    _G.GTax = fallback

    local loadedErrorFrame = CreateFrame("Frame")
    loadedErrorFrame:RegisterEvent("PLAYER_LOGIN")
    loadedErrorFrame:SetScript("OnEvent", function()
        print("|cff5fd7ffGTax|r Ace3 dependency missing. Install/enable Ace3.")
    end)

    return
end

local GTax = AceAddon:NewAddon(addonName, "AceEvent-3.0", "AceComm-3.0")

GTax.addonPrefix = "|cff5fd7ffGTax|r"
GTax.commPrefix = "GTax"

function GTax.printMessage(text)
    print(string.format("%s %s", GTax.addonPrefix, text))
end

function GTax.sendCommPayload(payload, channel, target)
    if type(payload) ~= "table" then return false end
    if channel == "GUILD" and not (IsInGuild and IsInGuild()) then return false end

    local serializer = LibStub("AceSerializer-3.0", true)
    if not serializer then return false end

    local message = serializer:Serialize(payload)
    GTax:SendCommMessage(GTax.commPrefix, message, channel or "GUILD", target)
    return true
end

function GTax.sendGuildLine(text)
    if type(text) ~= "string" or text == "" then return false end
    return GTax.sendCommPayload({ kind = "CHAT", text = text }, "GUILD")
end

function GTax.formatMoney(money)
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
    local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
    local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
    return string.format("%d%s %d%s %d%s", gold, goldIcon, silver, silverIcon, copper, copperIcon)
end

function GTax.getCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return realm .. "-" .. name
end

_G.GTax = GTax
