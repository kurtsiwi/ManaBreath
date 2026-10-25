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

local SECRET = setmetatable({}, { __name = "secret" })
M.SECRET = SECRET
function issecretvalue(v) return v == SECRET end

C_Spell = {
    GetSpellPowerCost = function(spellID)
        local entry = M.costs[spellID]
        if entry == "secret" then
            return { { type = SECRET, cost = SECRET } }
        end
        return entry
    end,
}

-- Frames
local frames = {}
M.frames = frames

local Frame = {}
Frame.__index = function(t, k)
    local v = Frame[k]
    if v then return v end
    -- cualquier setter desconocido es un no-op silencioso
    return function() end
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
