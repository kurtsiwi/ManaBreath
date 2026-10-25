-- API falsa de WoW, suficiente para ejercitar ManaBreath fuera del juego.
unpack = unpack or table.unpack

local M = { now = 1000, mana = 5000, powerToken = "MANA", sounds = 0, log = {} }
_G.MOCK = M

function GetTime() return M.now end
function UnitPowerType(unit) return (M.powerToken == "MANA") and 0 or 1, M.powerToken end
function UnitPower(unit, kind) return M.mana end
function UnitPowerMax(unit, kind) return 5000 end
function PlaySound() M.sounds = M.sounds + 1 end
SOUNDKIT = { READY_CHECK = 1 }
SlashCmdList = {}
Enum = { PowerType = { Mana = 0, Rage = 1 } }
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

-- C_RestrictedActions: M.restricted simula estar en instancia o combate
-- restringido. Pon M.noRestrictionApi = true para simular un cliente que
-- no expone el namespace.
C_RestrictedActions = setmetatable({}, {
    __index = function(_, key)
        if M.noRestrictionApi then return nil end
        if key == "IsRestricted" then return function() return M.restricted == true end end
        if key == "IsInRestrictedInstance" then return function() return M.restricted == true end end
        if key == "IsInRestrictedCombat" then return function() return M.restricted == true end end
        if key == "GetRestrictions" then return function() return {} end end
        return nil
    end,
})

-- Costos: spellID -> tabla de entradas, o "secret" para simular Secret Values.
M.costs = {
    [100] = { { type = 0, cost = 300 } },              -- hechizo de mana
    [200] = { { type = 1, cost = 30 } },               -- hechizo de rabia
    [300] = { { type = 0, cost = 0, costPerSec = 50 } },-- canalizacion
    [400] = "secret",                                   -- costo protegido
}

-- Un valor secreto fiel: en WoW, tocarlo desde codigo de addon es un error.
-- Si el addon hace tostring, concatena, compara o calcula con uno, los tests
-- revientan en vez de pasar por casualidad.
local function boom(what)
    return function() error(what .. " sobre un valor secreto", 2) end
end

local SECRET = setmetatable({ __isSecret = true }, {
    __name     = "secret",
    __tostring = boom("tostring"),
    __concat   = boom("concatenacion"),
    __add      = boom("aritmetica"),
    __sub      = boom("aritmetica"),
    __mul      = boom("aritmetica"),
    __div      = boom("aritmetica"),
    __mod      = boom("aritmetica"),
    __pow      = boom("aritmetica"),
    __unm      = boom("aritmetica"),
    __lt       = boom("comparacion"),
    __le       = boom("comparacion"),
    __len      = boom("longitud"),
})
M.SECRET = SECRET

-- rawget, no ==, para no disparar __eq con tablas normales.
function issecretvalue(v)
    return type(v) == "table" and rawget(v, "__isSecret") == true
end

C_Spell = {
    -- Devuelve una tabla nueva en cada llamada, como el API real: asi
    -- tests/bench.lua mide la asignacion que el addon paga de verdad.
    GetSpellPowerCost = function(spellID)
        local entry = M.costs[spellID]
        if entry == "secret" then
            return { { type = SECRET, cost = SECRET } }
        end
        if not entry then return nil end
        local copy = {}
        for i = 1, #entry do
            local e = entry[i]
            copy[i] = { type = e.type, cost = e.cost, costPerSec = e.costPerSec,
                        costPercent = e.costPercent }
        end
        return copy
    end,
}

-- Frames
local frames = {}
M.frames = frames

local Frame = {}
-- Un unico no-op compartido: devolver `function() end` aqui crearia un closure
-- por cada acceso y falsearia las mediciones de tests/bench.lua.
local function noop() end
Frame.__index = function(_, k)
    return Frame[k] or noop
end

local function newFrame(kind, name)
    local f = setmetatable({
        kind = kind, name = name, events = {}, scripts = {},
        shown = false, alpha = 1, value = 0, width = 180, height = 18,
        children = {},
    }, Frame)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end

function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:RegisterUnitEvent(e, u) self.events[e] = u end
function Frame:SetScript(s, fn) self.scripts[s] = fn end
function Frame:GetScript(s) return self.scripts[s] end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(v) self.shown = not not v end
function Frame:IsShown() return self.shown end
function Frame:SetAlpha(a) self.alpha = a end
function Frame:GetAlpha() return self.alpha end
function Frame:SetValue(v) self.value = v end
function Frame:GetValue() return self.value end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetScale(s) self.scale = s end
function Frame:GetPoint() return self.point or "CENTER", UIParent, self.relPoint or "CENTER", self.x or 0, self.y or 0 end
function Frame:SetPoint(p, rel, relP, x, y)
    if type(rel) == "table" then self.point, self.relPoint, self.x, self.y = p, relP, x, y end
end
function Frame:SetStatusBarColor(r, g, b) self.color = { r, g, b } end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
function Frame:CreateTexture() return newFrame("Texture") end
function Frame:CreateFontString() return newFrame("FontString") end
function Frame:EnableMouse(v) self.mouse = v end

function CreateFrame(kind, name, parent, template)
    return newFrame(kind, name)
end

UIParent = newFrame("Frame", "UIParent")

-- Utilidades del arnes
function M:fire(event, ...)
    for _, f in ipairs(frames) do
        local filter = f.events[event]
        if filter then
            local handler = f.scripts.OnEvent
            if handler then handler(f, event, ...) end
        end
    end
end

function M:advance(seconds, step)
    step = step or 0.05
    local left = seconds
    while left > 0 do
        local dt = math.min(step, left)
        M.now = M.now + dt
        left = left - dt
        for _, f in ipairs(frames) do
            local onUpdate = f.scripts.OnUpdate
            if onUpdate and f.shown then onUpdate(f, dt) end
        end
    end
end
