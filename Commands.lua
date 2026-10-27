-- ManaBreath - slash commands.
local ADDON_NAME, ns = ...
local MB = ns.addon

local function OnOff(value)
    if value == "on" or value == "1" or value == "si" then return true end
    if value == "off" or value == "0" or value == "no" then return false end
    return nil
end

local function Toggle(key, value, label)
    local db = MB:GetDB()
    local wanted = OnOff(value)
    if wanted == nil then
        wanted = not db[key]
    end
    db[key] = wanted
    MB:Print(label .. ": " .. (wanted and "|cff33ff33on|r" or "|cffff5555off|r"))
    return wanted
end

local function Help()
    MB:Print("comandos disponibles:")
    print("  |cffffff00/mb config|r - abre el panel de opciones")
    print("  |cffffff00/mb lock|r / |cffffff00unlock|r - fija o libera el matraz")
    print("  |cffffff00/mb test|r - demo de 5 segundos")
    print("  |cffffff00/mb style flask/text|r - matraz animado o solo letras")
    print("  |cffffff00/mb scale <n>|r - escala (0.5 - 3)")
    print("  |cffffff00/mb size <ancho> <alto>|r - tamano del matraz")
    print("  |cffffff00/mb glow regen/rule/off|r - cuando brilla el matraz")
    print("  |cffffff00/mb regen on/off|r - seguir el mana que vuelve tras la regla")
    print("  |cffffff00/mb sound on/off|r - aviso sonoro al terminar")
    print("  |cffffff00/mb text on/off|r - contador dentro del matraz")
    print("  |cffffff00/mb always on/off|r - mostrar el matraz siempre")
    print("  |cffffff00/mb fallback on/off|r - detectar por bajadas de mana")
    print("  |cffffff00/mb channel on/off|r - reiniciar al cortar una canalizacion")
    print("  |cffffff00/mb verify|r - mide si la regla de 5 s existe de verdad")
    print("  |cffffff00/mb debug on/off|r - imprime el costo leido de cada casteo")
    print("  |cffffff00/mb reset|r - vuelve a los valores por defecto")
    print("  |cffffff00/mb status|r - estado actual")
end

local handlers = {}

handlers.config = function()
    if ns.options then
        ns.options:Open()
    else
        MB:Print("panel de opciones no disponible; usa |cffffff00/mb help|r.")
    end
end

handlers.options = function() handlers.config() end

handlers.lock = function()
    local db = MB:GetDB()
    db.locked = true
    ns.display:ApplySettings()
    MB:Print("matraz |cff33ff33fijado|r.")
end

handlers.unlock = function()
    local db = MB:GetDB()
    db.locked = false
    ns.display:ApplySettings()
    MB:Print("matraz |cffffff00libre|r: arrastralo con el boton izquierdo.")
end

handlers.test = function()
    MB:Start(GetTime(), true)
    MB:Print("demo de " .. MB.RULE_DURATION .. " segundos.")
end

handlers.scale = function(value)
    local scale = tonumber(value)
    if not scale or scale < 0.5 or scale > 3 then
        MB:Print("uso: /mb scale <0.5 - 3>")
        return
    end
    MB:GetDB().scale = scale
    ns.display:ApplySettings()
    MB:Print("escala: " .. scale)
end

handlers.size = function(width, height)
    width, height = tonumber(width), tonumber(height)
    if not width or not height or width < 40 or height < 6 then
        MB:Print("uso: /mb size <ancho >= 40> <alto >= 6>")
        MB:Print("el dibujo esta hecho para un marco cuadrado; para agrandarlo")
        MB:Print("sin deformarlo conviene |cffffff00/mb scale|r.")
        return
    end
    local db = MB:GetDB()
    db.width, db.height = width, height
    ns.display:ApplySettings()
    MB:Print(("tamano: %dx%d"):format(width, height))
    if db.style == "text" then
        MB:Print("en modo texto el ancho lo pone la cadena mas larga; manda el alto.")
    end
end

-- Las dos pieles. Por debajo es el mismo addon: cambia lo que se dibuja, no
-- lo que se detecta ni cuanto dura la regla.
local STYLE_MODES = {
    flask = "el matraz animado, con liquido, olas y burbujas",
    text = "solo la cifra y una etiqueta pequena debajo",
}

handlers.style = function(value)
    if not value or not STYLE_MODES[value] then
        MB:Print("uso: /mb style flask | text")
        for _, mode in ipairs({ "flask", "text" }) do
            print(("  |cffffff00%s|r - %s"):format(mode, STYLE_MODES[mode]))
        end
        return
    end
    MB:GetDB().style = value
    ns.display:ApplySettings()
    if ns.options then ns.options:Refresh() end
    MB:Print("estilo: |cff33ff33" .. value .. "|r (" .. STYLE_MODES[value] .. ")")
    if value == "text" then
        -- Tres opciones dejan de tener efecto, y callarselo se lee como que
        -- el mando no funciona.
        MB:Print("en modo texto no hay halo ni burbujas, y el contador no se")
        MB:Print("puede apagar: es lo unico que se ve.")
    end
end

-- El brillo marca una sola fase, la que se elija: encenderlo en las dos lo
-- dejaria sin decir nada.
local GLOW_MODES = {
    regen = "al acabar la regla, mientras el mana vuelve a subir",
    rule = "durante los 5 segundos de la regla",
    off = "nunca",
}

handlers.glow = function(value)
    if not value or not GLOW_MODES[value] then
        MB:Print("uso: /mb glow regen | rule | off")
        for _, mode in ipairs({ "regen", "rule", "off" }) do
            print(("  |cffffff00%s|r - %s"):format(mode, GLOW_MODES[mode]))
        end
        return
    end
    MB:GetDB().glow = value
    ns.display:RefreshGlow()
    if ns.options then ns.options:Refresh() end
    MB:Print("brillo: |cff33ff33" .. value .. "|r (" .. GLOW_MODES[value] .. ")")
end

-- La fase de regen se acaba sola de tres maneras: mana lleno, salir de
-- combate o volver a entrar en la regla. Lo dice el comando porque es la
-- diferencia entre un aviso y un elemento fijo de la interfaz.
handlers.regen = function(value)
    local enabled = Toggle("holdRegen", value, "seguimiento de la regeneracion")
    if enabled then
        MB:Print("el matraz se queda marcando el mana que entra hasta que se")
        MB:Print("llene, salgas de combate o vuelvas a gastar mana.")
    else
        MB:Print("el matraz se apagara en cuanto acabe la regla.")
        ns.display:EndRegen()
    end
end

handlers.sound = function(value)
    Toggle("sound", value, "sonido")
end

handlers.text = function(value)
    Toggle("showText", value, "textos")
    ns.display:ApplySettings()
end

handlers.always = function(value)
    Toggle("alwaysShow", value, "mostrar siempre")
    ns.display:UpdateShown()
end

handlers.fallback = function(value)
    local enabled = Toggle("powerFallback", value, "respaldo por mana")
    if enabled then
        MB:Print("|cffff9900ojo|r: puede dar falsos positivos si algo mas te quita mana.")
    end
end

handlers.channel = function(value)
    local enabled = Toggle("channelRestart", value, "reinicio al cortar canal")
    if not enabled then
        MB:Print("las canalizaciones solo arrancaran el contador al empezar.")
    end
end

handlers.verify = function()
    if ns.verify then
        ns.verify:Arm()
    else
        MB:Print("verificacion no disponible: falta Verify.lua.")
    end
end

handlers.debug = function(value)
    Toggle("debug", value, "debug")
end

handlers.reset = function()
    local db = MB:GetDB()
    wipe(db)
    for key, value in pairs(MB.defaults) do
        db[key] = value
    end
    ns.display:ApplySettings()
    if ns.options then ns.options:Refresh() end
    MB:Print("opciones restauradas.")
end

handlers.status = function()
    local db = MB:GetDB()
    MB:Print(("mana: %s | regla activa: %s | restante: %.1fs")
        :format(MB:UsesMana() and "si" or "no",
                MB:IsActive() and "si" or "no",
                MB:Remaining()))
    MB:Print(("estilo: %s | fijado: %s | escala: %s | sonido: %s | brillo: %s")
        :format(tostring(db.style), tostring(db.locked), tostring(db.scale),
                tostring(db.sound), tostring(db.glow)))
    MB:Print(("respaldo: %s | canal: %s | seguir regen: %s")
        :format(tostring(db.powerFallback), tostring(db.channelRestart),
                tostring(db.holdRegen)))
    MB:Print("fase del matraz: " .. tostring(ns.display and ns.display.state))

    if MB.costApi then
        MB:Print("lectura de costes: " .. MB.costApi)
    else
        MB:Print("lectura de costes: |cffff5555ninguna disponible|r")
        MB:Print("todo casteo quedara en 'unknown' y dependera del mana.")
    end

    MB:UpdateRestrictionState()
    if MB.restrictionApi then
        MB:Print(("contexto restringido: %s"):format(MB.restricted and "si" or "no"))
    else
        MB:Print("contexto restringido: |cff888888C_RestrictedActions no disponible|r")
    end
end

handlers.help = Help

SLASH_MANABREATH1 = "/manabreath"
SLASH_MANABREATH2 = "/mb"

SlashCmdList["MANABREATH"] = function(msg)
    local args = {}
    for word in string.gmatch(msg or "", "%S+") do
        args[#args + 1] = word
    end

    local command = string.lower(args[1] or "")
    local handler = handlers[command]

    if handler then
        handler(args[2] and string.lower(args[2]) or nil, args[3])
    else
        if command ~= "" then
            MB:Print("comando desconocido: " .. command)
        end
        Help()
    end
end
