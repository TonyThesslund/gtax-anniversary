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
        entry.importedFingerprints = {}
        if GTax.UI and GTax.UI.UpdateWindow then GTax.UI.UpdateWindow() end
        GTax.printMessage("Deposit history purged.")
        return
    end
    if command == "audit" then
        if not (IsInGuild and IsInGuild() and SendChatMessage) then
            GTax.printMessage("You are not in a guild.")
            return
        end
        local entry = GTax.ensureDB()
        local today, week, total = GTax.getDepositSums(entry)
        local lastDeposit = GTax.formatTimeSinceDeposit(entry.lastResetAt)
        local name = UnitName("player") or "Unknown"
        local function fmt(money)
            if type(money) ~= "number" or not money or money < 0 then money = 0 end
            money = math.floor(money)
            local g = math.floor(money / (100 * 100))
            local s = math.floor((money / 100) % 100)
            local c = money % 100
            local parts = {}
            local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
            local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
            local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
            if g > 0 then table.insert(parts, g .. goldIcon) end
            if s > 0 or g > 0 then table.insert(parts, s .. silverIcon) end
            table.insert(parts, c .. copperIcon)
            return table.concat(parts, " ")
        end
        -- Color the last deposit line
        local r, g, b = GTax.getDepositColor(entry.lastResetAt)
        local hex = string.format("%02x%02x%02x", math.floor(r*255), math.floor(g*255), math.floor(b*255))
        local lastDepositColored = "|cff" .. hex .. "Last Contribution: " .. lastDeposit .. "|r"
        local indent = string.rep(" ", 11)
        local messages = {
            "|cff5fd7ff[GTax]|r Audit for " .. name,
            indent .. lastDepositColored,
            indent .. "Contributed today: " .. fmt(today),
            indent .. "Contributed this week: " .. fmt(week),
            indent .. "Contributed total: " .. fmt(total),
        }
        local function sendNext(i)
            if i > #messages then return end
            if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                C_ChatInfo.SendAddonMessage("GTax", messages[i], "GUILD")
            end
            if i < #messages then
                sendNext(i+1)
            end
        end
        sendNext(1)
        return
    end
    if command == "help" then
        GTax.printMessage("Commands: /gtax (toggle window), /gtax options, /gtax reset, /gtax purge, /gtax audit, /gtax help")
        return
    end
    GTax.printMessage("Unknown command. Use /gtax help")
end

SLASH_GUILDBANKEARNINGS1 = "/gtax"
SLASH_GUILDBANKEARNINGS2 = "/gt"
SLASH_GUILDBANKEARNINGS3 = "/gbe"
SLASH_GUILDBANKEARNINGS4 = "/gbearn"
SlashCmdList.GUILDBANKEARNINGS = handleSlash
