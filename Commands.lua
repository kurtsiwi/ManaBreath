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
    print("  |cffffff00/mb lock|r / |cffffff00unlock|r - fija o libera la barra")
    print("  |cffffff00/mb test|r - demo de 5 segundos")
    print("  |cffffff00/mb scale <n>|r - escala (0.5 - 3)")
    print("  |cffffff00/mb size <ancho> <alto>|r - tamano de la barra")
    print("  |cffffff00/mb sound on/off|r - aviso sonoro al terminar")
    print("  |cffffff00/mb text on/off|r - textos de la barra")
    print("  |cffffff00/mb always on/off|r - mostrar la barra siempre")
    print("  |cffffff00/mb fallback on/off|r - detectar por bajadas de mana")
    print("  |cffffff00/mb channel on/off|r - reiniciar al cortar una canalizacion")
    print("  |cffffff00/mb verify|r - mide si la regla de 5 s existe de verdad")
    print("  |cffffff00/mb debug on/off|r - imprime el costo leido de cada casteo")
    print("  |cffffff00/mb reset|r - vuelve a los valores por defecto")
    print("  |cffffff00/mb status|r - estado actual")
end

local handlers = {}

handlers.lock = function()
    local db = MB:GetDB()
    db.locked = true
    ns.display:ApplySettings()
    MB:Print("barra |cff33ff33fijada|r.")
end

handlers.unlock = function()
    local db = MB:GetDB()
    db.locked = false
    ns.display:ApplySettings()
    MB:Print("barra |cffffff00libre|r: arrastrala con el boton izquierdo.")
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
        return
    end
    local db = MB:GetDB()
    db.width, db.height = width, height
    ns.display:ApplySettings()
    MB:Print(("tamano: %dx%d"):format(width, height))
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
    MB:Print("opciones restauradas.")
end

handlers.status = function()
    local db = MB:GetDB()
    MB:Print(("mana: %s | regla activa: %s | restante: %.1fs")
        :format(MB:UsesMana() and "si" or "no",
                MB:IsActive() and "si" or "no",
                MB:Remaining()))
    MB:Print(("fijada: %s | escala: %s | sonido: %s | respaldo: %s | canal: %s")
        :format(tostring(db.locked), tostring(db.scale), tostring(db.sound),
                tostring(db.powerFallback), tostring(db.channelRestart)))

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
