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

    local spellName = GetSpellInfo(spellID)
    print("|cFFFF0000Spell cast failed:|r " .. (spellName or "Unknown") .. " (ID: " .. spellID .. ")")
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
