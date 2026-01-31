-- LucyCursorCooldowns - Main addon file
local addonName, addon = ...

-- Create the main addon object
LucyCursorCooldowns = {}
local LCC = LucyCursorCooldowns

-- Saved variables
LucyCursorCooldownsDB = LucyCursorCooldownsDB or {}

-- Initialize the main frame
local frame = CreateFrame("Frame", "LucyCursorCooldownsFrame")
LCC.frame = frame

-- Create the cursor cooldown frame
local cooldownFrame = CreateFrame("Frame", "LucyCursorCooldownFrame", UIParent)
cooldownFrame:SetSize(36, 36)
cooldownFrame:SetFrameStrata("TOOLTIP")
cooldownFrame:SetFrameLevel(1000)
cooldownFrame:Hide()

-- Icon texture
cooldownFrame.icon = cooldownFrame:CreateTexture(nil, "ARTWORK")
cooldownFrame.icon:SetSize(36, 36)
cooldownFrame.icon:SetPoint("CENTER")
cooldownFrame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

-- Cooldown swipe
cooldownFrame.cooldown = CreateFrame("Cooldown", nil, cooldownFrame, "CooldownFrameTemplate")
cooldownFrame.cooldown:SetSize(36, 36)
cooldownFrame.cooldown:SetPoint("CENTER")
cooldownFrame.cooldown:SetDrawEdge(true)
cooldownFrame.cooldown:SetHideCountdownNumbers(false)

-- Store the cooldown frame reference and fade timer
LCC.cooldownFrame = cooldownFrame
LCC.fadeTimer = nil

-- Store the locked position for the cooldown frame
cooldownFrame.lockedX = nil
cooldownFrame.lockedY = nil

-- Update frame position (either locked position or for animation offset changes)
local function UpdateFramePosition()
    local offsetY = cooldownFrame.animOffsetY or 0
    if cooldownFrame.lockedX and cooldownFrame.lockedY then
        cooldownFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cooldownFrame.lockedX, cooldownFrame.lockedY + offsetY)
    end
end

-- Capture current cursor position and lock the frame to it
local function LockFrameToCursor()
    local db = LucyCursorCooldownsDB
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cooldownFrame.lockedX = x / scale + (db.cursorOffsetX or 20)
    cooldownFrame.lockedY = y / scale + (db.cursorOffsetY or 20)
    UpdateFramePosition()
end

-- OnUpdate script to update position (only for animation offset changes)
cooldownFrame:SetScript("OnUpdate", function(self, elapsed)
    UpdateFramePosition()
end)

-- Event handler function
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            LCC:OnAddonLoaded()
            frame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "UNIT_SPELLCAST_FAILED" then
        LCC:OnSpellcastFailed(...)
    end
end

-- Set the event handler
frame:SetScript("OnEvent", OnEvent)

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")

-- Filter for player unit only
frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")

-- Helper function to update frame sizes based on settings
function LCC:UpdateFrameSizes()
    local db = LucyCursorCooldownsDB
    local cooldownFrame = LCC.cooldownFrame

    -- Update icon and cooldown sizes to match
    local iconSize = db.iconSize

    -- Frame should be the same as icon size (no extra padding needed)
    cooldownFrame:SetSize(iconSize, iconSize)
    cooldownFrame.icon:SetSize(iconSize, iconSize)
    cooldownFrame.cooldown:SetSize(iconSize, iconSize)
end

-- Addon loaded handler
function LCC:OnAddonLoaded()
    print("|cFF00FF00LucyCursorCooldowns|r loaded successfully!")

    -- Initialize saved variables with defaults
    if LucyCursorCooldownsDB.enabled == nil then
        LucyCursorCooldownsDB.enabled = true
    end

    -- Icon size (frame and border sizes are calculated from this)
    if not LucyCursorCooldownsDB.iconSize then
        LucyCursorCooldownsDB.iconSize = 36
    end

    -- Cursor offset
    if not LucyCursorCooldownsDB.cursorOffsetX then
        LucyCursorCooldownsDB.cursorOffsetX = 20
    end
    if not LucyCursorCooldownsDB.cursorOffsetY then
        LucyCursorCooldownsDB.cursorOffsetY = 20
    end

    -- Timing settings
    if not LucyCursorCooldownsDB.fadeoutDelay then
        LucyCursorCooldownsDB.fadeoutDelay = 2.0
    end
    if not LucyCursorCooldownsDB.fadeDuration then
        LucyCursorCooldownsDB.fadeDuration = 0.5
    end
    if not LucyCursorCooldownsDB.animateInDuration then
        LucyCursorCooldownsDB.animateInDuration = 0.2
    end

    -- Animation settings
    if not LucyCursorCooldownsDB.initialYOffset then
        LucyCursorCooldownsDB.initialYOffset = 10
    end

    -- Apply initial sizes to the cooldown frame
    LCC:UpdateFrameSizes()
end

-- Spellcast failed handler
function LCC:OnSpellcastFailed(unit, castGUID, spellID)
    if unit ~= "player" then return end
    if not LucyCursorCooldownsDB.enabled then return end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    local spellName = spellInfo and spellInfo.name or "Unknown"

    -- Get cooldown information
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)

    if cooldownInfo and cooldownInfo.duration > 0 then
        -- Spell is on cooldown, show the cursor cooldown frame
        LCC:ShowCooldownAtCursor(spellID, cooldownInfo.startTime, cooldownInfo.duration)
        print("|cFFFF0000Spell on cooldown:|r " ..
            spellName .. " (" .. string.format("%.1f", cooldownInfo.duration) .. "s)")
    else
        print("|cFFFF0000Spell cast failed:|r " .. spellName .. " (ID: " .. spellID .. ")")
    end
end

-- Show cooldown at cursor
function LCC:ShowCooldownAtCursor(spellID, startTime, duration)
    local cooldownFrame = LCC.cooldownFrame

    -- Cancel any existing fade timer
    if LCC.fadeTimer then
        LCC.fadeTimer:Cancel()
        LCC.fadeTimer = nil
    end

    -- Get spell icon
    local spellTexture = C_Spell.GetSpellTexture(spellID)
    if spellTexture then
        cooldownFrame.icon:SetTexture(spellTexture)
    end

    -- Set cooldown
    cooldownFrame.cooldown:SetCooldown(startTime, duration)

    -- Check if frame is already showing (updating existing cooldown)
    local isUpdate = cooldownFrame:IsShown()

    if not isUpdate then
        -- Lock position to cursor for new cooldown
        LockFrameToCursor()
        -- Animate in for new cooldown
        LCC:AnimateInCooldownFrame()
    else
        -- Just reset alpha if updating (keep same position)
        cooldownFrame:SetAlpha(1.0)
    end

    -- Start fade timer (fade out after configured delay)
    LCC.fadeTimer = C_Timer.NewTimer(LucyCursorCooldownsDB.fadeoutDelay or 2.0, function()
        LCC:FadeOutCooldownFrame()
    end)
end

-- Animate in the cooldown frame
function LCC:AnimateInCooldownFrame()
    local cooldownFrame = LCC.cooldownFrame
    local db = LucyCursorCooldownsDB

    -- Set initial state
    cooldownFrame:SetAlpha(0)
    cooldownFrame.animOffsetY = db.initialYOffset or 10

    -- Show the frame
    cooldownFrame:Show()

    local animDuration = db.animateInDuration or 0.2
    local animSteps = 15
    local stepDuration = animDuration / animSteps
    local currentStep = 0

    local animTimer
    animTimer = C_Timer.NewTicker(stepDuration, function()
        currentStep = currentStep + 1

        local progress = currentStep / animSteps
        local newAlpha = progress
        local initialYOffset = db.initialYOffset or 10
        cooldownFrame.animOffsetY = initialYOffset - (progress * initialYOffset)

        if currentStep >= animSteps then
            cooldownFrame:SetAlpha(1.0)
            cooldownFrame.animOffsetY = 0
            animTimer:Cancel()
        else
            cooldownFrame:SetAlpha(newAlpha)
        end
    end)
end

-- Fade out the cooldown frame
function LCC:FadeOutCooldownFrame()
    local cooldownFrame = LCC.cooldownFrame
    if not cooldownFrame:IsShown() then return end

    local db = LucyCursorCooldownsDB
    local fadeDuration = db.fadeDuration or 0.5
    local fadeSteps = 20
    local stepDuration = fadeDuration / fadeSteps
    local currentStep = 0

    local fadeTimer
    fadeTimer = C_Timer.NewTicker(stepDuration, function()
        currentStep = currentStep + 1
        local newAlpha = 1.0 - (currentStep / fadeSteps)

        if newAlpha <= 0 then
            cooldownFrame:Hide()
            cooldownFrame:SetAlpha(1.0)
            cooldownFrame.animOffsetY = 0
            -- Clear locked position when frame is hidden
            cooldownFrame.lockedX = nil
            cooldownFrame.lockedY = nil
            fadeTimer:Cancel()
        else
            cooldownFrame:SetAlpha(newAlpha)
        end
    end)
end

-- Slash command handler
SLASH_LUCYCURSORCOOLDOWNS1 = "/lcc"
SLASH_LUCYCURSORCOOLDOWNS2 = "/lucycursorcooldowns"

SlashCmdList["LUCYCURSORCOOLDOWNS"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "" or msg == "help" then
        print("|cFF00FF00LucyCursorCooldowns Commands:|r")
        print("  /lcc - Show this help")
        print("  /lcc config - Open configuration")
        print("  /lcc toggle - Toggle addon on/off")
        print("  /lcc status - Show current status")
    elseif msg == "config" or msg == "options" then
        LCC:ShowOptionsFrame()
    elseif msg == "toggle" then
        LucyCursorCooldownsDB.enabled = not LucyCursorCooldownsDB.enabled
        local status = LucyCursorCooldownsDB.enabled and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"
        print("|cFF00FF00LucyCursorCooldowns|r is now " .. status)
    elseif msg == "status" then
        local status = LucyCursorCooldownsDB.enabled and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"
        print("|cFF00FF00LucyCursorCooldowns|r status: " .. status)
    else
        print("|cFFFF0000Unknown command:|r " .. msg)
        print("Type |cFF00FF00/lcc help|r for a list of commands")
    end
end

-- Create options frame
function LCC:ShowOptionsFrame()
    if LCC.optionsFrame then
        if LCC.optionsFrame:IsShown() then
            LCC.optionsFrame:Hide()
        else
            LCC.optionsFrame:Show()
        end
        return
    end

    -- Create the options frame
    local optionsFrame = CreateFrame("Frame", "LucyCursorCooldownsOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    optionsFrame:SetSize(500, 500)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)

    LCC.optionsFrame = optionsFrame

    -- Set title
    optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    optionsFrame.title:SetPoint("TOP", optionsFrame.TitleBg, "TOP", 0, -5)
    optionsFrame.title:SetText("Lucy Cursor Cooldowns Options")

    -- Create scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "LCCScrollFrame", optionsFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 4, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -26, 4)

    -- Create content frame for scroll frame
    local content = CreateFrame("Frame", "LCCScrollContent", scrollFrame)
    content:SetSize(450, 600) -- Height can be larger than the scroll frame
    scrollFrame:SetScrollChild(content)

    local yOffset = -10
    local db = LucyCursorCooldownsDB

    -- Enable/Disable checkbox
    local enableCheckbox = CreateFrame("CheckButton", "LCCEnableCheckbox", content, "UICheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    enableCheckbox:SetChecked(db.enabled)
    enableCheckbox.text = enableCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableCheckbox.text:SetPoint("LEFT", enableCheckbox, "RIGHT", 5, 0)
    enableCheckbox.text:SetText("Enable Addon")

    enableCheckbox:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked()
        local status = db.enabled and "enabled" or "disabled"
        print("|cFF00FF00LucyCursorCooldowns|r is now " .. status)
    end)

    yOffset = yOffset - 40

    -- Helper function to create a slider
    local function CreateSlider(parent, name, label, minVal, maxVal, step, getValue, setValue, tooltip)
        local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 30, yOffset)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        slider:SetValue(getValue())
        slider:SetWidth(300)

        -- Set label
        getglobal(slider:GetName() .. "Text"):SetText(label)

        -- Value label
        slider.valueLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slider.valueLabel:SetPoint("TOP", slider, "BOTTOM", 0, 0)
        slider.valueLabel:SetText(string.format("%.2f", getValue()))

        -- Min/Max labels
        getglobal(slider:GetName() .. "Low"):SetText(minVal)
        getglobal(slider:GetName() .. "High"):SetText(maxVal)

        slider:SetScript("OnValueChanged", function(self, value)
            setValue(value)
            slider.valueLabel:SetText(string.format("%.2f", value))
            LCC:UpdateFrameSizes()
        end)

        if tooltip then
            slider.tooltipText = tooltip
        end

        yOffset = yOffset - 50
        return slider
    end

    -- Section: Size Settings
    local sizeHeader = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    sizeHeader:SetPoint("TOPLEFT", 20, yOffset)
    sizeHeader:SetText("Size Settings")
    yOffset = yOffset - 30

    CreateSlider(content, "LCCIconSizeSlider", "Icon Size", 24, 64, 1,
        function() return db.iconSize end,
        function(val) db.iconSize = val end,
        "Size of the spell icon and cooldown display")

    -- Section: Timing Settings
    local timingHeader = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    timingHeader:SetPoint("TOPLEFT", 20, yOffset)
    timingHeader:SetText("Timing Settings")
    yOffset = yOffset - 30

    CreateSlider(content, "LCCFadeoutDelaySlider", "Fadeout Delay", 0.5, 5.0, 0.1,
        function() return db.fadeoutDelay end,
        function(val) db.fadeoutDelay = val end,
        "Seconds before icon starts fading out")

    CreateSlider(content, "LCCFadeDurationSlider", "Fade Duration", 0.1, 2.0, 0.1,
        function() return db.fadeDuration end,
        function(val) db.fadeDuration = val end,
        "Duration of the fade-out animation")

    CreateSlider(content, "LCCAnimateInDurationSlider", "Animate-In Duration", 0.05, 1.0, 0.05,
        function() return db.animateInDuration end,
        function(val) db.animateInDuration = val end,
        "Duration of the pop-in animation")

    -- Section: Animation Settings
    local animHeader = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    animHeader:SetPoint("TOPLEFT", 20, yOffset)
    animHeader:SetText("Animation Settings")
    yOffset = yOffset - 30

    CreateSlider(content, "LCCInitialYOffsetSlider", "Initial Y Offset", 0, 30, 1,
        function() return db.initialYOffset end,
        function(val) db.initialYOffset = val end,
        "Starting vertical offset for pop-in animation")

    -- Section: Position Settings
    local posHeader = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    posHeader:SetPoint("TOPLEFT", 20, yOffset)
    posHeader:SetText("Cursor Offset")
    yOffset = yOffset - 30

    CreateSlider(content, "LCCCursorOffsetXSlider", "Cursor Offset X", 0, 100, 5,
        function() return db.cursorOffsetX end,
        function(val) db.cursorOffsetX = val end,
        "Horizontal offset from cursor position")

    CreateSlider(content, "LCCCursorOffsetYSlider", "Cursor Offset Y", 0, 100, 5,
        function() return db.cursorOffsetY end,
        function(val) db.cursorOffsetY = val end,
        "Vertical offset from cursor position")

    -- Reset button
    yOffset = yOffset - 10
    local resetButton = CreateFrame("Button", "LCCResetButton", content, "UIPanelButtonTemplate")
    resetButton:SetSize(150, 25)
    resetButton:SetPoint("TOPLEFT", 20, yOffset)
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function()
        -- Reset all values to defaults
        db.iconSize = 36
        db.cursorOffsetX = 20
        db.cursorOffsetY = 20
        db.fadeoutDelay = 2.0
        db.fadeDuration = 0.5
        db.animateInDuration = 0.2
        db.initialYOffset = 10

        -- Update all sliders
        LCC.optionsFrame:Hide()
        LCC.optionsFrame = nil
        LCC:ShowOptionsFrame()
        LCC:UpdateFrameSizes()

        print("|cFF00FF00LucyCursorCooldowns|r settings reset to defaults")
    end)

    -- Close button (already included in BasicFrameTemplateWithInset)
    optionsFrame:Show()
end
