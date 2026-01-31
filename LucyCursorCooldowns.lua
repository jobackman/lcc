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
cooldownFrame:SetSize(48, 48)
cooldownFrame:SetFrameStrata("TOOLTIP")
cooldownFrame:SetFrameLevel(1000)
cooldownFrame:Hide()

-- Border (draw first, behind icon)
cooldownFrame.border = cooldownFrame:CreateTexture(nil, "BACKGROUND")
cooldownFrame.border:SetSize(64, 64)
cooldownFrame.border:SetPoint("CENTER")
cooldownFrame.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
cooldownFrame.border:SetBlendMode("ADD")

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

-- Update frame position to follow cursor
local function UpdateCursorPosition()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cooldownFrame.cursorX = x / scale + 20
    cooldownFrame.cursorY = y / scale + 20
    
    local offsetY = cooldownFrame.animOffsetY or 0
    cooldownFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cooldownFrame.cursorX, cooldownFrame.cursorY + offsetY)
end

-- OnUpdate script to follow cursor
cooldownFrame:SetScript("OnUpdate", function(self, elapsed)
    UpdateCursorPosition()
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

-- Addon loaded handler
function LCC:OnAddonLoaded()
    print("|cFF00FF00LucyCursorCooldowns|r loaded successfully!")

    -- Initialize saved variables
    if not LucyCursorCooldownsDB.enabled then
        LucyCursorCooldownsDB.enabled = true
    end
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
        print("|cFFFF0000Spell on cooldown:|r " .. spellName .. " (" .. string.format("%.1f", cooldownInfo.duration) .. "s)")
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
        -- Animate in for new cooldown
        LCC:AnimateInCooldownFrame()
    else
        -- Just reset alpha if updating
        cooldownFrame:SetAlpha(1.0)
    end
    
    -- Start fade timer (fade out after 2 seconds)
    LCC.fadeTimer = C_Timer.NewTimer(2.0, function()
        LCC:FadeOutCooldownFrame()
    end)
end

-- Animate in the cooldown frame
function LCC:AnimateInCooldownFrame()
    local cooldownFrame = LCC.cooldownFrame
    
    -- Set initial state
    cooldownFrame:SetAlpha(0)
    cooldownFrame:SetScale(1.2)
    cooldownFrame.animOffsetY = 10
    
    -- Show the frame
    cooldownFrame:Show()
    
    local animDuration = 0.2
    local animSteps = 15
    local stepDuration = animDuration / animSteps
    local currentStep = 0
    
    local animTimer
    animTimer = C_Timer.NewTicker(stepDuration, function()
        currentStep = currentStep + 1
        
        local progress = currentStep / animSteps
        local newAlpha = progress
        local newScale = 1.2 - (progress * 0.2)
        cooldownFrame.animOffsetY = 10 - (progress * 10)
        
        if currentStep >= animSteps then
            cooldownFrame:SetAlpha(1.0)
            cooldownFrame:SetScale(1.0)
            cooldownFrame.animOffsetY = 0
            animTimer:Cancel()
        else
            cooldownFrame:SetAlpha(newAlpha)
            cooldownFrame:SetScale(newScale)
        end
    end)
end

-- Fade out the cooldown frame
function LCC:FadeOutCooldownFrame()
    local cooldownFrame = LCC.cooldownFrame
    if not cooldownFrame:IsShown() then return end
    
    local fadeDuration = 0.5
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
            cooldownFrame:SetScale(1.0)
            cooldownFrame.animOffsetY = 0
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
    optionsFrame:SetSize(400, 300)
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

    -- Enable/Disable checkbox
    local enableCheckbox = CreateFrame("CheckButton", "LCCEnableCheckbox", optionsFrame, "UICheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", 20, -40)
    enableCheckbox:SetChecked(LucyCursorCooldownsDB.enabled)
    enableCheckbox.text = enableCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableCheckbox.text:SetPoint("LEFT", enableCheckbox, "RIGHT", 5, 0)
    enableCheckbox.text:SetText("Enable Addon")

    enableCheckbox:SetScript("OnClick", function(self)
        LucyCursorCooldownsDB.enabled = self:GetChecked()
        local status = LucyCursorCooldownsDB.enabled and "enabled" or "disabled"
        print("|cFF00FF00LucyCursorCooldowns|r is now " .. status)
    end)

    -- Info text
    local infoText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOPLEFT", 20, -80)
    infoText:SetPoint("RIGHT", -20, 0)
    infoText:SetJustifyH("LEFT")
    infoText:SetText("This addon tracks spell cast failures and cursor cooldowns.\n\nUse /lcc for available commands.")

    -- Close button (already included in BasicFrameTemplateWithInset)
    optionsFrame:Show()
end
