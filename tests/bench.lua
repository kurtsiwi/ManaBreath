-- Mide la huella de memoria de ManaBreath fuera del juego.
-- Uso: lua tests/bench.lua
local SP = (arg[0] or "tests/bench.lua"):match("^(.*)[/\\]+[^/\\]+$") or "."
local REPO = SP .. "/.."

local function settle()
    for _ = 1, 4 do collectgarbage("collect") end
    return collectgarbage("count")
end

local function kb(n) return ("%.2f KB"):format(n) end

local function measure(label, iterations, fn)
    local before = settle()
    fn()
    local after = collectgarbage("count")
    local total = after - before
    local per = total / iterations
    print(("  %-44s %10s   %s"):format(label, kb(total), per > 0.0005
        and ("%.3f KB x %d"):format(per, iterations) or "sin basura medible"))
    return total
end

print("== huella estatica ==")
local base = settle()
dofile(SP .. "/mock_wow.lua")
local afterMock = settle()

local ns = {}
for _, file in ipairs({ "Core.lua", "Display.lua", "Verify.lua", "Commands.lua" }) do
    assert(loadfile(REPO .. "/" .. file))("ManaBreath", ns)
end
local MB, D = ns.addon, ns.display
MOCK:fire("ADDON_LOADED", "ManaBreath")
MOCK:fire("PLAYER_LOGIN")
local loaded = settle()

print(("  mock de la API de WoW (no cuenta)        %10s"):format(kb(afterMock - base)))
print(("  addon cargado y inicializado             %10s"):format(kb(loaded - afterMock)))

print("")
print("== basura en caliente ==")

-- Ciclos completos de la regla a 60 fps: 5 s de barra + fundido. Se miden
-- 20 seguidos porque uno solo queda por debajo del ruido de collectgarbage.
local FRAME = 1 / 60
measure("20 ciclos completos de 5 s a 60 fps", 20, function()
    for _ = 1, 20 do
        MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "bench-ciclo", 100)
        MB.lastCastGUID = nil
        MOCK:advance(6.5, FRAME)
    end
end)

measure("600 frames de barra activa", 600, function()
    MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "bench-2", 100)
    MOCK:advance(600 * FRAME, FRAME)
    MB:Cancel()
end)

-- Los castGUID se construyen ANTES de medir: concatenar dentro del bucle
-- medido asignaria una cadena por iteracion y lo que se veria seria la
-- basura del propio banco, no la del addon.
local guids = {}
for i = 1, 1000 do guids[i] = "bench-c" .. i end

measure("1000 casteos con coste de mana", 1000, function()
    for i = 1, 1000 do
        MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", guids[i], 100)
    end
    MB:Cancel()
end)

measure("1000 casteos sin coste de mana", 1000, function()
    for i = 1, 1000 do
        MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", guids[i], 200)
    end
end)

measure("1000 UNIT_POWER_UPDATE", 1000, function()
    for i = 1, 1000 do
        MOCK.mana = 5000 - (i % 500)
        MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
    end
end)

measure("10 s en reposo (barra oculta)", 1, function()
    MB:Cancel()
    MOCK:advance(10, FRAME)
end)

print("")
print("== fuga de memoria ==")

-- La pregunta que importa en una sesion de varias horas: tras mucho trabajo y
-- un recolectado completo, la memoria vuelve a donde estaba o crece?
guids = nil
local settled = settle()

for round = 1, 200 do
    MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "leak-a", 100)
    MB.lastCastGUID = nil
    MOCK:advance(6.5, FRAME)
    MOCK:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "leak-b", 300)
    MOCK:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "leak-b", 300)
    MB.lastCastGUID = nil
    for _ = 1, 10 do
        MOCK.mana = 5000 - (round % 400)
        MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
    end
    MB:Cancel()
end

local afterWork = settle()
local drift = afterWork - settled
print(("  200 ciclos + 400 casteos + 2000 UNIT_POWER_UPDATE"))
print(("  deriva tras recolectado completo:        %10s   %s")
    :format(kb(drift), math.abs(drift) < 1 and "sin fuga" or "REVISAR"))
