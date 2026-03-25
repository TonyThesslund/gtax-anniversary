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
        local messages = {
            "[GTax] " .. name,
            "Last deposit: " .. lastDeposit,
            "Today: " .. GTax.formatMoney(today),
            "Week: " .. GTax.formatMoney(week),
            "Total: " .. GTax.formatMoney(total),
        }
        local function sendNext(i)
            if i > #messages then return end
            SendChatMessage(messages[i], "GUILD")
            if i < #messages then
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.2, function() sendNext(i+1) end)
                else
                    sendNext(i+1)
                end
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
