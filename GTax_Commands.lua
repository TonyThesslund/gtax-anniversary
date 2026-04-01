-- GTax_Commands.lua
-- Slash command registration and handler

local addonName, GTax = ...
GTax = GTax or {}

local function handleSlash(msg)
    local command = string.lower(strtrim(msg or ""))
    if command == "" or command == "window" or command == "toggle" then
        if GTax.UI and GTax.UI.ToggleWindow then GTax.UI.ToggleWindow() end
        return
    end
    if command == "options" or command == "config" or command == "settings" then
        if GTax.UI and GTax.UI.ToggleOptions then GTax.UI.ToggleOptions() end
        return
    end
    if command == "reset" or command == "deposit" then
        GTax.resetTracker("manual")
        return
    end
    if command == "purge" then
        local entry = GTax.ensureDB()
        entry.depositHistory = {}
        if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
        GTax.printMessage("Contribution history purged.")
        return
    end
    if command == "audit" then
        if not (IsInGuild and IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage) then
            GTax.printMessage("You are not in a guild.")
            return
        end
        local entry = GTax.ensureDB()
        local today, week, total = GTax.getDepositSums(entry)
        local lastDeposit = GTax.formatTimeSinceDeposit(entry.lastResetAt)
        local name = UnitName("player") or "Unknown"
        -- Color the last deposit line
        local r, g, b = GTax.getDepositColor(entry.lastResetAt)
        local hex = string.format("%02x%02x%02x", math.floor(r*255), math.floor(g*255), math.floor(b*255))
        local lastDepositColored = "|cff" .. hex .. "Last Contribution: " .. lastDeposit .. "|r"
        local indent = string.rep(" ", 11)
        local messages = {
            "|cff5fd7ff[GTax]|r Contribution audit for " .. name,
            indent .. lastDepositColored,
            indent .. "Contributed today: " .. GTax.formatMoney(today),
            indent .. "Contributed this week: " .. GTax.formatMoney(week),
            indent .. "Contributed total: " .. GTax.formatMoney(total),
        }
        local function sendNext(i)
            if i > #messages then return end
            C_ChatInfo.SendAddonMessage("GTax", messages[i], "GUILD")
            if i < #messages then
                sendNext(i+1)
            end
        end
        sendNext(1)
        return
    end
    if command == "help" then
        GTax.printMessage("Commands: /gtax, /gtax options, /gtax reset, /gtax purge, /gtax audit, /gtax help")
        return
    end
    GTax.printMessage("Unknown command. Use /gtax help.")
end

SLASH_GUILDBANKEARNINGS1 = "/gtax"
SLASH_GUILDBANKEARNINGS2 = "/gt"
SLASH_GUILDBANKEARNINGS3 = "/gbe"
SLASH_GUILDBANKEARNINGS4 = "/gbearn"
SlashCmdList.GUILDBANKEARNINGS = handleSlash
