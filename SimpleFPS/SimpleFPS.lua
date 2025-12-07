--- SimpleFPS.lua
--- Minimal FPS monitor compatible with Ascension / 3.3.5 UI (UI 30300).

local AddonName = "SimpleFPS"

-- SavedVariables table will be: SimpleFPSDB
local defaults = {
    scale = 1.0,
    alpha = 1.0,
    showLatency = true,
    point = {"CENTER", nil, "CENTER", 0, 0},
}

-- Utility: ensure db exists and fill defaults
local function EnsureDB()
    if not SimpleFPSDB then SimpleFPSDB = {} end
    for k,v in pairs(defaults) do
        if SimpleFPSDB[k] == nil then SimpleFPSDB[k] = v end
    end
end

-- Main frame
local f = CreateFrame("Frame", "SimpleFPS_Frame", UIParent)
f:SetSize(140, 22) -- widened to avoid text clipping
f:SetFrameStrata("BACKGROUND")
f:EnableMouse(true)
f:SetMovable(true)
f:SetClampedToScreen(true)

-- Background and text
f.bg = f:CreateTexture(nil, "BACKGROUND")
f.bg:SetAllPoints(f)

f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
f.text:SetPoint("CENTER", 0, 0)

-- Default art (semi-transparent black)
f.bg:SetTexture(0,0,0,0.4)

-- small border so the frame is easier to see (optional)
f.border = CreateFrame("Frame", nil, f, "BackdropTemplate")
f.border:SetAllPoints(f)
f.border:SetBackdrop({edgeFile = "Interface\Tooltips\UI-Tooltip-Border", edgeSize = 12, insets = {left=4,right=4,top=4,bottom=4}})

-- Create an options panel and register it with the Interface Options
local options = CreateFrame("Frame", "SimpleFPSOptionsPanel", UIParent)
options.name = AddonName

-- Heading for panel
options.title = options:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
options.title:SetPoint("TOPLEFT", 16, -16)
options.title:SetText(AddonName)

-- Scale slider
local scaleSlider = CreateFrame("Slider", "SimpleFPS_ScaleSlider", options, "OptionsSliderTemplate")
scaleSlider:SetPoint("TOPLEFT", options, "TOPLEFT", 16, -60)
scaleSlider:SetWidth(200)
scaleSlider:SetMinMaxValues(0.5, 2.0)
scaleSlider:SetValueStep(0.01)
_G[scaleSlider:GetName() .. "Text"]:SetText("Scale: ")
_G[scaleSlider:GetName() .. "Low"]:SetText("0.5")
_G[scaleSlider:GetName() .. "High"]:SetText("2.0")

-- Opacity slider
local alphaSlider = CreateFrame("Slider", "SimpleFPS_AlphaSlider", options, "OptionsSliderTemplate")
alphaSlider:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -40)
alphaSlider:SetWidth(200)
alphaSlider:SetMinMaxValues(0.1, 1.0)
alphaSlider:SetValueStep(0.01)
_G[alphaSlider:GetName() .. "Text"]:SetText("Opacity: ")
_G[alphaSlider:GetName() .. "Low"]:SetText("0.1")
_G[alphaSlider:GetName() .. "High"]:SetText("1.0")

-- Latency toggle checkbox
local latencyCheck = CreateFrame("CheckButton", "SimpleFPS_ShowLatencyCheck", options, "InterfaceOptionsCheckButtonTemplate")
latencyCheck:SetPoint("TOPLEFT", alphaSlider, "BOTTOMLEFT", 0, -30)
_G[latencyCheck:GetName() .. "Text"]:SetText("Show latency (ms)")

-- Add to Interface Options
InterfaceOptions_AddCategory(options)

-- Helper to update displayed text (used in multiple places)
local function UpdateDisplay(hovered)
    local fps = GetFramerate()
    local _, _, latencyHome, latencyWorld = GetNetStats()
    local latHome = latencyHome or 0
    local latWorld = latencyWorld or 0

    -- color logic
    if fps < 20 then
        f.text:SetTextColor(1, 0, 0)        -- red
    elseif fps < 50 then
        f.text:SetTextColor(1, 1, 0)        -- yellow
    else
        f.text:SetTextColor(0, 1, 0)        -- green
    end

    -- shortened display for small scale
    local currentScale = f:GetScale() or 1
    local shortMode = (currentScale < 0.8)

    if shortMode then
        -- only show FPS
        f.text:SetFormattedText("FPS: %.0f", fps)
        return
    end

    -- if hovered show both latencies
    if hovered and SimpleFPSDB.showLatency then
        f.text:SetFormattedText("FPS: %.0f / H:%d W:%dms", fps, latHome, latWorld)
        return
    end

    -- default: show FPS + single latency if enabled
    if SimpleFPSDB.showLatency then
        -- prefer home latency when available
        local primary = latHome or latWorld or 0
        f.text:SetFormattedText("FPS: %.0f / %dms", fps, primary)
    else
        f.text:SetFormattedText("FPS: %.0f", fps)
    end
end

-- Hook slider actions
scaleSlider:SetScript("OnValueChanged", function(self, val)
    f:SetScale(val)
    SimpleFPSDB.scale = val
    _G[self:GetName() .. "Text"]:SetFormattedText("Scale: %.2f", val)
    UpdateDisplay(false)
end)

alphaSlider:SetScript("OnValueChanged", function(self, val)
    f:SetAlpha(val)
    SimpleFPSDB.alpha = val
    _G[self:GetName() .. "Text"]:SetFormattedText("Opacity: %.2f", val)
end)

latencyCheck:SetScript("OnClick", function(self)
    SimpleFPSDB.showLatency = self:GetChecked() and true or false
    UpdateDisplay(false)
end)

-- Click handling for dragging and opening options
f:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self:StartMoving()
    end
end)

f:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        self:StopMovingOrSizing()
        -- save position
        local point, relativeTo, relPoint, xOfs, yOfs = self:GetPoint(1)
        SimpleFPSDB.point = {point, nil, relPoint, xOfs, yOfs}
    elseif button == "RightButton" then
        InterfaceOptionsFrame_OpenToCategory(options)
        InterfaceOptionsFrame_OpenToCategory(options)
    end
end)

-- Hover behavior: show both latencies when hovered
f:SetScript("OnEnter", function(self)
    UpdateDisplay(true)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("SimpleFPS")
    local _, _, latencyHome, latencyWorld = GetNetStats()
    GameTooltip:AddLine(string.format("Home latency: %dms", latencyHome or 0), 1,1,1)
    GameTooltip:AddLine(string.format("World latency: %dms", latencyWorld or 0), 1,1,1)
    GameTooltip:Show()
end)

f:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    UpdateDisplay(false)
end)

-- Update loop: update text periodically
local elapsed = 0
f:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.5 then
        UpdateDisplay(false)
        elapsed = 0
    end
end)

-- Initialization
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    EnsureDB()

    -- apply saved scale/alpha
    f:SetScale(SimpleFPSDB.scale or defaults.scale)
    f:SetAlpha(SimpleFPSDB.alpha or defaults.alpha)

    -- apply saved position
    local p = SimpleFPSDB.point or defaults.point
    f:ClearAllPoints()
    f:SetPoint(p[1], UIParent, p[3], p[4], p[5])

    -- Initialize slider positions
    scaleSlider:SetValue(SimpleFPSDB.scale)
    alphaSlider:SetValue(SimpleFPSDB.alpha)
    latencyCheck:SetChecked(SimpleFPSDB.showLatency)

    -- initial display
    UpdateDisplay(false)

    -- Hide default text from being selectable
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- Slash command to open options quickly
SLASH_SIMPLEFPS1 = "/simplefps"
SlashCmdList["SIMPLEFPS"] = function(msg)
    InterfaceOptionsFrame_OpenToCategory(options)
    InterfaceOptionsFrame_OpenToCategory(options)
end

