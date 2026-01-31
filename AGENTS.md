# Agent Guidelines for LucyCursorCooldowns

## Project Overview
World of Warcraft addon written in Lua. Tracks spell cast failures and cursor cooldowns.

## General Rules
- Be extremely concise. Sacrifice grammar for the sake of concision.
- At the end, give me a list of unresolved questions to answer, if any.

## Build/Test/Lint Commands

### Build Process
- Build addon package: `.release/build.sh` (packages and copies to WoW directory)
- Manual package: `.release/release.sh -d -z` (creates zip in .release/)
- Build output: `.release/LucyCursorCooldowns/`
- Exclusions: Add files to `.pkgmeta` ignore list to exclude from package (AGENTS.md is excluded)

### Testing
No automated tests. Manual testing required:
1. Run `.release/build.sh` to build and deploy to WoW
2. Launch WoW and test in-game
3. Use `/lcc` commands to verify functionality
4. Check Lua errors with `/luaerror on` in-game
5. Test spell cast failures on various cooldowns

### Validation
- Check `.toc` file syntax (must start with `## Interface: XXXXXX`)
- Verify Lua syntax: `lua -c LucyCursorCooldowns.lua` (if Lua interpreter available)
- No automated linting - manual code review only

## Code Style Guidelines

### File Structure
- `.toc` file: Addon metadata and file loading order
- `.lua` files: Implementation code
- Files loaded in order listed in `.toc`

### Lua Conventions

#### Naming
- Global addon table: `LucyCursorCooldowns` (full name)
- Local alias: `LCC` (abbreviated)
- Saved variables: `<AddonName>DB` pattern (e.g., `LucyCursorCooldownsDB`)
- Functions: PascalCase for public methods (`LCC:OnAddonLoaded`)
- Local functions: camelCase (`local function onEvent`)
- Frame names: `<AddonName><Purpose>Frame` (e.g., `LucyCursorCooldownsOptionsFrame`)
- Constants: UPPER_SNAKE_CASE

#### Variable Scope
- Use `local` for all variables unless global required
- Module pattern: `local addonName, addon = ...`
- Create local aliases for frequently used globals: `local LCC = LucyCursorCooldowns`

#### Formatting
- Indentation: 4 spaces (no tabs)
- Line breaks: Unix style (LF)
- Trailing commas: Not used in Lua tables
- String quotes: Double quotes preferred for user-facing text
- Comments: `--` for single line, `--[[ ]]--` for multiline

#### Functions
- Use colon syntax for methods: `function LCC:MethodName()`
- Use dot syntax for static functions: `function LCC.UtilityFunction()`
- Declare local functions before use: `local function helper() ... end`

#### Tables
- Initialize tables with defaults: `LucyCursorCooldownsDB = LucyCursorCooldownsDB or {}`
- Access with dot notation when possible: `table.field`
- Use bracket notation for dynamic keys: `table[key]`

#### WoW API Patterns
- Event registration: Always register events before setting handlers
- Frame creation: `CreateFrame("Type", "GlobalName", parent, "template")`
- Unit filtering: Use `RegisterUnitEvent` for unit-specific events when possible
- Color codes: Use `|cFFRRGGBB` format (e.g., `|cFF00FF00` green, `|cFFFF0000` red, `|r` reset)
- Saved variables: Declare in `.toc` with `## SavedVariables:` or `## SavedVariablesPerCharacter:`
- Timers: Use `C_Timer.NewTimer()` for one-shot, `C_Timer.NewTicker()` for repeating
- Spell info: Use `C_Spell.*` namespace (not deprecated GetSpellInfo function)

#### Error Handling
- Validate inputs: Check for nil/invalid values
- Guard clauses: Early returns for invalid conditions
- User feedback: Use `print()` with color codes for status messages
- Fail gracefully: Don't break addon on error

#### Comments
- Function headers: Describe purpose, not implementation
- Complex logic: Brief inline comments
- TODOs: Use `-- TODO:` prefix
- Avoid obvious comments

#### Slash Commands
- Register with: `SLASH_<ADDONNAME>1`, `SLASH_<ADDONNAME>2`, etc.
- Handler: `SlashCmdList["<ADDONNAME>"] = function(msg) ... end`
- Convert input to lowercase: `msg = string.lower(msg or "")`

#### Frames and UI
- Use Blizzard templates: `"BasicFrameTemplateWithInset"`, `"UICheckButtonTemplate"`, `"OptionsSliderTemplate"`
- Make frames movable with drag handlers (`:EnableMouse()`, `:RegisterForDrag()`)
- Reuse frames: Check if exists before creating (store in addon table)
- ScrollFrames: Use `"UIPanelScrollFrameTemplate"` with `:SetScrollChild()`
- Cooldown frames: Use `"CooldownFrameTemplate"` with `:SetCooldown(startTime, duration)`
- Clean up: Store frame references in addon table for reuse

## Common Patterns

### Event Handler Pattern
```lua
local function OnEvent(self, event, ...)
    if event == "EVENT_NAME" then
        AddonName:HandlerFunction(...)
    end
end
frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("EVENT_NAME")
```

### Initialization Pattern
```lua
function LCC:OnAddonLoaded()
    -- Initialize saved variables with defaults
    if not LucyCursorCooldownsDB.setting then
        LucyCursorCooldownsDB.setting = defaultValue
    end
end
```

### Toggle Pattern
```lua
setting = not setting
local status = setting and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"
print(message .. status)
```

## File Organization
- Keep related functionality together
- Group by feature, not by type
- Single file OK for small addons
- Split into modules when file exceeds ~500 lines

## WoW API Version
- Current interface: 120000 (WoW 12.0.0)
- Update `## Interface:` in `.toc` for new patches
- Check API changes on Wowpedia/Warcraft Wiki
- Using modern Spell API: `C_Spell.GetSpellInfo`, `C_Spell.GetSpellCooldown`, `C_Spell.GetSpellTexture`

## Common Pitfalls
- Don't use Lua 5.2+ features (WoW uses Lua 5.1)
- Avoid `_G` pollution - use locals
- Unregister events when not needed
- Don't trust user input - validate everything
- Test with multiple characters/settings

## Resources
- WoW API: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
- Lua 5.1 Reference: https://www.lua.org/manual/5.1/
- UI Documentation: https://wowpedia.fandom.com/wiki/UI_beginner%27s_guide

## Git Workflow
- Commit messages: Concise, imperative mood ("Add feature" not "Added feature")
- Recent commits show simple style: "Add config", "Buggy but somewhat works"
- Branch naming: descriptive lowercase with hyphens
- Keep commits atomic and focused on single changes

## Build Output
- `.release/` directory contains build artifacts (gitignored)
- Built addon in `.release/LucyCursorCooldowns/`
- Only `.toc` and `.lua` files included (AGENTS.md excluded via `.pkgmeta`)
- CHANGELOG.md auto-generated from git commits during build
