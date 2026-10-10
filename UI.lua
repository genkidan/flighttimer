local addonName, FT = ...
FT = _G.FlightTimer
local L = FT.L

local function Clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function FormatTime(seconds)
    seconds = math.max(0, math.floor((seconds or 0) + 0.5))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

FT.FormatTime = FormatTime

local SOUND_CHOICES = {
    { key = "raid_warning", name = "Raid Warning", id = 8959 },
    { key = "ready_check", name = "Ready Check", id = 8960 },
    { key = "quest_complete", name = "Quest Complete", id = 619 },
    { key = "level_up", name = "Level Up", id = 888 },
    { key = "whisper", name = "Whisper", id = 3081 },
}

local function GetSelectedSound()
    local key = FT.db and FT.db.profile and FT.db.profile.selectedSound or "raid_warning"
    for _, sound in ipairs(SOUND_CHOICES) do
        if sound.key == key then return sound end
    end
    return SOUND_CHOICES[1]
end

local function PreviewSound(sound)
    if sound and PlaySound then pcall(PlaySound, sound.id, "Master") end
end

function FT:CreateUI()
    if self.frame then return end

    local f = CreateFrame("Frame", "FlightTimerFrame", UIParent, "BackdropTemplate")
    f:SetSize(430, 126)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScale(self.db.profile.scale or 1)
    f:SetAlpha(self.db.profile.alpha or 1)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 20,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    f:SetBackdropColor(0.035, 0.028, 0.02, 0.96)
    f:SetBackdropBorderColor(0.72, 0.53, 0.22, 1)

    local iconFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    iconFrame:SetSize(44, 44)
    iconFrame:SetPoint("TOPLEFT", 15, -18)
    iconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    })
    iconFrame:SetBackdropColor(0.08, 0.06, 0.035, 1)
    iconFrame:SetBackdropBorderColor(0.82, 0.63, 0.25, 1)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    icon:SetTexture("Interface\\Icons\\Ability_Mount_Wyvern_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local soundButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    soundButton:SetSize(64, 20)
    soundButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -10)

    local route = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    route:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 10, -2)
    route:SetPoint("RIGHT", soundButton, "LEFT", -8, 0)
    route:SetJustifyH("LEFT")
    if route.SetWordWrap then route:SetWordWrap(true) end
    route:SetTextColor(1, 0.82, 0.38)
    route:SetText("FlightTimer")

    local function RefreshSoundButton()
        local enabled = FT.db and FT.db.profile and FT.db.profile.soundEnabled ~= false
        soundButton:SetText(enabled and L.SOUND_ON or L.SOUND_OFF)
    end

    local soundMenu = CreateFrame("Frame", nil, f, "BackdropTemplate")
    soundMenu:SetSize(178, 142)
    soundMenu:SetPoint("TOPRIGHT", soundButton, "BOTTOMRIGHT", 0, -4)
    soundMenu:SetFrameStrata("DIALOG")
    soundMenu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    soundMenu:SetBackdropColor(0.035, 0.028, 0.02, 0.98)
    soundMenu:SetBackdropBorderColor(0.72, 0.53, 0.22, 1)
    soundMenu:Hide()

    local menuTitle = soundMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    menuTitle:SetPoint("TOP", 0, -9)
    menuTitle:SetText(L.SOUND_MENU_TITLE)

    local function RefreshSoundMenu()
        local selected = GetSelectedSound()
        if soundMenu.buttons then
            for _, b in ipairs(soundMenu.buttons) do
                b:SetText((b.sound.key == selected.key and "|cffFFD100> |r" or "  ") .. b.sound.name)
            end
        end
    end

    soundMenu.buttons = {}
    for i, sound in ipairs(SOUND_CHOICES) do
        local b = CreateFrame("Button", nil, soundMenu, "UIPanelButtonTemplate")
        b:SetSize(154, 20)
        b:SetPoint("TOP", 0, -25 - ((i - 1) * 22))
        b.sound = sound
        b:SetScript("OnClick", function(button)
            FT.db.profile.selectedSound = button.sound.key
            PreviewSound(button.sound)
            RefreshSoundMenu()
            FT:Print(string.format(L.SOUND_SELECTED, button.sound.name))
        end)
        soundMenu.buttons[i] = b
    end
    RefreshSoundMenu()

    soundButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    soundButton:SetScript("OnClick", function(_, mouseButton)
        if not FT.db or not FT.db.profile then return end
        if mouseButton == "RightButton" then
            RefreshSoundMenu()
            if soundMenu:IsShown() then soundMenu:Hide() else soundMenu:Show() end
            return
        end
        FT.db.profile.soundEnabled = not (FT.db.profile.soundEnabled ~= false)
        RefreshSoundButton()
        FT:Print(FT.db.profile.soundEnabled and L.SOUND_ENABLED_MSG or L.SOUND_DISABLED_MSG)
    end)
    soundButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:SetText("FlightTimer", 1, 0.82, 0.38)
        local enabled = FT.db and FT.db.profile and FT.db.profile.soundEnabled ~= false
        GameTooltip:AddLine(enabled and L.SOUND_TOOLTIP_ON or L.SOUND_TOOLTIP_OFF, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    soundButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    RefreshSoundButton()

    local bar = CreateFrame("StatusBar", nil, f, "BackdropTemplate")
    bar:SetPoint("TOPLEFT", route, "BOTTOMLEFT", 0, -7)
    bar:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    bar:SetHeight(19)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.86, 0.57, 0.12, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 9,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    bar:SetBackdropColor(0.03, 0.025, 0.02, 0.9)
    bar:SetBackdropBorderColor(0.42, 0.34, 0.20, 1)

    local shine = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    shine:SetTexture("Interface\\Buttons\\WHITE8X8")
    shine:SetPoint("TOPLEFT", 2, -2)
    shine:SetPoint("TOPRIGHT", -2, -2)
    shine:SetHeight(3)
    shine:SetVertexColor(1, 1, 1, 0.13)

    local timerText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("CENTER", 0, 0)
    timerText:SetText("0:00")

    local arrival = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    arrival:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 1, -5)
    arrival:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    arrival:SetJustifyH("LEFT")
    if arrival.SetWordWrap then arrival:SetWordWrap(true) end
    arrival:SetText("")

    local cancelInfo = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cancelInfo:SetPoint("TOPLEFT", arrival, "BOTTOMLEFT", 0, -7)
    cancelInfo:SetPoint("RIGHT", f, "RIGHT", -122, 0)
    cancelInfo:SetJustifyH("LEFT")
    if cancelInfo.SetWordWrap then cancelInfo:SetWordWrap(true) end
    cancelInfo:SetTextColor(0.82, 0.78, 0.68)
    cancelInfo:SetText("")

    local cancelButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelButton:SetSize(100, 22)
    cancelButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 12)
    cancelButton:SetText(L.CANCEL_FLIGHT)
    cancelButton:SetScript("OnClick", function()
        FT:RequestEarlyLanding()
    end)
    cancelButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:SetText(L.CANCEL_FLIGHT, 1, 0.82, 0.38)
        GameTooltip:AddLine(L.CANCEL_TOOLTIP, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    cancelButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Ajuste automatiquement la hauteur de la fenêtre lorsque les noms de
    -- destinations ou le texte d'arrêt occupent plusieurs lignes. Ainsi,
    -- aucun texte ne peut dépasser de la bordure inférieure.
    local function RefreshLayout()
        local routeHeight = math.max(14, math.ceil(route:GetStringHeight() or 14))
        local arrivalHeight = math.max(12, math.ceil(arrival:GetStringHeight() or 12))
        local cancelHeight = math.max(12, math.ceil(cancelInfo:GetStringHeight() or 12))

        -- 20 px au-dessus du trajet, 7 px avant la barre, 19 px pour la barre,
        -- 5 px avant l'arrivée, 7 px avant l'information d'arrêt et une marge
        -- inférieure confortable de 14 px.
        local requiredHeight = 20 + routeHeight + 7 + 19 + 5 + arrivalHeight + 7 + cancelHeight + 14
        f:SetHeight(math.max(126, requiredHeight))
    end

    f:SetScript("OnDragStart", function(frame)
        if not FT.db.profile.locked then frame:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        FT.db.profile.point = point
        FT.db.profile.relativePoint = relativePoint
        FT.db.profile.x = x
        FT.db.profile.y = y
    end)

    f:SetScript("OnEnter", function(frame)
        if not FT.db.profile.locked then
            GameTooltip:SetOwner(frame, "ANCHOR_TOP")
            GameTooltip:SetText("FlightTimer", 1, 0.82, 0.38)
            GameTooltip:AddLine(L.MOVE_TOOLTIP, 0.85, 0.85, 0.85)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f:ClearAllPoints()
    f:SetPoint(self.db.profile.point or "CENTER", UIParent, self.db.profile.relativePoint or "CENTER", self.db.profile.x or 0, self.db.profile.y or -210)

    self.frame = f
    self.routeText = route
    self.bar = bar
    self.timerText = timerText
    self.arrivalText = arrival
    self.cancelInfoText = cancelInfo
    self.cancelButton = cancelButton
    self.icon = icon
    self.soundButton = soundButton
    self.soundMenu = soundMenu
    self.RefreshSoundButton = RefreshSoundButton
    self.RefreshLayout = RefreshLayout

    RefreshLayout()
    if self.db.profile.alwaysShow then
        self:ShowIdleUI()
    else
        f:Hide()
    end
end

function FT:ShowIdleUI()
    self.routeText:SetText("FlightTimer")
    self.timerText:SetText(L.READY)
    self.arrivalText:SetText(L.IDLE)
    self.bar:SetMinMaxValues(0, 1)
    self.bar:SetValue(0)
    self:SetCancelState(false, nil, true, true)
    self.cancelInfoText:SetText("")
    if self.RefreshLayout then self.RefreshLayout() end
    self.frame:Show()
end

function FT:SetCancelState(requested, nextStop, isDirect, hidden)
    if not self.cancelButton or not self.cancelInfoText then return end

    if hidden then
        self.cancelButton:Hide()
    else
        self.cancelButton:Show()
    end

    if requested then
        self.cancelButton:Disable()
        self.cancelButton:SetText(L.CANCEL_REQUESTED)
        self.cancelInfoText:SetText(string.format(L.STOPPING_AT, nextStop or L.NEXT_STOP_UNKNOWN))
    elseif isDirect then
        self.cancelButton:Disable()
        self.cancelButton:SetText(L.DIRECT)
        self.cancelInfoText:SetText(string.format(L.DIRECT_STOP, nextStop or L.NEXT_STOP_UNKNOWN))
    else
        self.cancelButton:Enable()
        self.cancelButton:SetText(L.CANCEL_FLIGHT)
        self.cancelInfoText:SetText(string.format(L.CANCEL_STOP, nextStop or L.NEXT_STOP_UNKNOWN))
    end

    if self.RefreshLayout then self.RefreshLayout() end
end

function FT:SetLocked(locked)
    self.db.profile.locked = locked and true or false
end

function FT:ResetPosition()
    self.db.profile.point = "CENTER"
    self.db.profile.relativePoint = "CENTER"
    self.db.profile.x = 0
    self.db.profile.y = -210
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -210)
    end
end

function FT:PlayTenSecondAlert()
    if not self.db or not self.db.profile or self.db.profile.soundEnabled == false then return end
    if PlaySound then
        local sound = GetSelectedSound()
        pcall(PlaySound, sound.id, "Master")
    end
end

function FT:ResetTenSecondAlert()
    self.tenSecondAlertPlayed = false
end

function FT:ShowFlightUI(fromName, toName, estimate, learned, source, nextStop, isDirect)
    self:CreateUI()
    self.displaySource = source
    self:ResetTenSecondAlert()
    self.routeText:SetText(string.format("%s  |cff8c8c8c>|r  %s", fromName or "?", toName or "?"))
    self.bar:SetMinMaxValues(0, math.max(estimate or 1, 1))
    self.bar:SetValue(0)
    self.bar:SetStatusBarColor(0.86, 0.57, 0.12, 1)
    if estimate then
        self.timerText:SetText("0:00 / " .. FormatTime(estimate))
        if source == "database" then
            self.arrivalText:SetText(L.ARRIVAL .. " : --:--:--  |cff8c8c8c(Base Classic)|r")
        else
            self.arrivalText:SetText(L.ARRIVAL .. " : --:--:--")
        end
    else
        self.timerText:SetText(L.LEARNING)
        self.arrivalText:SetText(L.UNKNOWN)
    end
    self:SetCancelState(false, nextStop, isDirect, false)
    self.frame:Show()
end

function FT:SwitchToEarlyLandingUI(fromName, stopName, estimate, learned, source, elapsed)
    self:CreateUI()
    self.displaySource = source
    self:ResetTenSecondAlert()
    elapsed = math.max(0, elapsed or 0)

    self.routeText:SetText(string.format("%s  |cff8c8c8c>|r  %s", fromName or "?", stopName or "?"))
    self.bar:SetStatusBarColor(0.86, 0.57, 0.12, 1)

    if estimate and estimate > 0 then
        self.bar:SetMinMaxValues(0, estimate)
        self.bar:SetValue(Clamp(elapsed, 0, estimate))
        local remaining = math.max(0, estimate - elapsed)
        self.timerText:SetText(FormatTime(remaining) .. "  |cff9a8f7a/ " .. FormatTime(estimate) .. "|r")
        local arrivalEpoch = time() + math.floor(remaining + 0.5)
        local suffix = source == "database" and "  |cff8c8c8c(Base Classic)|r" or ""
        self.arrivalText:SetText(string.format("%s : %s%s", L.ARRIVAL, date("%H:%M:%S", arrivalEpoch), suffix))
    else
        self.bar:SetMinMaxValues(0, 1)
        self.bar:SetValue(0)
        self.timerText:SetText(L.LEARNING .. "  " .. FormatTime(elapsed))
        self.arrivalText:SetText(L.UNKNOWN)
    end

    if self.RefreshLayout then self.RefreshLayout() end
    self.frame:Show()
end

function FT:UpdateFlightUI(elapsed, estimate, learned)
    if not self.frame or not self.frame:IsShown() then return end

    if estimate and estimate > 0 then
        local remaining = math.max(0, estimate - elapsed)
        self.bar:SetMinMaxValues(0, estimate)
        self.bar:SetValue(Clamp(elapsed, 0, estimate))
        self.timerText:SetText(FormatTime(remaining) .. "  |cff9a8f7a/ " .. FormatTime(estimate) .. "|r")

        local arrivalEpoch = time() + math.floor(remaining + 0.5)
        local suffix = self.displaySource == "database" and "  |cff8c8c8c(Base Classic)|r" or ""
        self.arrivalText:SetText(string.format("%s%s : %s%s", learned and "" or "~ ", L.ARRIVAL, date("%H:%M:%S", arrivalEpoch), suffix))

        if remaining <= 10 then
            if not self.tenSecondAlertPlayed then
                self.tenSecondAlertPlayed = true
                self:PlayTenSecondAlert()
            end
            self.bar:SetStatusBarColor(0.92, 0.34, 0.12, 1)
            self.arrivalText:SetText("|cffff6b35" .. L.IMMINENT .. "|r  -  " .. date("%H:%M:%S", arrivalEpoch) .. suffix)
        else
            self.bar:SetStatusBarColor(0.86, 0.57, 0.12, 1)
        end
    else
        local pulse = (math.sin(GetTime() * 3) + 1) * 0.5
        self.bar:SetMinMaxValues(0, 1)
        self.bar:SetValue(0.15 + pulse * 0.7)
        self.timerText:SetText(L.LEARNING .. "  " .. FormatTime(elapsed))
        self.arrivalText:SetText(L.LEARNING_DETAIL)
    end
end

function FT:FinishFlightUI(actualDuration, status)
    if not self.frame then return end
    self.bar:SetStatusBarColor(0.25, 0.72, 0.32, 1)
    self.timerText:SetText(FormatTime(actualDuration or 0))
    self.arrivalText:SetText(status or L.FLIGHT_DONE)
    self.cancelInfoText:SetText("")
    self.cancelButton:Hide()
    C_Timer.After(3, function()
        if FT.frame and not FT.activeFlight and not FT.db.profile.alwaysShow then
            FT.frame:Hide()
        end
    end)
end
