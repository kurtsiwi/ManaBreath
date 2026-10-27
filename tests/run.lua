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
for _, file in ipairs({ "Core.lua", "Display.lua", "Verify.lua", "Commands.lua", "Options.lua" }) do
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
check("mascara del matraz creada", D.masked, true)
check("oculto al inicio", D.frame:IsShown(), false)

print("\n-- hechizo con costo de mana --")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 100)
check("regla activa", MB:IsActive(), true)
check("restante = 5s", MB:Remaining(), 5.0)
check("matraz visible", D.frame:IsShown(), true)
check("estado", D.state, "active")
check("sin brillo mientras corre la regla", D.glow:IsShown(), false)

MOCK:advance(2)
check("matraz llenandose", D.fill > 0.39 and D.fill < 0.41, true)
check("burbujas subiendo", D.bubbles[1]:IsShown(), true)

print("\n-- reinicio dentro de los 5s --")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 100)
check("contador reiniciado", MB:Remaining(), 5.0)

print("\n-- fin de la regla --")
MOCK:advance(5.2)
check("regla terminada", MB:IsActive(), false)
check("estado done", D.state, "done")
check("matraz lleno", D.fill, 1)
check("liquido verde", D.liquid.color[2] > D.liquid.color[3], true)
check("brilla al volver la regeneracion", D.glow:IsShown(), true)
check("sin sonido (opcion off)", MOCK.sounds, 0)

MOCK:advance(2)
check("vuelve a idle", D.state, "idle")
check("oculto de nuevo", D.frame:IsShown(), false)
check("brillo apagado en reposo", D.glow:IsShown(), false)

print("\n-- con el mana lleno no hay fase de regeneracion --")
-- No hay ticks que ensenar, asi que el matraz se apaga como siempre.
check("mana lleno", MB:GetManaFraction(), 1)
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-full", 100)
MOCK:advance(6.5)
check("se apaga tras el aviso", D.state, "idle")

print("\n-- fase de regeneracion: el matraz sigue el mana que vuelve --")
MOCK.mana = 2000
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-regen", 100)
MOCK:advance(5.9)
check("estado regen tras el aguante", D.state, "regen")
check("sigue visible", D.frame:IsShown(), true)
check("brilla mientras el mana vuelve", D.glow:IsShown(), true)
check("el porcentaje sustituye al contador", D.timeText:GetText(), "40%")
MOCK:advance(1)
check("el liquido baja hasta el mana real", D.fill > 0.35 and D.fill < 0.45, true)

MOCK.mana = 2500
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK:advance(0.5)
check("un tick sube el porcentaje", D.timeText:GetText(), "50%")
check("y el liquido con el", D.fill > 0.45, true)

MOCK:advance(3.0)
check("con el tick reciente sigue encendido", D.state, "regen")
MOCK:advance(1.5)
check("sin ticks la fase se cierra sola", D.state, "idle")
check("y deja de costar por frame", D.frame:GetScript("OnUpdate"), nil)

print("\n-- el mana lleno cierra la fase --")
MOCK.mana = 2000
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-full2", 100)
MOCK:advance(5.9)
check("en regen", D.state, "regen")
MOCK.mana = MOCK.maxMana
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
check("al llenarse se apaga", D.state, "fading")
check("y queda lleno", D.fill, 1)
check("marcando el 100%", D.timeText:GetText(), "100%")
MOCK:advance(1)
check("vuelve a idle", D.state, "idle")

print("\n-- salir de combate cierra la fase --")
MOCK.mana = 2000
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-combat", 100)
MOCK:advance(5.9)
check("en regen", D.state, "regen")
MOCK:fire("PLAYER_REGEN_ENABLED")
check("al salir de combate se apaga", D.state, "fading")
MOCK:advance(1)
check("vuelve a idle", D.state, "idle")

print("\n-- volver a gastar mana devuelve el matraz a la regla --")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-r1", 100)
MOCK:advance(5.9)
check("en regen", D.state, "regen")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-r2", 100)
check("vuelve a active", D.state, "active")
check("liquido azul otra vez", D.liquid.color[3] > D.liquid.color[2], true)
MOCK:advance(0.1)
check("y el contador de nuevo", D.timeText:GetText(), "4.9")
MB:Cancel()
MOCK.mana = MOCK.maxMana
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")

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
slash("glow rule")
check("modo de brillo", ManaBreathDB.glow, "rule")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-glow", 100)
check("con rule brilla durante la regla", D.glow:IsShown(), true)
MOCK:advance(5.2)
check("y se apaga al acabar", D.glow:IsShown(), false)
MB:Cancel()
slash("glow off")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-glow2", 100)
MOCK:advance(5.2)
check("con off no brilla nunca", D.glow:IsShown(), false)
MB:Cancel()
slash("glow loquesea")
check("modo invalido rechazado", ManaBreathDB.glow, "off")
slash("glow regen")
check("vuelve a regen", ManaBreathDB.glow, "regen")

slash("regen off")
check("seguimiento apagado", ManaBreathDB.holdRegen, false)
MOCK.mana = 2000
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-noregen", 100)
MOCK:advance(6.5)
check("con regen off se apaga tras la regla", D.state, "idle")
slash("regen on")
check("seguimiento encendido", ManaBreathDB.holdRegen, true)
-- Y apagarlo en mitad de la fase la corta en el momento.
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-cut", 100)
MOCK:advance(5.9)
check("en regen", D.state, "regen")
slash("regen off")
check("apagarlo corta la fase", D.state, "fading")
slash("regen on")
MB:Cancel()
MOCK.mana = MOCK.maxMana
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")

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

print("\n-- panel de opciones --")
local O = ns.options
check("panel construido", O.category ~= nil, true)
check("sin errores al construirlo", O.failed, nil)
check("categoria registrada en Ajustes", O.category.registered, true)

local declared = 0
for _ in pairs(O.settings) do declared = declared + 1 end
check("opciones declaradas", declared, 10)

-- Lo que importa de la forma moderna del API: el valor no vive en una variable
-- del sistema, vive en ManaBreathDB. Si no, el panel y /mb serian dos verdades.
check("el valor vive en ManaBreathDB", MOCK.settings.MANABREATH_SOUND.tbl, ManaBreathDB)
check("el defecto sale de MB.defaults", MOCK.settings.MANABREATH_LOCKED.default, true)
check("la escala es un deslizador", MOCK.settings.MANABREATH_SCALE.control, "slider")
check("de 0.5 a 3", MOCK.settings.MANABREATH_SCALE.sliderOptions.max, 3)
check("el brillo es un desplegable", MOCK.settings.MANABREATH_GLOW.control, "dropdown")
check("con los tres modos", #MOCK.settings.MANABREATH_GLOW.choices, 3)

-- Marcar una casilla tiene que escribir en la DB y aplicarse al momento.
MOCK.settings.MANABREATH_ALWAYSSHOW:SetValue(true)
check("marcarla escribe en la DB", ManaBreathDB.alwaysShow, true)
check("y se aplica sin /reload", D.frame:IsShown(), true)
MOCK.settings.MANABREATH_ALWAYSSHOW:SetValue(false)
check("desmarcarla tambien", D.frame:IsShown(), false)

-- Cambiar el brillo a mitad de ciclo se nota ya, no en el siguiente.
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "opt-glow", 100)
check("con regen no brilla durante la regla", D.glow:IsShown(), false)
MOCK.settings.MANABREATH_GLOW:SetValue("rule")
check("pasarlo a rule se nota en caliente", D.glow:IsShown(), true)
MOCK.settings.MANABREATH_GLOW:SetValue("regen")
check("y volver atras tambien", D.glow:IsShown(), false)
MB:Cancel()

-- Apagar el seguimiento desde el panel corta la fase abierta.
MOCK.mana = 2000
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "opt-regen", 100)
MOCK:advance(5.9)
check("en regen", D.state, "regen")
MOCK.settings.MANABREATH_HOLDREGEN:SetValue(false)
check("apagarlo desde el panel corta la fase", D.state, "fading")
MOCK.settings.MANABREATH_HOLDREGEN:SetValue(true)
MB:Cancel()
MOCK.mana = MOCK.maxMana
MOCK:fire("UNIT_POWER_UPDATE", "player", "MANA")

-- Y al reves: un /mb tiene que dejar el panel al dia.
slash("glow off")
check("un comando actualiza el panel", MOCK.settings.MANABREATH_GLOW:GetValue(), "off")
slash("glow regen")

MOCK.settingsOpened = nil
slash("config")
check("/mb config abre el panel", MOCK.settingsOpened, O.category:GetID())
MOCK.settingsOpened = nil
ManaBreath_OnAddonCompartmentClick()
check("el boton del compartimento tambien", MOCK.settingsOpened, O.category:GetID())

print("\n-- el panel es un extra: sin el, el addon entero sigue --")
-- Copia solo los metodos: asi Init() arranca de cero sin heredar la categoria
-- que ya se construyo arriba.
local function probe()
    local p = {}
    for key, value in pairs(O) do
        if type(value) == "function" then p[key] = value end
    end
    return p
end

local realSettings = Settings
Settings = nil
local sinApi = probe()
sinApi:Init()
check("sin API de Ajustes no revienta", sinApi.failed ~= nil, true)
check("y no deja panel a medias", sinApi.category, nil)
check("abrirlo avisa en vez de fallar", sinApi:Open(), false)
Settings = realSettings

-- Un cliente con un API de otra forma: lo que no puede pasar es que el error
-- suba y se lleve por delante el ADDON_LOADED del addon.
local realRegister = Settings.RegisterAddOnSetting
Settings.RegisterAddOnSetting = function() error("otra firma") end
local otraFirma = probe()
otraFirma:Init()
check("una firma distinta degrada", otraFirma.category, nil)
check("y queda el motivo apuntado", otraFirma.failed ~= nil, true)
Settings.RegisterAddOnSetting = realRegister

check("el matraz sigue funcionando sin panel", (function()
    MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "opt-sin-panel", 100)
    local ok = MB:IsActive() and D.frame:IsShown()
    MB:Cancel()
    return ok
end)(), true)

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
-- La ruta corta: sin seguimiento, el matraz se apaga en cuanto acaba la regla.
-- La larga tiene su propia seccion mas arriba.
ManaBreathDB.holdRegen = false
check("en reposo no hay OnUpdate", D.frame:GetScript("OnUpdate"), nil)
MOCK:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-upd", 100)
check("activa instala OnUpdate", type(D.frame:GetScript("OnUpdate")), "function")
MOCK:advance(6.5)
check("tras el fundido se desinstala", D.frame:GetScript("OnUpdate"), nil)
ManaBreathDB.holdRegen = true

ManaBreathDB.alwaysShow = true
D:UpdateShown()
check("matraz siempre visible pero en reposo", D.frame:IsShown(), true)
check("en reposo el matraz no esta vacio", D.fill > 0, true)
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
