-- Cuenta llamadas al API de WoW por frame en cada fase del matraz.
-- Uso: lua tests/profile.lua
--
-- tests/bench.lua responde "cuanta memoria"; esto responde "cuanto trabajo".
-- Son preguntas distintas: una animacion puede no asignar un solo byte y estar
-- llamando al API cuarenta veces por frame, que es trabajo real del cliente.
local SP = (arg[0] or "tests/profile.lua"):match("^(.*)[/\\][^/\\]+$") or "."
local REPO = SP .. "/.."
dofile(SP .. "/mock_wow.lua")

local counts, counting = {}, false
local function bump(name)
    if counting then counts[name] = (counts[name] or 0) + 1 end
end

-- Los globales del API tambien cuentan: GetTime no es gratis.
local realGetTime = GetTime
GetTime = function() bump("GetTime") return realGetTime() end
local realUnitPower = UnitPower
UnitPower = function(...) bump("UnitPower") return realUnitPower(...) end
local realUnitPowerMax = UnitPowerMax
UnitPowerMax = function(...) bump("UnitPowerMax") return realUnitPowerMax(...) end

local ns = {}
for _, file in ipairs({ "Core.lua", "Display.lua", "Verify.lua", "Commands.lua", "Options.lua" }) do
    assert(loadfile(REPO .. "/" .. file))("ManaBreath", ns)
end
local MB, D = ns.addon, ns.display

MOCK:fire("ADDON_LOADED", "ManaBreath")
MOCK:fire("PLAYER_LOGIN")

local METHODS = {
    "SetPoint", "ClearAllPoints", "SetAlpha", "GetAlpha", "Show", "Hide",
    "SetShown", "SetHeight", "SetWidth", "SetSize", "SetTexCoord",
    "SetVertexColor", "SetTextColor", "SetText", "SetFont", "GetFont", "SetTexture",
    "SetScript", "SetDrawLayer", "SetBlendMode",
}

-- Envoltorio por objeto: el __index del mock solo se consulta cuando la clave
-- no esta en la instancia, asi que asignarla aqui intercepta la llamada sin
-- tocar el mock ni el addon.
local function instrument(obj)
    if type(obj) ~= "table" then return end
    local index = getmetatable(obj).__index
    for _, name in ipairs(METHODS) do
        local real = index(obj, name)
        obj[name] = function(self, ...)
            bump(name)
            return real(self, ...)
        end
    end
end

instrument(D.frame)
for _, key in ipairs({ "liquid", "wave1", "wave2", "glow", "glass", "timeText",
                       "label", "barBorder", "barTrack", "barFill", "barSpark",
                       "rateText" }) do
    instrument(D[key])
end
for i = 1, #D.bubbles do instrument(D.bubbles[i]) end

local FRAME = 1 / 60

local function report(label, frames)
    local total, lines = 0, {}
    for name, n in pairs(counts) do
        total = total + n
        if n / frames >= 0.05 then
            lines[#lines + 1] = ("%s=%.1f"):format(name, n / frames)
        end
    end
    table.sort(lines)
    print(("  %-34s %5.1f llamadas/frame   %s")
        :format(label, total / frames, table.concat(lines, " ")))
end

local function phase(label, frames, setup)
    setup()
    counts, counting = {}, true
    MOCK:advance(frames * FRAME, FRAME)
    counting = false
    report(label, frames)
end

-- Un castGUID nuevo en cada llamada: repetirlo lo descarta la deduplicacion
-- del addon y la fase no arrancaria, que es justo lo que paso al escribir esto.
local casts = 0
local function castAndSettle(mana, seconds)
    MB:Cancel()
    MOCK.mana = mana
    MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
    casts = casts + 1
    MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "prof-" .. casts, 100)
    assert(MB:IsActive(), "la regla no arranco")
    if seconds then MOCK:advance(seconds, FRAME) end
end

print("== llamadas al API por frame ==")

phase("fase azul (regla corriendo)", 60, function()
    castAndSettle(5000)
end)

phase("fase verde (estable)", 60, function()
    -- 6.5 s: regla, aguante y el tiempo que el liquido tarda en bajar al mana.
    castAndSettle(2000, 6.5)
    assert(D.state == "regen", D.state)
end)

phase("fase verde (con un tick)", 120, function()
    castAndSettle(2000, 6.5)
    MOCK.mana = MOCK.mana + 150
    MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
end)

-- La otra piel, sobre el mismo motor. Sin matraz no hay olas, ni burbujas, ni
-- halo: no queda nada que animar a 30 Hz y lo unico que se mueve por frame es
-- el contador. Si estas dos lineas no salen claramente por debajo de las de
-- arriba, es que algo del matraz sigue dibujandose en modo texto.
ManaBreathDB.style = "text"
D:ApplySettings()

phase("texto (regla corriendo)", 60, function()
    castAndSettle(5000)
end)

phase("texto (fase verde, con un tick)", 120, function()
    castAndSettle(2000, 6.5)
    assert(D.state == "regen", D.state)
    MOCK.mana = MOCK.mana + 150
    MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
end)

-- Y la tercera. Tampoco tiene nada que animar a 30 Hz, y ademas el destello
-- va colgado del borde derecho del relleno, asi que lo unico que se mueve por
-- frame es un SetWidth. Si estas dos lineas se acercan a las del matraz, es
-- que algo esta recolocando el destello en vez de dejar que lo arrastre.
ManaBreathDB.style = "bar"
D:ApplySettings()

phase("barra (regla corriendo)", 60, function()
    castAndSettle(5000)
end)

phase("barra (fase verde, con un tick)", 120, function()
    castAndSettle(2000, 6.5)
    assert(D.state == "regen", D.state)
    MOCK.mana = MOCK.mana + 150
    MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
end)

ManaBreathDB.style = "flask"
D:ApplySettings()

MB:Cancel()
ManaBreathDB.alwaysShow = true
D:UpdateShown()
counts, counting = {}, true
MOCK:advance(60 * FRAME, FRAME)
counting = false
report("en reposo, matraz visible", 60)
assert(D.frame:GetScript("OnUpdate") == nil, "el OnUpdate sigue instalado en reposo")
print("\n  en reposo el OnUpdate no esta instalado: cero llamadas, no pocas.")
