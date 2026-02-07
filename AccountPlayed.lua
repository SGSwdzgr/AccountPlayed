--------------------------------------------------
-- Account Played - Main Module
--------------------------------------------------

-- Addon namespace
AccountPlayed = AccountPlayed or {}
local AP = AccountPlayed

-- SavedVariables (must NOT be local)
AccountPlayedDB = AccountPlayedDB or {}
AccountPlayedPopupDB = AccountPlayedPopupDB or {
    width = 520,
    height = 300,
    point = "CENTER",
    x = 0,
    y = 0,
    useYears = false,
}

local ADDON_NAME = "Account Played"

-- Localization table
local L = {
    ADDON_NAME = "Account Played",
    WINDOW_TITLE = "Account Played - Time by Class",
    NO_DATA = "No data yet",
    TOTAL = "TOTAL: ",
    DEBUG_HEADER = "[AccountPlayed Debug] Known characters:",
}

-- Throttle tracking for RequestTimePlayed
local lastPlayedRequest = 0

-- Frame references
AP.mainFrame = CreateFrame("Frame")
AP.popupFrame = nil
AP.popupRows = {}

-- API Version
AccountPlayed.API_VERSION = 1

--------------------------------------------------
-- Validation
--------------------------------------------------

-- Ensure SavedVariables is valid table
if type(AccountPlayedDB) ~= "table" then
    print("|cffff0000Account Played: SavedVariables corrupted, resetting!|r")
    AccountPlayedDB = {}
end

--------------------------------------------------
-- Data Migration
--------------------------------------------------

-- Migrate old number-only format to new table format
local function MigrateOldData()
    for charKey, data in pairs(AccountPlayedDB) do
        if type(data) == "number" then
            AccountPlayedDB[charKey] = {
                time = data,
                class = "UNKNOWN"
            }
        end
    end
end

--------------------------------------------------
-- Helpers
--------------------------------------------------

local function GetCharInfo()
    local name = UnitName("player")
    -- GetNormalizedRealmName doesn't exist in Classic, fallback to GetRealmName
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    return realm, name
end

local function GetCharKey(realm, name)
    return realm .. "-" .. name
end

local function FormatTime(seconds)
    seconds = tonumber(seconds) or 0
    local hours = math.floor(seconds / 3600)
    local days = math.floor(hours / 24)
    local remHours = hours % 24
    return string.format("%dd %dh", days, remHours)
end

local function FormatTimeSmart(seconds, useYears)
    seconds = tonumber(seconds) or 0
    local hours = seconds / 3600

    if useYears then
        local days = math.floor(hours / 24)
        local years = math.floor(days / 365)
        local remDays = days % 365

        if years > 0 then
            return string.format("%dy %dd", years, remDays)
        else
            return string.format("%dd", remDays)
        end
    else
        -- Round up to nearest hour for cleaner display
        local h = math.ceil(hours)
        return string.format("%dh", h)
    end
end

local function GetAccountTotal()
    local total = 0
    for _, data in pairs(AccountPlayedDB) do
        if type(data) == "table" and data.time then
            total = total + data.time
        end
    end
    return total
end

local function GetClassTotals()
    local totals = {}
    local accountTotal = 0

    for _, data in pairs(AccountPlayedDB) do
        if type(data) == "table" and data.time and data.class then
            totals[data.class] = (totals[data.class] or 0) + data.time
            accountTotal = accountTotal + data.time
        end
    end

    return totals, accountTotal
end

-- Get all characters for a specific class
local function GetCharactersByClass(className)
    local chars = {}
    for charKey, data in pairs(AccountPlayedDB) do
        if type(data) == "table" and data.class == className and data.time then
            table.insert(chars, {
                key = charKey,
                time = data.time,
                class = data.class
            })
        end
    end
    -- Sort by playtime descending
    table.sort(chars, function(a, b) return a.time > b.time end)
    return chars
end

-- Safe request with throttle protection
local function SafeRequestTimePlayed()
    local now = GetTime()
    if now - lastPlayedRequest >= 10 then
        RequestTimePlayed()
        lastPlayedRequest = now
        return true
    end
    return false
end

--------------------------------------------------
-- Public API for Other Addons
--------------------------------------------------

--[[
    Get playtime for a specific character
    
    @param realm string - Realm name (normalized)
    @param name string - Character name
    @return time number - Seconds played (or nil if not found)
    @return class string - Class file name (or nil if not found)
    
    Example:
        local time, class = AccountPlayed:GetCharacterTime("MyRealm", "MyChar")
        if time then
            print(string.format("%s has played for %d hours", "MyChar", time/3600))
        end
]]
function AccountPlayed:GetCharacterTime(realm, name)
    local charKey = realm .. "-" .. name
    local data = AccountPlayedDB[charKey]
    
    if data and type(data) == "table" and data.time then
        return data.time, data.class
    end
    return nil
end

--[[
    Get total playtime across all characters on account
    
    @return total number - Total seconds played across all characters
    
    Example:
        local total = AccountPlayed:GetAccountTotal()
        print(string.format("Account total: %.1f days", total/86400))
]]
function AccountPlayed:GetAccountTotal()
    return GetAccountTotal()
end

--[[
    Get total playtime by class
    
    @return totals table - Table mapping class names to seconds played
    @return accountTotal number - Total seconds across all classes
    
    Example:
        local classTotals, total = AccountPlayed:GetClassTotals()
        for class, time in pairs(classTotals) do
            print(string.format("%s: %.1f hours", class, time/3600))
        end
]]
function AccountPlayed:GetClassTotals()
    return GetClassTotals()
end

--[[
    Get a copy of all character data
    Returns a COPY not a reference, so modifications won't affect the database
    
    @return characters table - Copy of all character data
    
    Example:
        local chars = AccountPlayed:GetAllCharacters()
        for charKey, data in pairs(chars) do
            print(string.format("%s: %s - %.1f hours", 
                charKey, data.class, data.time/3600))
        end
]]
function AccountPlayed:GetAllCharacters()
    local copy = {}
    for charKey, data in pairs(AccountPlayedDB) do
        if type(data) == "table" and data.time then
            copy[charKey] = {
                time = data.time,
                class = data.class
            }
        end
    end
    return copy
end

--[[
    Check if AccountPlayed has loaded and has data
    Useful for other addons to check before trying to read data
    
    @return loaded boolean - True if addon has initialized
    @return hasData boolean - True if database contains any character data
    
    Example:
        local loaded, hasData = AccountPlayed:IsReady()
        if loaded and hasData then
            -- Safe to read data
        end
]]
function AccountPlayed:IsReady()
    local hasData = false
    for _ in pairs(AccountPlayedDB) do
        hasData = true
        break
    end
    return true, hasData
end

--[[
    Get formatted time string
    Useful for other addons to display time consistently
    
    @param seconds number - Time in seconds
    @param useYears boolean - Use years/days format if true, hours/minutes if false
    @return formatted string - Formatted time string
    
    Example:
        local str = AccountPlayed:FormatTime(86400, false)
        -- Returns: "24h 0m"
]]
function AccountPlayed:FormatTime(seconds, useYears)
    return FormatTimeSmart(seconds, useYears)
end

--------------------------------------------------
-- Debug helpers
--------------------------------------------------

local function DebugListCharacters()
    print("|cffff0000" .. L.DEBUG_HEADER .. "|r")
    for charKey, data in pairs(AccountPlayedDB) do
        local time, class
        if type(data) == "table" then
            time = data.time or 0
            class = data.class or "UNKNOWN"
        else
            time = data
            class = "UNKNOWN"
        end
        print(string.format(" |cffffff00 - %s : %s (%s)|r", charKey, FormatTime(time), class))
    end
end

SLASH_ACCOUNTPLAYEDDEBUG1 = "/apdebug"
SlashCmdList.ACCOUNTPLAYEDDEBUG = DebugListCharacters

--------------------------------------------------
-- Popup Window + Rows
--------------------------------------------------

-- Create a single row (class name + bar + value text)
local function CreateRow(parent, width, height)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, height)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")

    -- Highlight texture for hover
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)
    row.highlight:Hide()

    -- Class name
    row.classText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.classText:SetPoint("LEFT", 0, 0)
    row.classText:SetWidth(100)
    row.classText:SetJustifyH("LEFT")

    -- Status bar (dynamic width via anchors)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("LEFT", row.classText, "RIGHT", 8, 0)
    row.bar:SetPoint("RIGHT", row, "RIGHT", -120, 0)
    row.bar:SetHeight(height - 4)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)
    row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bar.bg:SetAllPoints()
    row.bar.bg:SetColorTexture(0, 0, 0, 0.4)

    -- Right-side value text
    row.valueText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.valueText:SetPoint("LEFT", row.bar, "RIGHT", 8, 0)
    row.valueText:SetWidth(150)
    row.valueText:SetJustifyH("LEFT")

    -- Hover and click handlers
    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
        if self.className then
            local chars = GetCharactersByClass(self.className)
            if #chars > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(self.className .. " Characters", 1, 1, 1)
                GameTooltip:AddLine(" ")
                
                for _, char in ipairs(chars) do
                    local name = char.key:match("%-(.+)$") or char.key
                    local timeStr = FormatTimeSmart(char.time, AccountPlayedPopupDB.useYears)
                    local color = RAID_CLASS_COLORS[char.class] or { r = 1, g = 1, b = 1 }
                    GameTooltip:AddDoubleLine(name, timeStr, color.r, color.g, color.b, 1, 1, 1)
                end
                
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to print in chat", 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end
        end
    end)

    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)

    row:SetScript("OnClick", function(self)
        if self.className then
            local chars = GetCharactersByClass(self.className)
            if #chars > 0 then
                print("|cff00ff00" .. self.className .. " Characters:|r")
                for _, char in ipairs(chars) do
                    local name = char.key:match("%-(.+)$") or char.key
                    local timeStr = FormatTimeSmart(char.time, AccountPlayedPopupDB.useYears)
                    local color = RAID_CLASS_COLORS[char.class] or { r = 1, g = 1, b = 1 }
                    print(string.format("  |cff%02x%02x%02x%s|r - %s", 
                        color.r * 255, color.g * 255, color.b * 255, name, timeStr))
                end
            end
        end
    end)

    return row
end

--------------------------------------------------
-- Scrollbar visibility helper
--------------------------------------------------

local function UpdateScrollBarVisibility(frame)
    local sf = frame.scrollFrame
    -- ScrollBar naming may differ between versions
    local sb = sf and (sf.ScrollBar or sf.scrollBar)
    if not sb then return end

    if sf:GetVerticalScrollRange() > 0 then
        sb:Show()
    else
        sb:Hide()
        sf:SetVerticalScroll(0)
    end
end

--------------------------------------------------
-- Popup creation
--------------------------------------------------

local function CreatePopup()
    if AP.popupFrame then return AP.popupFrame end

    local START_W, START_H = AccountPlayedPopupDB.width or 520, AccountPlayedPopupDB.height or 300
    local MIN_W, MIN_H = 420, 200
    local MAX_W, MAX_H = 720, 400

    local f = CreateFrame("Frame", "AccountPlayedPopup", UIParent, "BackdropTemplate")
    f:SetSize(START_W, START_H)
    
    -- Restore saved position or default to center
    if AccountPlayedPopupDB.point then
        f:SetPoint(AccountPlayedPopupDB.point, UIParent, AccountPlayedPopupDB.point, 
                   AccountPlayedPopupDB.x or 0, AccountPlayedPopupDB.y or 0)
    else
        f:SetPoint("CENTER")
    end
    
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)

    -- Dragging with position save
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, _, x, y = self:GetPoint()
        AccountPlayedPopupDB.point = point
        AccountPlayedPopupDB.x = x
        AccountPlayedPopupDB.y = y
    end)

    -- Resizing - use modern API if available
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    elseif f.SetMinResize then
        f:SetMinResize(MIN_W, MIN_H)
        f:SetMaxResize(MAX_W, MAX_H)
    end
    f:SetClampedToScreen(true)

    -- Resize grabber
    local br = CreateFrame("Button", nil, f)
    br:SetSize(16, 16)
    br:SetPoint("BOTTOMRIGHT", -6, 6)
    br:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    br:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    br:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    br:SetScript("OnMouseDown", function(self) self:GetParent():StartSizing("BOTTOMRIGHT") end)
    br:SetScript("OnMouseUp", function(self) self:GetParent():StopMovingOrSizing() end)

    -- Backdrop
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetBackdropColor(0, 0, 0, 0.5)

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.title:SetPoint("TOP", f, "TOP", 0, -12)
    f.title:SetText(L.WINDOW_TITLE)

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -10, -10)
    
    -- ESC key handler
    table.insert(UISpecialFrames, "AccountPlayedPopup")

    --------------------------------------------------
    -- ScrollFrame
    --------------------------------------------------

    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)
    f.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    f.content = content

    -- Mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local step = 20
        local new = self:GetVerticalScroll() - delta * step
        new = math.max(0, math.min(new, self:GetVerticalScrollRange()))
        self:SetVerticalScroll(new)
    end)

    -- Total row (fixed)
    f.totalRow = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.totalRow:SetPoint("BOTTOMLEFT", 15, 18)
    f.totalRow:SetTextColor(1, 0.82, 0)

    -- Create rows
    local rowHeight = 22
    local maxRows = 20

    for i = 1, maxRows do
        local row = CreateRow(content, START_W - 60, rowHeight)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        row:Hide()
        AP.popupRows[i] = row
    end

    -- Hard clamp + layout sync on resize
    f:SetScript("OnSizeChanged", function(self, w, h)
        if w < MIN_W then self:SetWidth(MIN_W) end
        if h < MIN_H then self:SetHeight(MIN_H) end
        if w > MAX_W then self:SetWidth(MAX_W) end
        if h > MAX_H then self:SetHeight(MAX_H) end

        -- Save size
        AccountPlayedPopupDB.width = self:GetWidth()
        AccountPlayedPopupDB.height = self:GetHeight()

        local cw = self.scrollFrame:GetWidth()
        self.content:SetWidth(cw)
        for _, row in ipairs(AP.popupRows) do
            row:SetWidth(cw)
        end

        UpdateScrollBarVisibility(self)
    end)

    -- Format toggle checkbox (bottom right, near resize grabber)
    local checkBox = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    checkBox:SetSize(24, 24)
    checkBox:SetPoint("BOTTOMRIGHT", -28, 20)
    checkBox:SetChecked(AccountPlayedPopupDB.useYears)
    
    -- Label for checkbox
    checkBox.text = checkBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkBox.text:SetPoint("RIGHT", checkBox, "LEFT", -4, 0)
    checkBox.text:SetText("Years")
    checkBox.text:SetTextColor(0.9, 0.9, 0.9)
    
    checkBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Time Format", 1, 1, 1)
        GameTooltip:AddLine("Checked: Years/Days", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Unchecked: Hours/Minutes", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    checkBox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    checkBox:SetScript("OnClick", function(self)
        AccountPlayedPopupDB.useYears = self:GetChecked()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        -- Update the display by calling the function that will be defined later
        if AP.popupFrame and AP.popupFrame.UpdateDisplay then
            AP.popupFrame:UpdateDisplay()
        end
    end)
    
    f.formatCheckbox = checkBox

    -- Method to update display without recreating frame
    f.UpdateDisplay = function(self)
        local totals = GetClassTotals()
        local accountTotal = GetAccountTotal()

        if accountTotal == 0 then
            AP.popupRows[1].classText:SetText(L.NO_DATA)
            AP.popupRows[1].bar:SetValue(0)
            AP.popupRows[1].valueText:SetText("")
            AP.popupRows[1]:Show()
            self.totalRow:SetText(L.TOTAL .. "0h")
            return
        end

        local sorted = {}
        for class, time in pairs(totals) do
            table.insert(sorted, { class = class, time = time })
        end
        table.sort(sorted, function(a, b) return a.time > b.time end)

        local topTime = sorted[1].time

        for i, row in ipairs(AP.popupRows) do
            local entry = sorted[i]
            if entry then
                local percent = entry.time / accountTotal
                local barPercent = entry.time / topTime
                local color = RAID_CLASS_COLORS[entry.class] or { r = 1, g = 1, b = 1 }

                row.className = entry.class
                row.classText:SetText(entry.class)
                row.classText:SetTextColor(color.r, color.g, color.b)
                row.bar:SetValue(barPercent)
                row.bar:SetStatusBarColor(color.r, color.g, color.b)
                -- Use format preference for individual class times
                row.valueText:SetText(string.format("%5.1f%% - %s", percent * 100, 
                    FormatTimeSmart(entry.time, AccountPlayedPopupDB.useYears)))
                row:Show()
            else
                row.className = nil
                row:Hide()
            end
        end

        -- Update scroll content height
        self.content:SetHeight(#sorted * 22)
        UpdateScrollBarVisibility(self)

        -- Total row - use saved format preference
        self.totalRow:SetText(L.TOTAL .. FormatTimeSmart(accountTotal, AccountPlayedPopupDB.useYears))
    end

    f:Hide()
    AP.popupFrame = f
    return f
end

--------------------------------------------------
-- Popup update
--------------------------------------------------

local function UpdatePopup()
    local f = CreatePopup()
    
    -- Update checkbox state
    if f.formatCheckbox then
        f.formatCheckbox:SetChecked(AccountPlayedPopupDB.useYears)
    end
    
    -- Update the display
    f:UpdateDisplay()
    f:Show()
end

--------------------------------------------------
-- Slash command
--------------------------------------------------

SLASH_ACCOUNTPLAYEDPOPUP1 = "/apclasswin"
SlashCmdList.ACCOUNTPLAYEDPOPUP = function()
    if AP.popupFrame and AP.popupFrame:IsShown() then
        AP.popupFrame:Hide()
    else
        UpdatePopup()
    end
end

--------------------------------------------------
-- Event handler
--------------------------------------------------

AP.mainFrame:RegisterEvent("PLAYER_LOGIN")
AP.mainFrame:RegisterEvent("TIME_PLAYED_MSG")

AP.mainFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Migrate old data format on first load
        MigrateOldData()
        SafeRequestTimePlayed()
    elseif event == "TIME_PLAYED_MSG" then
        local totalTimePlayed = ...
        local realm, name = GetCharInfo()
        local charKey = GetCharKey(realm, name)
        local _, classFile = UnitClass("player")
        classFile = classFile or "UNKNOWN"

        -- Only update if this is new data or larger than existing
        local existing = AccountPlayedDB[charKey]
        if not existing or not existing.time or totalTimePlayed > existing.time then
            AccountPlayedDB[charKey] = {
                time = totalTimePlayed,
                class = classFile,
            }
        end
    end
end)
