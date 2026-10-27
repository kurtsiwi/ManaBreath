-- API falsa de WoW, suficiente para ejercitar ManaBreath fuera del juego.
unpack = unpack or table.unpack

local M = {
    now = 1000, mana = 5000, maxMana = 5000, powerToken = "MANA",
    sounds = 0, log = {}, timers = {},
    -- Regeneracion simulada. regenSuspendedUntil permite imitar un cliente
    -- que SI aplica la regla de 5 s, para probar /mb verify contra los dos
    -- escenarios: uno coherente y uno que regenera dentro de la ventana.
    regenPerSec = 0, regenSuspendedUntil = 0,
}
_G.MOCK = M

function GetTime() return M.now end
function UnitPowerType(unit) return (M.powerToken == "MANA") and 0 or 1, M.powerToken end
function UnitPower(unit, kind) return M.mana end
function UnitPowerMax(unit, kind) return M.maxMana end
function GetPowerRegen() return M.regenPerSec, 0 end

C_Timer = {
    After = function(delay, fn)
        M.timers[#M.timers + 1] = { at = M.now + delay, fn = fn }
    end,
}
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
                        costPercent = e.costPercent,
                        hasRequiredAura = e.hasRequiredAura,
                        requiredAuraID = e.requiredAuraID }
        end
        return copy
    end,
}

-- Settings: el API del panel de opciones, en su forma de la 11.0 en adelante.
-- Lo que importa reproducir es que el valor vive en la tabla del addon, no en
-- una variable del sistema, y que el tipo declarado se respeta: si el panel
-- declara un booleano y le llega un numero, aqui revienta igual que en WoW.
M.settings = {}
M.settingsCategories = {}
M.settingsOpened = nil

Settings = {
    VarType = { Boolean = "boolean", Number = "number", String = "string" },
}

function Settings.RegisterVerticalLayoutCategory(name)
    local layout = { initializers = {} }
    function layout:AddInitializer(init)
        self.initializers[#self.initializers + 1] = init
    end

    local category = { name = name, settings = {}, layout = layout }
    function category:GetID() return "cat:" .. self.name end

    M.settingsCategories[#M.settingsCategories + 1] = category
    return category, layout
end

function Settings.RegisterAddOnSetting(category, variable, key, tbl, varType, name, default)
    assert(type(category) == "table", "categoria invalida")
    assert(type(variable) == "string", "variable invalida")
    assert(type(key) == "string", "clave invalida")
    assert(type(tbl) == "table", "tabla invalida")
    assert(varType == "boolean" or varType == "number" or varType == "string",
        "tipo invalido: " .. tostring(varType))
    assert(type(name) == "string", "nombre invalido")
    assert(type(default) == varType,
        ("el defecto de %s no es %s"):format(variable, varType))

    local setting = {
        variable = variable, key = key, tbl = tbl,
        varType = varType, name = name, default = default,
    }

    function setting:GetValue() return self.tbl[self.key] end

    function setting:SetValue(value)
        assert(type(value) == self.varType,
            ("%s espera %s"):format(self.variable, self.varType))
        self.tbl[self.key] = value
        if self.callback then self.callback(self.variable, self, value) end
    end

    M.settings[variable] = setting
    category.settings[variable] = setting
    return setting
end

function Settings.SetOnValueChangedCallback(variable, fn)
    local setting = M.settings[variable]
    assert(setting, "variable sin registrar: " .. tostring(variable))
    setting.callback = fn
end

function Settings.CreateCheckbox(category, setting, tooltip)
    setting.control, setting.tooltip = "checkbox", tooltip
end

function Settings.CreateSlider(category, setting, options, tooltip)
    setting.control, setting.tooltip = "slider", tooltip
    setting.sliderOptions = options
end

function Settings.CreateDropdown(category, setting, getOptions, tooltip)
    setting.control, setting.tooltip = "dropdown", tooltip
    setting.choices = getOptions()
end

function Settings.CreateSliderOptions(minValue, maxValue, step)
    local o = { min = minValue, max = maxValue, step = step }
    function o:SetLabelFormatter(where, fn) self.formatter = fn end
    return o
end

function Settings.CreateControlTextContainer()
    local c = { data = {} }
    function c:Add(value, label, tooltip)
        self.data[#self.data + 1] = { value = value, label = label, tooltip = tooltip }
    end
    function c:GetData() return self.data end
    return c
end

function Settings.RegisterAddOnCategory(category)
    category.registered = true
end

function Settings.OpenToCategory(id)
    M.settingsOpened = id
end

MinimalSliderWithSteppersMixin = { Label = { Right = 2 } }

function CreateSettingsListSectionHeaderInitializer(text)
    return { kind = "header", text = text }
end

-- El quinto argumento (addSearchTags) hace que el boton salga en el buscador
-- del panel de opciones. Se declara para que la firma sea la de verdad.
function CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, addSearchTags)
    return { kind = "button", name = name, text = buttonText, click = onClick,
             tooltip = tooltip, searchTags = addSearchTags }
end

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
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetScale(s) self.scale = s end
function Frame:GetPoint() return self.point or "CENTER", UIParent, self.relPoint or "CENTER", self.x or 0, self.y or 0 end
function Frame:SetPoint(p, rel, relP, x, y)
    if type(rel) == "table" then self.point, self.relPoint, self.x, self.y = p, relP, x, y end
end
-- Estos tres se llaman desde el OnUpdate, asi que reutilizan la tabla: si
-- asignaran una nueva, tests/bench.lua estaria midiendo la basura del mock.
local function store(frame, key, ...)
    -- rawget: el __index del mock devuelve un no-op para las claves que no
    -- existen, asi que un frame[key] pelado nunca daria nil.
    local t = rawget(frame, key)
    if not t then t = {}; frame[key] = t end
    for i = 1, select("#", ...) do t[i] = (select(i, ...)) end
    return t
end

function Frame:SetStatusBarColor(r, g, b) store(self, "color", r, g, b) end
function Frame:SetVertexColor(r, g, b) store(self, "color", r, g, b) end
function Frame:SetTexCoord(l, r, t, b) store(self, "coord", l, r, t, b) end
function Frame:GetFont() return "Fonts/FRIZQT__.TTF", 10, "" end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
function Frame:CreateTexture() return newFrame("Texture") end
function Frame:CreateMaskTexture() return newFrame("MaskTexture") end
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

        if M.regenPerSec > 0 and M.now >= M.regenSuspendedUntil
            and type(M.mana) == "number" then
            M.mana = math.min(M.maxMana, M.mana + M.regenPerSec * dt)
        end

        for _, f in ipairs(frames) do
            local onUpdate = f.scripts.OnUpdate
            if onUpdate and f.shown then onUpdate(f, dt) end
        end

        -- Temporizadores vencidos, en orden.
        local i = 1
        while i <= #M.timers do
            local t = M.timers[i]
            if M.now >= t.at then
                table.remove(M.timers, i)
                t.fn()
            else
                i = i + 1
            end
        end
    end
end
