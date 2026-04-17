-- GTax_Runtime_AddonComm.lua
-- Addon prefix registration and addon-channel message handling

local addonName, GTax = ...
GTax = GTax or {}

function GTax.RegisterAddonPrefix()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix("GTax")
    end
end

local prefixFrame = CreateFrame("Frame")
prefixFrame:RegisterEvent("ADDON_LOADED")
prefixFrame:SetScript("OnEvent", function(_, _, addon)
    if addon == "GTax" then
        GTax.RegisterAddonPrefix()
    end
end)

local addonMessageFrame = CreateFrame("Frame")
addonMessageFrame:RegisterEvent("CHAT_MSG_ADDON")
addonMessageFrame:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix == "GTax" and channel == "GUILD" then
        if GTax.handleSyncMessage and GTax.handleSyncMessage(message, sender) then
            return
        end
        print(message)
    end
end)
