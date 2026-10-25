-- Pruebas de ManaBreath contra una API falsa de WoW.
-- Uso: lua tests/run.lua   (desde cualquier carpeta)
local SP = (arg[0] or "tests/run.lua"):match("^(.*)[/\\][^/\\]+$") or "."
local REPO = SP .. "/.."
dofile(SP .. "/mock_wow.lua")

local fails, passes = 0, 0
local function check(label, got, want)
    if got == want then
        passes = passes + 1
        print(("  ok   %-46s %s"):format(label, tostring(got)))
    else
        fails = fails + 1
        print(("  FAIL %-46s got=%s want=%s"):format(label, tostring(got), tostring(want)))
    end
end

-- Carga el addon como lo haria WoW: cada archivo recibe (nombre, tabla compartida)
local ns = {}
for _, file in ipairs({ "Core.lua", "Display.lua", "Verify.lua", "Commands.lua" }) do
    assert(loadfile(REPO .. "/" .. file))("ManaBreath", ns)
end
local MB = ns.addon
local D = ns.display

MOCK:fire("ADDON_LOADED", "OtroAddon")
check("DB no se crea con otro addon", ManaBreathDB, nil)

MOCK:fire("ADDON_LOADED", "ManaBreath")
MOCK:fire("PLAYER_LOGIN")
check("DB inicializada", type(ManaBreathDB), "table")
check("frame creado", D.frame ~= nil, true)
check("oculto al inicio", D.frame:IsShown(), false)

print("\n-- hechizo con costo de mana --")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 100)
check("regla activa", MB:IsActive(), true)
check("restante = 5s", MB:Remaining(), 5.0)
check("barra visible", D.frame:IsShown(), true)
check("estado", D.state, "active")

MOCK:advance(2)
check("barra llenandose", D.bar:GetValue() > 1.9 and D.bar:GetValue() < 2.1, true)

print("\n-- reinicio dentro de los 5s --")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 100)
check("contador reiniciado", MB:Remaining(), 5.0)

print("\n-- fin de la regla --")
MOCK:advance(5.2)
check("regla terminada", MB:IsActive(), false)
check("estado done", D.state, "done")
check("barra llena", D.bar:GetValue(), MB.RULE_DURATION)
check("color verde", D.bar.color[2] > D.bar.color[3], true)
check("sin sonido (opcion off)", MOCK.sounds, 0)

MOCK:advance(2)
check("vuelve a idle", D.state, "idle")
check("oculta de nuevo", D.frame:IsShown(), false)

print("\n-- hechizo sin mana (rabia) --")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-3", 200)
check("no activa la regla", MB:IsActive(), false)

print("\n-- canalizacion --")
MOCK:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-4", 300)
check("arranca al empezar el canal", MB:IsActive(), true)
MOCK:advance(3)
check("restante ~2s", math.floor(MB:Remaining() * 10 + 0.5) / 10, 2.0)
MOCK:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-4", 300)
check("reinicia al cortar el canal", MB:Remaining(), 5.0)
MB:Cancel()

print("\n-- costo protegido (Secret Value) --")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-5", 400)
check("espera confirmacion", MB:IsActive(), false)
MOCK.mana = MOCK.mana - 300
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
check("confirmado por bajada de mana", MB:IsActive(), true)
MB:Cancel()

print("\n-- costo protegido, sin bajada de mana --")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-6", 400)
MOCK:advance(1)
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
check("fuera de la ventana: no activa", MB:IsActive(), false)

print("\n-- mana secreto no rompe nada --")
local realMana = MOCK.mana
MOCK.mana = MOCK.SECRET
local ok = pcall(function()
    MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
    MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-7", 100)
end)
check("sin error con valor secreto", ok, true)
MOCK.mana = realMana
MB:Cancel()

print("\n-- respaldo por mana desactivado / activado --")
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK.mana = MOCK.mana - 100
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
check("respaldo off: ignora la bajada", MB:IsActive(), false)
ManaBreathDB.powerFallback = true
MOCK.mana = MOCK.mana - 100
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
check("respaldo on: activa la regla", MB:IsActive(), true)
ManaBreathDB.powerFallback = false
MB:Cancel()

print("\n-- clase/forma sin mana --")
MOCK.powerToken = "RAGE"
MOCK:fire("UNIT_DISPLAYPOWER", "player")
check("no usa mana", MB:UsesMana(), false)
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-8", 100)
check("no arranca en forma sin mana", MB:IsActive(), false)
MOCK.powerToken = "MANA"
MOCK:fire("UNIT_DISPLAYPOWER", "player")

print("\n-- slash commands --")
local slash = SlashCmdList["MANABREATH"]
check("slash registrado", type(slash), "function")
check("alias /mb", SLASH_MANABREATH2, "/mb")
slash("unlock")
check("desbloqueada", ManaBreathDB.locked, false)
check("visible al desbloquear", D.frame:IsShown(), true)
check("mouse activo", D.frame.mouse, true)
slash("lock")
check("bloqueada", ManaBreathDB.locked, true)
check("oculta al bloquear", D.frame:IsShown(), false)
slash("scale 1.5")
check("escala", ManaBreathDB.scale, 1.5)
slash("scale 99")
check("escala invalida rechazada", ManaBreathDB.scale, 1.5)
slash("size 240 22")
check("ancho", ManaBreathDB.width, 240)
check("alto", ManaBreathDB.height, 22)
slash("sound on")
check("sonido on", ManaBreathDB.sound, true)
slash("test")
check("demo activa", MB:IsActive(), true)
MOCK:advance(5.2)
check("suena al terminar", MOCK.sounds, 1)
slash("always on")
check("mostrar siempre", ManaBreathDB.alwaysShow, true)
MOCK:advance(2)
check("sigue visible con always", D.frame:IsShown(), true)
slash("status")
slash("reset")
check("reset restaura escala", ManaBreathDB.scale, 1)
check("reset restaura always", ManaBreathDB.alwaysShow, false)
slash("comando-inexistente")
slash("")

print("\n-- castGUID: no procesar dos veces el mismo casteo --")
-- Una canalizacion dispara SUCCEEDED y CHANNEL_START con el mismo castGUID.
local realStart, starts = MB.Start, 0
MB.Start = function(self, ...) starts = starts + 1 return realStart(self, ...) end
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-canal", 300)
MOCK:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-canal", 300)
check("un solo arranque por castGUID", starts, 1)
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-otro", 100)
check("un castGUID nuevo si arranca", starts, 2)
MB.Start = realStart
MB:Cancel()

print("\n-- contexto restringido (C_RestrictedActions) --")
MOCK.restricted = false
MOCK:fire("PLAYER_ENTERING_WORLD")
check("api disponible", MB.restrictionApi, true)
check("fuera de instancia", MB.restricted, false)
MOCK.restricted = true
MOCK:fire("ZONE_CHANGED_NEW_AREA")
check("dentro de instancia", MB.restricted, true)
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-rest", 100)
check("la deteccion sigue funcionando", MB:IsActive(), true)
MB:Cancel()
MOCK.restricted = false

print("\n-- cliente sin C_RestrictedActions --")
MOCK.noRestrictionApi = true
MB:UpdateRestrictionState()
check("no rompe nada", MB.restrictionApi, false)
check("restringido = false", MB.restricted, false)
MOCK.noRestrictionApi = false
MOCK:fire("PLAYER_ENTERING_WORLD")
check("se recupera la api", MB.restrictionApi, true)

print("\n-- eficiencia: OnUpdate solo cuando hay algo que animar --")
MB:Cancel()
check("en reposo no hay OnUpdate", D.frame:GetScript("OnUpdate"), nil)
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-upd", 100)
check("activa instala OnUpdate", type(D.frame:GetScript("OnUpdate")), "function")
MOCK:advance(6.5)
check("tras el fundido se desinstala", D.frame:GetScript("OnUpdate"), nil)

ManaBreathDB.alwaysShow = true
D:UpdateShown()
check("barra siempre visible pero en reposo", D.frame:IsShown(), true)
check("y sin OnUpdate: cero coste por frame", D.frame:GetScript("OnUpdate"), nil)
ManaBreathDB.alwaysShow = false
D:UpdateShown()

print("\n-- el contador muestra decimas sin asignar cadenas --")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-txt", 100)
MOCK:advance(0.5, 1 / 60)
check("texto a los 0.5 s", D.timeText:GetText(), "4.5")
MOCK:advance(2.0, 1 / 60)
check("texto a los 2.5 s", D.timeText:GetText(), "2.5")
MOCK:advance(3.0, 1 / 60)
check("texto al terminar", D.timeText:GetText(), "regen")
MB:Cancel()

print("\n-- un spellID secreto no se puede tocar --")
-- El mock hace que tostring, concatenar, comparar o calcular con un valor
-- secreto lance error, igual que WoW. Esto cubre el caso de la checklist:
-- que UNIT_SPELLCAST_SUCCEEDED entregue el spellID protegido en combate.
ManaBreathDB.debug = nil
local okSecret = pcall(function()
    MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-sec1", MOCK.SECRET)
end)
check("spellID secreto, debug off", okSecret, true)
check("sin coste legible no arranca sola", MB:IsActive(), false)

ManaBreathDB.debug = true
okSecret = pcall(function()
    MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-sec2", MOCK.SECRET)
end)
check("spellID secreto, debug on", okSecret, true)
ManaBreathDB.debug = nil

-- Y sigue detectando por la bajada de mana.
MOCK.mana = MOCK.mana - 200
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
check("confirmado por el mana aun con spellID secreto", MB:IsActive(), true)
MB:Cancel()

print("\n-- ventana simetrica: el orden de los eventos no importa --")
-- Orden A: primero el casteo, luego la bajada de mana.
MB:Cancel()
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "ord-a", MOCK.SECRET)
check("tras el casteo no arranca sola", MB:IsActive(), false)
MOCK.mana = MOCK.mana - 150
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
check("casteo y luego mana", MB:IsActive(), true)

-- Orden B: primero la bajada de mana, luego el casteo. Este era el caso que
-- no confirmaba nunca cuando la ventana iba en un solo sentido.
MB:Cancel()
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK.mana = MOCK.mana - 150
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "ord-b", MOCK.SECRET)
check("mana y luego casteo", MB:IsActive(), true)

-- Fuera de la ventana no se reclama una bajada vieja.
MB:Cancel()
MOCK.mana = MOCK.mana - 150
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK:advance(1.0)
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "ord-c", MOCK.SECRET)
check("una bajada vieja no cuenta", MB:IsActive(), false)
MB:Cancel()

print("\n-- hasRequiredAura: coste condicionado no es un si seguro --")
MOCK.costs[500] = { { type = 0, cost = 400, hasRequiredAura = true } }
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "aura-1", 500)
check("coste condicionado no arranca sola", MB:IsActive(), false)
MOCK.mana = MOCK.mana - 400
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
check("pero si el mana baja, arranca", MB:IsActive(), true)
MB:Cancel()

-- Y un hechizo gratis con coste base condicionado no debe arrancar nada.
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "aura-2", 500)
MOCK:advance(1.0)
check("hechizo gratis no arranca la regla", MB:IsActive(), false)
MB:Cancel()

print("\n-- reinicio de canalizacion configurable --")
ManaBreathDB.channelRestart = true
MOCK:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "can-1", 300)
MOCK:advance(3)
MOCK:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "can-1", 300)
check("con channel on reinicia", MB:Remaining(), 5.0)
MB:Cancel()

ManaBreathDB.channelRestart = false
MOCK:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "can-2", 300)
MOCK:advance(3)
MOCK:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "can-2", 300)
check("con channel off no reinicia", math.floor(MB:Remaining() * 10 + 0.5) / 10, 2.0)
ManaBreathDB.channelRestart = true
MB:Cancel()

print("\n-- /mb verify mide la regla contra el cliente --")
local said = {}
local realPrint = MB.Print
MB.Print = function(self, ...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    said[#said + 1] = table.concat(parts, " ")
end
local function saidMatch(pat)
    for _, line in ipairs(said) do if line:find(pat, 1, true) then return true end end
    return false
end

-- Cliente que SI aplica la regla: no regenera durante los 5 s.
said = {}
MOCK.mana = 2000
MOCK.regenPerSec = 50
MOCK.regenSuspendedUntil = 0
slash("verify")
check("verify se arma", MB.verifyArmed, true)
MOCK.regenSuspendedUntil = MOCK.now + 5
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "ver-1", 100)
check("al castear se desarma", MB.verifyArmed, false)
MOCK:advance(8, 1 / 60)
check("veredicto coherente", saidMatch("coherente"), true)

-- Cliente que NO aplica la regla: regenera todo el tiempo.
said = {}
MB:Cancel()
MOCK.mana = 2000
MOCK.regenSuspendedUntil = 0
slash("verify")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "ver-2", 100)
MOCK:advance(8, 1 / 60)
check("veredicto incoherente", saidMatch("incoherente"), true)

MOCK.regenPerSec = 0
MB.Print = realPrint
MB:Cancel()

print("\n-- coste nil = sin coste, no = ilegible --")
-- El API devuelve nil para un hechizo sin coste de recursos. Tratarlo como
-- "unknown" armaba la ventana de confirmacion, y entonces un instantaneo
-- gratis lanzado justo despues de un gasto real reclamaba esa bajada de mana.
-- Solo era peligroso desde que la ventana es simetrica.
MB:Cancel()
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK.mana = MOCK.mana - 300
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "gratis-1", 999)
check("un instantaneo gratis no reclama la bajada", MB:IsActive(), false)
MB:Cancel()

print("\n-- se sabe de donde se leen los costes --")
check("costApi detectado", MB.costApi, "C_Spell.GetSpellPowerCost")

print(("\n%d ok, %d fallos"):format(passes, fails))
os.exit(fails == 0 and 0 or 1)
