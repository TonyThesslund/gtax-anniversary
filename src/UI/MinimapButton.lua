-- GTax_MinimapButton.lua
-- Minimap button creation, drag, angle

local addonName, GTax = ...
GTax = GTax or {}

GTax.MinimapButton = GTax.MinimapButton or {}

function GTax.MinimapButton.SetVisible(visible)
    local entry = GTax.ensureDB()
    entry.showMinimap = visible and true or false
    if GTax.MinimapButton.button then
        if entry.showMinimap then
            GTax.MinimapButton.button:Show()
            GTax.MinimapButton.UpdatePosition()
        else
            GTax.MinimapButton.button:Hide()
        end
    end
end

function GTax.MinimapButton.UpdatePosition()
    local entry = GTax.ensureDB()
    local angle = math.rad(entry.minimapAngle or 220)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    if GTax.MinimapButton.button then
        GTax.MinimapButton.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
end

function GTax.MinimapButton.Create()
    if GTax.MinimapButton.button then return end
    local btn = CreateFrame("Button", "GTaxMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(54, 54)
    overlay:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if GTax.UI and GTax.UI.ToggleOptions then GTax.UI.ToggleOptions() end
        else
            if GTax.UI and GTax.UI.ToggleWindow then GTax.UI.ToggleWindow() end
        end
    end)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Guild Tax Tracker")
        GameTooltip:AddLine("|cffffffffLeft-click|r to toggle the tracker window", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffffffRight-click|r to open options", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetMovable(true)
    btn:SetScript("OnDragStart", function(self) self.isDragging = true end)
    btn:SetScript("OnDragStop", function(self) self.isDragging = false end)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnUpdate", function(self)
        if not self.isDragging then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.atan2(cy - my, cx - mx)
        local entry = GTax.ensureDB()
        entry.minimapAngle = math.deg(angle)
        GTax.MinimapButton.UpdatePosition()
    end)
    GTax.MinimapButton.button = btn
    GTax.MinimapButton.UpdatePosition()
    local entry = GTax.ensureDB()
    GTax.MinimapButton.SetVisible(entry.showMinimap ~= false)
end
