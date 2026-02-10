-- Account Played Minimap Button
-- Hybrid snap/free-form positioning system:
--   - Snaps to minimap edge when close (works with round minimap)
--   - Breaks free for arbitrary positioning (works with square minimap / ElvUI)
--   - Saves x,y offset relative to Minimap center between sessions

-- Addon namespace
AccountPlayed = AccountPlayed or {}
local AP = AccountPlayed

local BUTTON_NAME = "AccountPlayed_MinimapButton"

-- Localization (Define the table with your localized strings)
local L = {
    TOOLTIP_TITLE = "Account Played",
    TOOLTIP_CLICK = "Left Click: Toggle window",
    TOOLTIP_DRAG = "Drag: Move icon",
    TOOLTIP_LOCK = "Right Click: Lock/Unlock position",
    TOOLTIP_LOCKED = "|cffff0000[LOCKED]|r",
    TOOLTIP_UNLOCKED = "|cff00ff00[UNLOCKED]|r",
}

-- Migrate from old angle-only format or initialize defaults.
local function InitDB()
    if not AccountPlayedMinimapDB then
        AccountPlayedMinimapDB = {}
    end

    -- Migrate: if old angle-based data exists, convert to x,y
    if AccountPlayedMinimapDB.angle and not AccountPlayedMinimapDB.x then
        local angle = math.rad(AccountPlayedMinimapDB.angle)
        local radius = 105
        AccountPlayedMinimapDB.x = math.cos(angle) * radius
        AccountPlayedMinimapDB.y = math.sin(angle) * radius
        AccountPlayedMinimapDB.angle = nil
    end

    -- Default position: bottom-left of minimap (equivalent to old 225 degrees)
    if not AccountPlayedMinimapDB.x then
        local angle = math.rad(225)
        local radius = 105
        AccountPlayedMinimapDB.x = math.cos(angle) * radius
        AccountPlayedMinimapDB.y = math.sin(angle) * radius
    end
    
    -- Default locked state
    if AccountPlayedMinimapDB.locked == nil then
        AccountPlayedMinimapDB.locked = false
    end
end

-- Positioning
local function UpdateButtonPosition(button)
    local x = AccountPlayedMinimapDB.x or 0
    local y = AccountPlayedMinimapDB.y or 0
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    -- print("Button Position Updated: x = " .. x .. ", y = " .. y)  -- Debugging line
end

-- Save the button's current position as an offset from Minimap center
local function SaveButtonPosition(button)
    local bx, by = button:GetCenter()
    local mx, my = Minimap:GetCenter()
    if bx and mx then
        AccountPlayedMinimapDB.x = bx - mx
        AccountPlayedMinimapDB.y = by - my
    end
end

-- Drag position update 
local function UpdateDragPosition(self)
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    local angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    AccountPlayedMinimapDB.angle = angle
    UpdateButtonPosition(self)
end

-- Fade animation helper
local function FadeButton(btn, targetAlpha, duration)
    local startAlpha = btn:GetAlpha()
    local elapsed = 0
    duration = duration or 0.15
    
    btn.fadeFrame = btn.fadeFrame or CreateFrame("Frame")
    btn.fadeFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local progress = math.min(1, elapsed / duration)
        btn:SetAlpha(startAlpha + (targetAlpha - startAlpha) * progress)
        
        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Creation of the Minimap button
local function CreateMinimapButton()
    -- Don't create if hidden
    if AccountPlayedMinimapDB.hide then
        return
    end

    -- Update position if already exists
    if _G[BUTTON_NAME] then
        UpdateButtonPosition(_G[BUTTON_NAME])
        return
    end

    local btn = CreateFrame("Button", BUTTON_NAME, Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetClampedToScreen(true)
    btn:SetAlpha(0.01)  -- Start faded out

    -- Debugging line to check if the button is created
    --print("Button Created")

    -- Tooltip and Click Handlers
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.TOOLTIP_TITLE, 0.4, 0.78, 1)  -- Light blue title
        GameTooltip:AddLine(" ")  -- Spacer
        GameTooltip:AddDoubleLine("|cffffffffLeft Click:|r", "|cff00ff00Toggle window|r")
        if not AccountPlayedMinimapDB.locked then
            GameTooltip:AddDoubleLine("|cffffffffDrag:|r", "|cffffff00Move icon|r")
        end
        GameTooltip:AddDoubleLine("|cffffffffRight Click:|r", "|cffff8800Lock/Unlock position|r")
        GameTooltip:AddLine(" ")  -- Spacer
        GameTooltip:AddLine(AccountPlayedMinimapDB.locked and L.TOOLTIP_LOCKED or L.TOOLTIP_UNLOCKED, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            SlashCmdList.ACCOUNTPLAYEDPOPUP()
        elseif button == "RightButton" then
            AccountPlayedMinimapDB.locked = not AccountPlayedMinimapDB.locked
            PlaySound(AccountPlayedMinimapDB.locked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            print("|cff00ff00Account Played:|r Minimap button " .. (AccountPlayedMinimapDB.locked and "|cffff0000LOCKED|r" or "|cff00ff00UNLOCKED|r"))
            
            -- Update tooltip if it's showing
            if GameTooltip:GetOwner() == self then
                self:GetScript("OnEnter")(self)
            end
        end
    end)

    -- Track minimap mouse state for fade in/out (only when snapped)
    local minimapHoverFrame = CreateFrame("Frame")
    minimapHoverFrame.checkInterval = 0.2  -- Check every 0.1 seconds instead of every frame
    minimapHoverFrame.elapsed = 0
    minimapHoverFrame.lastMouseOver = false
    
    minimapHoverFrame:SetScript("OnUpdate", function(self, elapsed)
        if btn.isDragging then return end  -- Don't fade while dragging
        
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < self.checkInterval then
            return
        end
        self.elapsed = 0
        
        -- Only auto-hide if button is snapped to minimap
        if btn.snapped then
            local isMouseOver = Minimap:IsMouseOver(60, -60, -60, 60)
            
            -- Only fade if mouse state changed
            if isMouseOver ~= self.lastMouseOver then
                self.lastMouseOver = isMouseOver
                if isMouseOver then
                    FadeButton(btn, 1, 0.15)
                else
                    FadeButton(btn, 0.01, 0.15)
                end
            end
        else
            -- When not snapped, always show at full opacity (only if needed)
            if btn:GetAlpha() < 0.99 then
                FadeButton(btn, 1, 0.15)
                self.lastMouseOver = true
            end
        end
    end)

    -- Border (OVERLAY, positioned first)
    btn.border = btn:CreateTexture(nil, "OVERLAY")
    btn.border:SetSize(53, 53)
    btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.border:SetPoint("TOPLEFT")

    -- Icon (ARTWORK layer, smaller size)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(17, 17)
    btn.icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")  
    btn.icon:SetPoint("CENTER")
    btn.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    -- Check if the texture is loaded correctly
    -- if not btn.icon:GetTexture() then
    --     print("Error: Icon texture not loaded!")
    -- else
    --     print("Icon texture loaded successfully.")
    -- end

    -- Highlight
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    -- Drag handlers
    btn:SetScript("OnDragStart", function(self)
        if AccountPlayedMinimapDB.locked then
            print("|cff00ff00Account Played:|r Button is locked. Right-click to unlock.")
            return
        end
        
        self.isDragging = true
        self:SetScript("OnUpdate", function(self)
            local minimap = Minimap
            local mx, my = minimap:GetCenter()
            local scale = minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            local dx, dy = cx - mx, cy - my
            local dist = (dx * dx + dy * dy) ^ 0.5

            -- Define the RADIUS_ADJUST constant here
            local RADIUS_ADJUST = -5  -- Adjust the snap zone radius (negative makes it tighter)

            -- Determine snap behavior
            local edgeRadius = (minimap:GetWidth() + self:GetWidth()) / 2
            local radSnap = edgeRadius + RADIUS_ADJUST
            local radPull = edgeRadius + self:GetWidth() * 0.2
            local radFree = edgeRadius + self:GetWidth() * 0.7
            local radClamp

            -- Snapping logic
            if dist <= radSnap then
                self.snapped = true
                radClamp = radSnap
            elseif dist < radPull and self.snapped then
                radClamp = radSnap
            elseif dist < radFree and self.snapped then
                radClamp = radSnap + (dist - radPull) / 2
            else
                self.snapped = false
            end

            -- Apply final position
            if radClamp and dist > 0 then
                local factor = radClamp / dist
                dx = dx * factor
                dy = dy * factor
            end

            AccountPlayedMinimapDB.x = dx
            AccountPlayedMinimapDB.y = dy
            self:ClearAllPoints()
            self:SetPoint("CENTER", minimap, "CENTER", dx, dy)
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    -- Determine initial snap state
    local edgeRadius = (Minimap:GetWidth() + btn:GetWidth()) / 2
    local savedDist = (AccountPlayedMinimapDB.x ^ 2 + AccountPlayedMinimapDB.y ^ 2) ^ 0.5
    btn.snapped = (savedDist <= edgeRadius + btn:GetWidth() * 0.3)

    UpdateButtonPosition(btn)
end

-- Slash command to reset button position
SLASH_ACCOUNTPLAYEDRESETMAP1 = "/apresetmap"
SlashCmdList.ACCOUNTPLAYEDRESETMAP = function()
    -- Reset to default position (bottom-left, 225 degrees)
    local angle = math.rad(225)
    local radius = 105
    AccountPlayedMinimapDB.x = math.cos(angle) * radius
    AccountPlayedMinimapDB.y = math.sin(angle) * radius
    
    -- Update button if it exists
    local btn = _G[BUTTON_NAME]
    if btn then
        btn.snapped = true  -- Reset snap state
        UpdateButtonPosition(btn)
        FadeButton(btn, 1, 0.15)  -- Make it visible
        print("|cff00ff00Account Played:|r Minimap button position reset to default.")
    else
        print("|cff00ff00Account Played:|r Minimap button will appear at default position on next login.")
    end
end

-- Init
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    InitDB()
    CreateMinimapButton()
end)
