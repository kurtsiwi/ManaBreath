-- ManaBreath - deteccion de la regla de 5 segundos (5SR) de regeneracion de mana.
local ADDON_NAME, ns = ...

local RULE_DURATION = 5.0

-- Ventana para confirmar, mirando el mana, un hechizo cuyo costo no pudimos leer.
local UNKNOWN_COST_WINDOW = 0.35

local MB = {}
MB.name = ADDON_NAME
MB.RULE_DURATION = RULE_DURATION
MB.expires = 0
MB.startedAt = 0
ns.addon = MB
_G.ManaBreath = MB

MB.defaults = {
    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = -150,
    width = 180,
    height = 18,
    scale = 1,
    locked = true,
    sound = false,
    showText = true,
    alwaysShow = false,
    powerFallback = false,
}

-- Secret values (Midnight): los valores protegidos no se pueden comparar ni
-- operar, asi que todo lo que venga del juego pasa por aqui antes de usarse.
local issecretvalue = _G.issecretvalue

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function SafeNumber(value)
    if value == nil or IsSecret(value) then return nil end
    if type(value) ~= "number" then return nil end
    return value
end

local GetPowerCost = (C_Spell and C_Spell.GetSpellPowerCost) or _G.GetSpellPowerCost
local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

-- Devuelve "yes", "no" o "unknown": "unknown" significa que el costo no se
-- pudo leer (API ausente o valor secreto) y hay que confirmarlo por el mana.
local function SpellManaCost(spellID)
    if not GetPowerCost then return "unknown" end
    if spellID == nil or IsSecret(spellID) then return "unknown" end

    local ok, costs = pcall(GetPowerCost, spellID)
    if not ok or type(costs) ~= "table" then return "unknown" end

    local maybeMana = false
    for i = 1, #costs do
        local entry = costs[i]
        if type(entry) == "table" then
            local powerType = SafeNumber(entry.type)
            if powerType == nil then
                maybeMana = true
            elseif powerType == MANA then
                local cost = SafeNumber(entry.cost)
                local perSec = SafeNumber(entry.costPerSec)
                local percent = SafeNumber(entry.costPercent)
                if (cost and cost > 0) or (perSec and perSec > 0) or (percent and percent > 0) then
                    return "yes"
                end
                if cost == nil and perSec == nil and percent == nil then
                    maybeMana = true
                end
            end
        end
    end

    if maybeMana then return "unknown" end
    return "no"
end

local function CurrentMana()
    return SafeNumber(UnitPower("player", MANA))
end

function MB:GetDB()
    return ManaBreathDB or self.defaults
end

function MB:Print(...)
    print("|cff33ccffManaBreath|r:", ...)
end

function MB:Debug(...)
    if self:GetDB().debug then
        self:Print("|cff888888debug|r", ...)
    end
end

-- Solo nos interesan clases y formas que usen mana.
-- UnitPowerType y UnitPowerMax("player") no son secretos en 12.0.
function MB:UsesMana()
    local _, token = UnitPowerType("player")
    return token == "MANA"
end

-- Estado de restriccion (instancia o combate restringido). No cambia la
-- deteccion, pero explica por que un costo puede llegar protegido: es lo
-- primero que hay que mirar si el addon falla solo dentro de una mazmorra.
function MB:UpdateRestrictionState()
    local api = C_RestrictedActions
    if api and api.IsRestricted then
        local ok, restricted = pcall(api.IsRestricted)
        self.restricted = (ok and restricted) or false
        self.restrictionApi = true
    else
        self.restricted = false
        self.restrictionApi = false
    end
    return self.restricted
end

function MB:IsActive()
    return GetTime() < (self.expires or 0)
end

function MB:Remaining()
    return math.max(0, (self.expires or 0) - GetTime())
end

function MB:Start(now, force)
    if not force and not self:UsesMana() then return end
    now = now or GetTime()
    self.startedAt = now
    self.expires = now + RULE_DURATION
    self.pendingUntil = nil
    if ns.display then
        ns.display:Start(self.startedAt, self.expires)
    end
end

function MB:Cancel()
    self.expires = 0
    self.pendingUntil = nil
    if ns.display then
        ns.display:Reset()
    end
end

-- castGUID nunca es secreto y crece de forma monotona por casteo, asi que
-- sirve para no procesar dos veces el mismo hechizo: una canalizacion dispara
-- UNIT_SPELLCAST_SUCCEEDED y UNIT_SPELLCAST_CHANNEL_START a la vez.
function MB:HandleCast(castGUID, spellID)
    if castGUID ~= nil and castGUID == self.lastCastGUID then return end
    self.lastCastGUID = castGUID

    local verdict = SpellManaCost(spellID)
    self:Debug("cast", tostring(spellID), verdict)
    if verdict == "yes" then
        self:Start()
    elseif verdict == "unknown" then
        -- No sabemos el costo: si el mana baja en los proximos instantes,
        -- lo tomamos como gasto propio.
        self.pendingUntil = GetTime() + UNKNOWN_COST_WINDOW
    end
end

function MB:HandlePower()
    local mana = CurrentMana()
    local previous = self.lastMana
    self.lastMana = mana

    if mana == nil or previous == nil or mana >= previous then return end

    local now = GetTime()
    if self.pendingUntil and now <= self.pendingUntil then
        self:Start(now)
    elseif self:GetDB().powerFallback then
        -- Respaldo opcional: cualquier bajada de mana arranca el contador.
        -- Da falsos positivos (p. ej. un enemigo quemando tu mana).
        self:Start(now)
    end
end

local function InitDB()
    ManaBreathDB = ManaBreathDB or {}
    for key, value in pairs(MB.defaults) do
        if ManaBreathDB[key] == nil then
            ManaBreathDB[key] = value
        end
    end
end

local events = CreateFrame("Frame")

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")

events:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        InitDB()
        if ns.display then
            ns.display:Init()
        end

    elseif event == "PLAYER_LOGIN" then
        MB.lastMana = CurrentMana()
        MB:UpdateRestrictionState()
        if ns.display then
            ns.display:ApplySettings()
            ns.display:UpdateShown()
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        -- Tras una pantalla de carga el mana guardado ya no sirve de referencia.
        MB.lastMana = CurrentMana()
        MB:UpdateRestrictionState()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        MB:HandleCast(arg2, arg3)

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        -- Una canalizacion gasta mana mientras dura: el contador cuenta
        -- desde el ultimo tick, no desde el inicio.
        if SpellManaCost(arg3) == "yes" then
            MB:Start()
        end

    elseif event == "UNIT_POWER_UPDATE" then
        if arg2 == "MANA" then
            MB:HandlePower()
        end

    elseif event == "UNIT_DISPLAYPOWER" then
        -- Cambio de forma o de tipo de recurso.
        MB.lastMana = CurrentMana()
        if ns.display then
            ns.display:UpdateShown()
        end
    end
end)

MB.eventFrame = events
