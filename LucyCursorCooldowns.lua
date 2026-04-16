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

-- Icon border (1 pixel black border)
cooldownFrame.border = cooldownFrame:CreateTexture(nil, "BORDER")
cooldownFrame.border:SetSize(38, 38)
cooldownFrame.border:SetPoint("CENTER")
cooldownFrame.border:SetColorTexture(0, 0, 0, 1)
cooldownFrame.border:SetDrawLayer("BORDER", -1)

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
    local borderSize = db.borderSize or 2

    -- Frame should be the same as icon size (no extra padding needed)
    cooldownFrame:SetSize(iconSize, iconSize)
    cooldownFrame.icon:SetSize(iconSize, iconSize)
    cooldownFrame.cooldown:SetSize(iconSize, iconSize)
    cooldownFrame.border:SetSize(iconSize + (borderSize * 2), iconSize + (borderSize * 2))

    -- Apply border visibility and color
    if db.showBorder then
        cooldownFrame.border:Show()
        local bc = db.borderColor
        cooldownFrame.border:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
    else
        cooldownFrame.border:Hide()
    end

    -- Apply DrawEdge setting
    cooldownFrame.cooldown:SetDrawEdge(db.drawEdge)
end

-- Addon loaded handler
function LCC:OnAddonLoaded()
    print("|cFF00FF00LucyCursorCooldowns|r loaded successfully!")

    -- Initialize saved variables with defaults
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

    -- Border settings
    if LucyCursorCooldownsDB.showBorder == nil then
        LucyCursorCooldownsDB.showBorder = true
    end
    if not LucyCursorCooldownsDB.borderColor then
        LucyCursorCooldownsDB.borderColor = { r = 0, g = 0, b = 0, a = 1 }
    end
    if not LucyCursorCooldownsDB.borderSize then
        LucyCursorCooldownsDB.borderSize = 2
    end

    -- Cooldown edge settings
    if LucyCursorCooldownsDB.drawEdge == nil then
        LucyCursorCooldownsDB.drawEdge = true
    end

    -- Minimum cooldown threshold (filter out GCD)
    if not LucyCursorCooldownsDB.minCooldownThreshold then
        LucyCursorCooldownsDB.minCooldownThreshold = 2.0
    end

    -- Apply initial sizes to the cooldown frame
    LCC:UpdateFrameSizes()

    -- Register addon settings in the native Options panel
    LCC:RegisterSettings()
end

-- Helper function to safely check if a value is a secret variable
local function IsSafeValue(value)
    -- If value is nil, it's safe (just not available)
    if value == nil then return true end

    -- Try to use the value in a protected call
    local success = pcall(function()
        local _ = value > 0 -- Attempt comparison
    end)

    return success
end

-- Spellcast failed handler
function LCC:OnSpellcastFailed(unit, castGUID, spellID)
    if unit ~= "player" or not spellID then
        return
    end

    -- Get cooldown metadata for the spell.
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    if not cooldownInfo or cooldownInfo.isOnGCD then
        return
    end

    if cooldownInfo.isActive == false then
        return
    end

    -- Try the combat-safe duration object path first.
    local durationObject = C_Spell.GetSpellCooldownDuration(spellID)
    if durationObject then
        LCC:ShowCooldownAtCursor(spellID, durationObject)
        return
    end

    -- Fallback to raw values if duration object is unavailable.
    local success = IsSafeValue(cooldownInfo.duration) and IsSafeValue(cooldownInfo.startTime)
    if not success then
        return
    end

    if cooldownInfo.duration and cooldownInfo.duration > 0 then
        local minThreshold = LucyCursorCooldownsDB.minCooldownThreshold or 2.0
        if cooldownInfo.duration >= minThreshold then
            LCC:ShowCooldownAtCursor(spellID, { startTime = cooldownInfo.startTime, duration = cooldownInfo.duration })
        end
    end
end

-- Show cooldown at cursor
function LCC:ShowCooldownAtCursor(spellID, cooldownData)
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

    -- Set cooldown from duration object if available, otherwise use legacy values.
    if type(cooldownData) == "table" and cooldownData.startTime and cooldownData.duration then
        cooldownFrame.cooldown:SetCooldown(cooldownData.startTime, cooldownData.duration)
    elseif cooldownData and cooldownFrame.cooldown.SetCooldownFromDurationObject then
        cooldownFrame.cooldown:SetCooldownFromDurationObject(cooldownData)
    else
        return
    end

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

-- Slash command handler - opens native settings panel
SLASH_LUCYCURSORCOOLDOWNS1 = "/lcc"
SLASH_LUCYCURSORCOOLDOWNS2 = "/lucycursorcooldowns"

SlashCmdList["LUCYCURSORCOOLDOWNS"] = function(msg)
    LCC:OpenSettings()
end

-- Open the native settings panel
function LCC:OpenSettings()
    -- Modern API (Dragonflight and later)
    if Settings and Settings.OpenToCategory then
        if LCC.settingsCategory then
            Settings.OpenToCategory(LCC.settingsCategory:GetID())
        else
            -- Fallback: open general settings
            Settings.OpenToCategory(Settings.INTERFACE_CATEGORY_ID)
        end
        -- Legacy API (older expansions)
    elseif InterfaceOptionsFrame_OpenToCategory then
        if LCC.optionsPanel then
            InterfaceOptionsFrame_OpenToCategory(LCC.optionsPanel)
            -- Call twice due to Blizzard bug in older versions
            InterfaceOptionsFrame_OpenToCategory(LCC.optionsPanel)
        end
    end
end

-- Shared settings definition
LCC.settingsDefinition = {
    {
        type = "header",
        text = "Icon Settings"
    },
    {
        type = "slider",
        label = "Icon Size",
        key = "iconSize",
        min = 24,
        max = 64,
        step = 1,
        tooltip = "Size of the spell icon and cooldown display",
        fullWidth = true
    },
    {
        type = "slider",
        label = "Cursor Offset X",
        key = "cursorOffsetX",
        min = -100,
        max = 100,
        step = 5,
        tooltip = "Horizontal offset from cursor position (negative values place icon to the left)",
        fullWidth = true
    },
    {
        type = "slider",
        label = "Cursor Offset Y",
        key = "cursorOffsetY",
        min = -100,
        max = 100,
        step = 5,
        tooltip = "Vertical offset from cursor position (negative values place icon below)",
        fullWidth = true
    },
    {
        type = "checkbox",
        label = "Draw Cooldown Edge",
        key = "drawEdge",
        tooltip = "Show edge highlight on cooldown swipe",
        fullWidth = true
    },
    {
        type = "checkbox",
        label = "Show Border",
        key = "showBorder",
        tooltip = "Show a border around the cooldown icon",
        fullWidth = true
    },
    {
        type = "color",
        label = "Border Color",
        key = "borderColor",
        tooltip = "Color of the border",
        fullWidth = true
    },
    {
        type = "slider",
        label = "Border Size",
        key = "borderSize",
        min = 1,
        max = 10,
        step = 1,
        tooltip = "Thickness of the border",
        fullWidth = true
    },
    {
        type = "header",
        text = "Animation"
    },
    {
        type = "slider",
        label = "Animate-In Duration",
        key = "animateInDuration",
        min = 0.05,
        max = 1.0,
        step = 0.05,
        tooltip = "Duration of the pop-in animation"
    },
    {
        type = "slider",
        label = "Initial Y Offset",
        key = "initialYOffset",
        min = 0,
        max = 30,
        step = 1,
        tooltip = "Starting vertical offset for pop-in animation"
    },
    {
        type = "slider",
        label = "Fadeout Delay",
        key = "fadeoutDelay",
        min = 0.5,
        max = 5.0,
        step = 0.1,
        tooltip = "Seconds before icon starts fading out"
    },
    {
        type = "slider",
        label = "Fade Duration",
        key = "fadeDuration",
        min = 0.1,
        max = 2.0,
        step = 0.1,
        tooltip = "Duration of the fade-out animation"
    },
    {
        type = "header",
        text = "Filtering"
    },
    {
        type = "slider",
        label = "Min Cooldown Threshold",
        key = "minCooldownThreshold",
        min = 0.0,
        max = 5.0,
        step = 0.1,
        tooltip = "Minimum cooldown duration to show (filters out GCD)",
        fullWidth = true
    }
}

-- Default values for all settings
LCC.defaults = {
    iconSize = 34,
    cursorOffsetX = 30,
    cursorOffsetY = 30,
    fadeoutDelay = 0.1,
    fadeDuration = 0.5,
    animateInDuration = 0.2,
    initialYOffset = 15,
    showBorder = true,
    borderColor = { r = 0, g = 0, b = 0, a = 1 },
    borderSize = 2,
    drawEdge = true,
    minCooldownThreshold = 2.0
}

-- Reset settings to defaults
function LCC:ResetToDefaults()
    for key, value in pairs(LCC.defaults) do
        if type(value) == "table" then
            -- Deep copy for tables (like borderColor)
            LucyCursorCooldownsDB[key] = {}
            for k, v in pairs(value) do
                LucyCursorCooldownsDB[key][k] = v
            end
        else
            LucyCursorCooldownsDB[key] = value
        end
    end
    LCC:UpdateFrameSizes()
end

-- Register addon settings in the native Options panel
function LCC:RegisterSettings()
    -- Try modern Settings API first (Dragonflight and later)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category, layout = Settings.RegisterCanvasLayoutCategory(LCC.optionsPanel or LCC:CreateOptionsPanel(),
            "Lucy Cursor Cooldowns")
        Settings.RegisterAddOnCategory(category)
        LCC.settingsCategory = category
        -- Fall back to InterfaceOptions for older versions
    elseif InterfaceOptions_AddCategory then
        local panel = LCC:CreateOptionsPanel()
        InterfaceOptions_AddCategory(panel)
        LCC.optionsPanel = panel
    end
end

-- Create the options panel for the native settings UI
function LCC:CreateOptionsPanel()
    if LCC.optionsPanel then
        return LCC.optionsPanel
    end

    local panel = CreateFrame("Frame", "LucyCursorCooldownsOptionsPanel")
    panel.name = "Lucy Cursor Cooldowns"

    -- Get reference to settings database
    local db = LucyCursorCooldownsDB

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Lucy Cursor Cooldowns")

    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure cursor cooldown display settings")

    -- Preview section (top-right corner)
    local previewHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewHeader:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -30, -16)
    previewHeader:SetText("Preview:")

    -- Preview container frame
    local previewContainer = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate")
    previewContainer:SetPoint("TOPRIGHT", previewHeader, "BOTTOMRIGHT", 0, -10)
    previewContainer:SetSize(250, 250)
    if previewContainer.SetBackdrop then
        previewContainer:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
    end

    -- Cursor icon (positioned more centered to allow preview of negative offsets)
    local cursorIcon = previewContainer:CreateTexture(nil, "OVERLAY")
    cursorIcon:SetSize(24, 24)
    cursorIcon:SetTexture("Interface\\Cursor\\Point")
    -- Position cursor texture so the hotspot (pointing finger tip) aligns with our reference point
    -- The Point cursor's hotspot is approximately at offset (3, 21) from the texture's BOTTOMLEFT
    -- We want the hotspot at (10, 10) from container CENTER (more centered for negative offset preview)
    -- So we position BOTTOMLEFT at (10-3, 10-21) = (7, -11)
    cursorIcon:SetPoint("BOTTOMLEFT", previewContainer, "CENTER", 7, -11)

    -- Preview cooldown icon (positioned relative to cursor)
    local previewIcon = CreateFrame("Frame", nil, previewContainer)
    previewIcon:SetFrameStrata("TOOLTIP")
    previewIcon:SetSize(db.iconSize, db.iconSize)
    -- Initially hidden, will be shown during animation
    previewIcon:Hide()
    previewIcon.animOffsetY = 0

    -- Position relative to cursor with offsets
    local function UpdatePreviewPosition()
        local offsetY = previewIcon.animOffsetY or 0
        previewIcon:ClearAllPoints()
        -- Match the actual implementation: use CENTER positioning
        -- The "cursor hotspot" in the preview is at container CENTER (10, 10)
        -- The icon's CENTER should be offset from the cursor hotspot by the configured offsets
        previewIcon:SetPoint("CENTER", previewContainer, "CENTER",
            10 + (db.cursorOffsetX or 20),
            10 + (db.cursorOffsetY or 20) + offsetY)
    end
    UpdatePreviewPosition()

    -- Icon texture
    previewIcon.icon = previewIcon:CreateTexture(nil, "ARTWORK")
    previewIcon.icon:SetAllPoints()
    previewIcon.icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning") -- Example spell icon
    previewIcon.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Icon border
    previewIcon.border = previewIcon:CreateTexture(nil, "BORDER")
    previewIcon.border:SetPoint("CENTER")
    local borderSize = db.borderSize or 2
    previewIcon.border:SetSize(db.iconSize + (borderSize * 2), db.iconSize + (borderSize * 2))
    if db.showBorder then
        local bc = db.borderColor
        previewIcon.border:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
    else
        previewIcon.border:Hide()
    end
    previewIcon.border:SetDrawLayer("BORDER", -1)

    -- Cooldown swipe
    previewIcon.cooldown = CreateFrame("Cooldown", nil, previewIcon, "CooldownFrameTemplate")
    previewIcon.cooldown:SetAllPoints(previewIcon.icon)
    previewIcon.cooldown:SetDrawEdge(db.drawEdge)

    -- Store preview reference for updates
    panel.previewIcon = previewIcon
    panel.cursorIcon = cursorIcon

    -- OnUpdate for animation
    previewIcon:SetScript("OnUpdate", function(self, elapsed)
        UpdatePreviewPosition()
    end)

    -- Function to update preview (static update without animation)
    local function UpdatePreview()
        local iconSize = db.iconSize
        local borderSize = db.borderSize or 2

        previewIcon:SetSize(iconSize, iconSize)
        previewIcon.icon:SetAllPoints(previewIcon)
        previewIcon.border:SetSize(iconSize + (borderSize * 2), iconSize + (borderSize * 2))
        previewIcon.cooldown:SetAllPoints(previewIcon.icon)
        previewIcon.cooldown:SetDrawEdge(db.drawEdge)

        if db.showBorder then
            previewIcon.border:Show()
            local bc = db.borderColor
            previewIcon.border:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
        else
            previewIcon.border:Hide()
        end

        UpdatePreviewPosition()
    end

    panel.UpdatePreview = UpdatePreview

    -- Function to play the full animation sequence
    local animTimer = nil
    local fadeTimer = nil

    local function PlayAnimation()
        -- Cancel any existing timers
        if animTimer then
            animTimer:Cancel()
            animTimer = nil
        end
        if fadeTimer then
            fadeTimer:Cancel()
            fadeTimer = nil
        end

        -- Reset and show icon
        previewIcon:SetAlpha(0)
        previewIcon.animOffsetY = db.initialYOffset or 10
        previewIcon:Show()

        -- Start cooldown
        previewIcon.cooldown:SetCooldown(GetTime(), 10)

        -- Animate in
        local animDuration = db.animateInDuration or 0.2
        local animSteps = 15
        local stepDuration = animDuration / animSteps
        local currentStep = 0

        animTimer = C_Timer.NewTicker(stepDuration, function()
            currentStep = currentStep + 1
            local progress = currentStep / animSteps
            local initialYOffset = db.initialYOffset or 10
            previewIcon.animOffsetY = initialYOffset - (progress * initialYOffset)

            if currentStep >= animSteps then
                previewIcon:SetAlpha(1.0)
                previewIcon.animOffsetY = 0
                animTimer:Cancel()
                animTimer = nil

                -- Schedule fade out
                fadeTimer = C_Timer.NewTimer(db.fadeoutDelay or 2.0, function()
                    -- Fade out
                    local fadeDuration = db.fadeDuration or 0.5
                    local fadeSteps = 20
                    local fadeStepDuration = fadeDuration / fadeSteps
                    local fadeStep = 0

                    fadeTimer = C_Timer.NewTicker(fadeStepDuration, function()
                        fadeStep = fadeStep + 1
                        local newAlpha = 1.0 - (fadeStep / fadeSteps)

                        if newAlpha <= 0 then
                            previewIcon:Hide()
                            previewIcon:SetAlpha(1.0)
                            previewIcon.animOffsetY = 0
                            fadeTimer:Cancel()
                            fadeTimer = nil
                        else
                            previewIcon:SetAlpha(newAlpha)
                        end
                    end)
                end)
            else
                previewIcon:SetAlpha(progress)
            end
        end)
    end

    panel.PlayAnimation = PlayAnimation

    -- Test Animation button
    local testButton = CreateFrame("Button", nil, previewContainer, "UIPanelButtonTemplate")
    testButton:SetSize(120, 25)
    testButton:SetPoint("BOTTOM", previewContainer, "BOTTOM", 0, 10)
    testButton:SetText("Test Animation")
    testButton:SetScript("OnClick", function()
        PlayAnimation()
    end)

    -- Preview description
    local previewDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    previewDesc:SetPoint("TOP", previewContainer, "BOTTOM", 0, -5)
    previewDesc:SetText("Click 'Test Animation' to see the full effect")

    -- Settings container (left side, two-column layout)
    local settingsContainer = CreateFrame("Frame", nil, panel)
    settingsContainer:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
    settingsContainer:SetPoint("BOTTOMRIGHT", previewContainer, "BOTTOMLEFT", -20, 0)

    local yOffset = -10
    local leftColumnX = 10
    local rightColumnX = 310
    local currentColumn = leftColumnX

    -- Helper function to create compact sliders (single line with label and value)
    local function CreateCompactSlider(parent, setting)
        -- Force left column for full-width settings
        if setting.fullWidth and currentColumn == rightColumnX then
            currentColumn = leftColumnX
            yOffset = yOffset - 40
        end

        local container = CreateFrame("Frame", nil, parent)
        container:SetSize(280, 35)
        container:SetPoint("TOPLEFT", currentColumn, yOffset)

        -- Label
        local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        labelText:SetPoint("TOPLEFT", 0, 0)
        labelText:SetText(setting.label)

        -- Slider (using BackdropTemplate for modern WoW)
        local slider = CreateFrame("Slider", nil, container, BackdropTemplateMixin and "BackdropTemplate")
        slider:SetPoint("TOPLEFT", 0, -15)
        slider:SetMinMaxValues(setting.min, setting.max)
        slider:SetValueStep(setting.step)
        slider:SetObeyStepOnDrag(true)
        slider:SetValue(db[setting.key])
        slider:SetWidth(200)
        slider:SetHeight(17)
        slider:SetOrientation("HORIZONTAL")

        -- Slider backdrop (only if BackdropTemplate is available)
        if slider.SetBackdrop then
            slider:SetBackdrop({
                bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
                edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
                tile = true,
                tileSize = 8,
                edgeSize = 8,
                insets = { left = 3, right = 3, top = 6, bottom = 6 }
            })
        end

        -- Slider thumb texture
        local thumb = slider:CreateTexture(nil, "ARTWORK")
        thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        thumb:SetSize(32, 32)
        slider:SetThumbTexture(thumb)

        -- Value label (to the right of slider)
        slider.valueLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        slider.valueLabel:SetPoint("LEFT", slider, "RIGHT", 5, 0)
        slider.valueLabel:SetText(string.format("%.1f", db[setting.key]))

        slider:SetScript("OnValueChanged", function(self, value)
            db[setting.key] = value
            slider.valueLabel:SetText(string.format("%.1f", value))
            LCC:UpdateFrameSizes()
            if panel.UpdatePreview then
                panel.UpdatePreview()
            end
        end)

        if setting.tooltip then
            container.tooltipText = setting.tooltip
        end

        -- Alternate columns (or move to next line if full-width)
        if setting.fullWidth then
            currentColumn = leftColumnX
            yOffset = yOffset - 40
        elseif currentColumn == leftColumnX then
            currentColumn = rightColumnX
        else
            currentColumn = leftColumnX
            yOffset = yOffset - 40
        end

        return container
    end

    -- Helper function to create compact checkboxes
    local function CreateCompactCheckbox(parent, setting)
        -- Force left column for full-width settings
        if setting.fullWidth and currentColumn == rightColumnX then
            currentColumn = leftColumnX
            yOffset = yOffset - 30
        end

        local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", currentColumn, yOffset)
        checkbox:SetChecked(db[setting.key])
        checkbox.Text:SetText(setting.label)
        checkbox.Text:SetFont(checkbox.Text:GetFont(), 11)

        checkbox:SetScript("OnClick", function(self)
            db[setting.key] = self:GetChecked()
            LCC:UpdateFrameSizes()
            if panel.UpdatePreview then
                panel.UpdatePreview()
            end
        end)

        if setting.tooltip then
            checkbox.tooltipText = setting.tooltip
        end

        -- Alternate columns (or move to next line if full-width)
        if setting.fullWidth then
            currentColumn = leftColumnX
            yOffset = yOffset - 30
        elseif currentColumn == leftColumnX then
            currentColumn = rightColumnX
        else
            currentColumn = leftColumnX
            yOffset = yOffset - 30
        end

        return checkbox
    end

    -- Helper function to create compact color pickers
    local function CreateCompactColorPicker(parent, setting)
        -- Force left column for full-width settings
        if setting.fullWidth and currentColumn == rightColumnX then
            currentColumn = leftColumnX
            yOffset = yOffset - 35
        end

        local container = CreateFrame("Frame", nil, parent)
        container:SetSize(280, 30)
        container:SetPoint("TOPLEFT", currentColumn, yOffset)

        -- Label
        local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        labelText:SetPoint("LEFT", 0, 0)
        labelText:SetText(setting.label .. ":")

        -- Color swatch button (standard WoW style)
        local colorSwatch = CreateFrame("Button", nil, container)
        colorSwatch:SetSize(20, 20)
        colorSwatch:SetPoint("LEFT", 120, 0)

        -- Checkerboard background for alpha visualization
        local bgTexture = colorSwatch:CreateTexture(nil, "BACKGROUND")
        bgTexture:SetTexture("Tileable-Checkers")
        bgTexture:SetTexCoord(0, 0.25, 0, 0.25)
        bgTexture:SetDesaturated(true)
        bgTexture:SetVertexColor(1, 1, 1, 0.75)
        bgTexture:SetAllPoints(colorSwatch)

        -- Actual color texture
        local colorTexture = colorSwatch:CreateTexture(nil, "ARTWORK")
        colorTexture:SetAllPoints(colorSwatch)
        local color = db[setting.key]
        colorTexture:SetColorTexture(color.r, color.g, color.b, color.a or 1)

        -- Standard swatch border
        local swatchBorder = colorSwatch:CreateTexture(nil, "OVERLAY")
        swatchBorder:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
        swatchBorder:SetAllPoints(colorSwatch)

        colorSwatch:SetScript("OnClick", function()
            local currentColor = db[setting.key]
            local function OnColorSelect(restore)
                local newR, newG, newB, newA
                if restore then
                    newR, newG, newB, newA = restore.r, restore.g, restore.b, restore.a
                else
                    newR, newG, newB = ColorPickerFrame:GetColorRGB()
                    newA = ColorPickerFrame:GetColorAlpha()
                end

                db[setting.key] = { r = newR, g = newG, b = newB, a = newA }
                colorTexture:SetColorTexture(newR, newG, newB, newA)
                LCC:UpdateFrameSizes()
                if panel.UpdatePreview then
                    panel.UpdatePreview()
                end
            end

            ColorPickerFrame:SetupColorPickerAndShow({
                r = currentColor.r,
                g = currentColor.g,
                b = currentColor.b,
                opacity = currentColor.a,
                hasOpacity = true,
                swatchFunc = OnColorSelect,
                opacityFunc = OnColorSelect,
                cancelFunc = OnColorSelect,
            })
        end)

        if setting.tooltip then
            container.tooltipText = setting.tooltip
        end

        -- Alternate columns (or move to next line if full-width)
        if setting.fullWidth then
            currentColumn = leftColumnX
            yOffset = yOffset - 35
        elseif currentColumn == leftColumnX then
            currentColumn = rightColumnX
        else
            currentColumn = leftColumnX
            yOffset = yOffset - 35
        end

        return container
    end

    -- Section headers (full width)
    local function CreateHeader(parent, text)
        -- If we're in the right column, we need to move down to complete the row first
        if currentColumn == rightColumnX then
            yOffset = yOffset - 40 -- Complete the current row
        end

        -- Reset to left column for headers
        currentColumn = leftColumnX
        if yOffset ~= -10 then
            yOffset = yOffset - 20 -- Add extra spacing before header
        end

        local header = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        header:SetPoint("TOPLEFT", 10, yOffset)
        header:SetText(text)
        yOffset = yOffset - 30 -- Space after header for controls
        currentColumn = leftColumnX
        return header
    end

    -- Build UI from settings definition
    for _, setting in ipairs(LCC.settingsDefinition) do
        if setting.type == "header" then
            CreateHeader(settingsContainer, setting.text)
        elseif setting.type == "slider" then
            CreateCompactSlider(settingsContainer, setting)
        elseif setting.type == "checkbox" then
            CreateCompactCheckbox(settingsContainer, setting)
        elseif setting.type == "color" then
            CreateCompactColorPicker(settingsContainer, setting)
        end
    end

    -- Refresh function for settings panel
    panel.refresh = function()
        -- This is called when the panel is shown
        -- We could refresh all slider values here if needed
    end

    -- Default button handler
    panel.default = function()
        LCC:ResetToDefaults()

        -- Refresh the panel by recreating it
        LCC.optionsPanel = nil
        if Settings and LCC.settingsCategory then
            Settings.OpenToCategory(LCC.settingsCategory:GetID())
        end

        print("|cFF00FF00LucyCursorCooldowns|r settings reset to defaults")
    end

    LCC.optionsPanel = panel
    return panel
end
