-- ManaBreath - barra que se llena durante los 5 segundos de la regla.
local ADDON_NAME, ns = ...
local MB = ns.addon

local D = {}
D.state = "idle"
ns.display = D

local COLOR_ACTIVE = { 0.20, 0.45, 0.95 }
local COLOR_DONE   = { 0.25, 0.85, 0.40 }
local COLOR_IDLE   = { 0.35, 0.35, 0.38 }

local HOLD_AFTER_DONE = 0.7
local FADE_DURATION = 0.5

local LABEL = "5SR"
local DONE_TEXT = "regen"

-- La ventana es fija (0.0 - 5.0), asi que las 51 cadenas posibles del contador
-- se construyen una sola vez al cargar. Con esto el OnUpdate no asigna nada:
-- un string.format por frame generaria basura 60 veces por segundo.
local TENTH_TEXT = {}
for i = 0, math.floor(MB.RULE_DURATION * 10) do
    TENTH_TEXT[i] = string.format("%.1f", i / 10)
end

function D:Init()
    if self.frame then return end

    local f = CreateFrame("Frame", "ManaBreathFrame", UIParent)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:Hide()

    local border = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    border:SetAllPoints(f)
    border:SetColorTexture(0, 0, 0, 0.9)

    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0.08, 0.08, 0.10, 0.85)

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, MB.RULE_DURATION)
    bar:SetValue(0)
    bar:SetStatusBarColor(unpack(COLOR_ACTIVE))

    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:Hide()

    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 4, 0)
    label:SetText(LABEL)

    local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("RIGHT", -4, 0)

    f:SetScript("OnDragStart", function(self)
        if not MB:GetDB().locked then
            self:StartMoving()
        end
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        D:SavePosition()
    end)

    -- El OnUpdate solo esta instalado mientras hay algo que animar, asi que la
    -- barra visible pero en reposo (desbloqueada o con `/mb always on`) no
    -- cuesta nada por frame.
    self.onUpdate = function(_, elapsed)
        D:OnUpdate(elapsed)
    end

    self.frame = f
    self.bar = bar
    self.spark = spark
    self.label = label
    self.timeText = timeText

    self:ApplySettings()
end

function D:SavePosition()
    local db = MB:GetDB()
    local point, _, relPoint, x, y = self.frame:GetPoint()
    db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
end

function D:ApplySettings()
    if not self.frame then return end
    local db = MB:GetDB()

    self.frame:SetSize(db.width, db.height)
    self.frame:SetScale(db.scale)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    self.frame:EnableMouse(not db.locked)

    self.spark:SetSize(16, db.height * 2.2)
    self.label:SetShown(db.showText)
    self.timeText:SetShown(db.showText)

    self:UpdateShown()
end

function D:UpdateShown()
    if not self.frame then return end
    local db = MB:GetDB()

    local show
    if self.state ~= "idle" then
        show = true
    elseif not db.locked then
        -- Desbloqueado: siempre visible para poder colocarlo.
        show = true
    else
        show = db.alwaysShow and MB:UsesMana()
    end

    if show and self.state == "idle" then
        self.bar:SetValue(MB.RULE_DURATION)
        self.bar:SetStatusBarColor(unpack(COLOR_IDLE))
        self.timeText:SetText(db.locked and "" or "arrastrame")
        self.spark:Hide()
    end

    self.frame:SetShown(show)
end

function D:SetUpdating(enabled)
    if enabled == self.updating then return end
    self.updating = enabled
    self.frame:SetScript("OnUpdate", enabled and self.onUpdate or nil)
end

function D:Start(startedAt, expires)
    if not self.frame then return end
    self.startedAt = startedAt
    self.expires = expires
    self.state = "active"
    self.holdLeft = nil
    self.shownTenths = nil
    self.sparkOffset = nil
    self.frame:SetAlpha(1)
    self.bar:SetStatusBarColor(unpack(COLOR_ACTIVE))
    self.spark:SetShown(true)
    self.frame:Show()
    self:SetUpdating(true)
end

function D:Finish()
    local db = MB:GetDB()
    self.state = "done"
    self.holdLeft = HOLD_AFTER_DONE
    self.bar:SetValue(MB.RULE_DURATION)
    self.bar:SetStatusBarColor(unpack(COLOR_DONE))
    self.timeText:SetText(DONE_TEXT)
    self.spark:Hide()
    if db.sound then
        PlaySound(SOUNDKIT.READY_CHECK, "Master")
    end
end

function D:Reset()
    if not self.frame then return end
    self.state = "idle"
    self.holdLeft = nil
    self.shownTenths = nil
    self.sparkOffset = nil
    self.frame:SetAlpha(1)
    self.bar:SetValue(0)
    self.timeText:SetText("")
    self.spark:Hide()
    self:SetUpdating(false)
    self:UpdateShown()
end

function D:OnUpdate(elapsed)
    if self.state == "active" then
        local remaining = self.expires - GetTime()
        if remaining <= 0 then
            self:Finish()
            return
        end

        local filled = MB.RULE_DURATION - remaining
        self.bar:SetValue(filled)

        -- Texto y chispa solo cambian cuando hay algo nuevo que mostrar: a 60
        -- fps el contador cambia 10 veces por segundo y la chispa se mueve un
        -- pixel cada varios frames. Sin esto serian 60 SetText y 60 SetPoint
        -- por segundo para el mismo resultado visible.
        local tenths = math.floor(remaining * 10)
        if tenths ~= self.shownTenths then
            self.shownTenths = tenths
            self.timeText:SetText(TENTH_TEXT[tenths] or "")
        end

        local offset = math.floor((filled / MB.RULE_DURATION) * self.bar:GetWidth())
        if offset ~= self.sparkOffset then
            self.sparkOffset = offset
            -- Siempre es el mismo anclaje, asi que SetPoint lo reemplaza y no
            -- hace falta ClearAllPoints.
            self.spark:SetPoint("CENTER", self.bar, "LEFT", offset, 0)
        end

    elseif self.state == "done" then
        self.holdLeft = self.holdLeft - elapsed
        if self.holdLeft > 0 then return end

        local alpha = self.frame:GetAlpha() - elapsed / FADE_DURATION
        if alpha <= 0 then
            self:Reset()
        else
            self.frame:SetAlpha(alpha)
        end
    end
end
