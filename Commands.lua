-- ManaBreath - slash commands.
local ADDON_NAME, ns = ...
local MB = ns.addon

local function OnOff(value)
    if value == "on" or value == "1" or value == "yes" or value == "si" then return true end
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
    MB:Print("commands:")
    print("  |cffffff00/mb config|r - open the options panel")
    print("  |cffffff00/mb lock|r / |cffffff00unlock|r - pin or release the flask")
    print("  |cffffff00/mb test|r - 5-second demo")
    print("  |cffffff00/mb style flask/text/bar|r - flask, text only or bar")
    print("  |cffffff00/mb scale <n>|r - scale (0.5 - 3)")
    print("  |cffffff00/mb size <width> <height>|r - frame size")
    print("  |cffffff00/mb glow regen/rule/off|r - when the flask glows")
    print("  |cffffff00/mb regen on/off|r - track the mana coming back after the rule")
    print("  |cffffff00/mb hold <s>|r - how long the |cffffff00regen|r notice holds (0 - 10)")
    print("  |cffffff00/mb sound on/off|r - a water drop when the rule ends")
    print("  |cffffff00/mb text on/off|r - countdown inside the bulb")
    print("  |cffffff00/mb rate on/off|r - mana per second (bar and text mode)")
    print("  |cffffff00/mb always on/off|r - keep the flask always visible")
    print("  |cffffff00/mb fallback on/off|r - also detect via mana drops")
    print("  |cffffff00/mb channel on/off|r - restart when a channel is cut")
    print("  |cffffff00/mb verify|r - measure whether the 5 s rule really exists")
    print("  |cffffff00/mb debug on/off|r - print the cost read for every cast")
    print("  |cffffff00/mb reset|r - restore defaults")
    print("  |cffffff00/mb status|r - current state")
end

local handlers = {}

handlers.config = function()
    if ns.options then
        ns.options:Open()
    else
        MB:Print("no options panel; use |cffffff00/mb help|r.")
    end
end

handlers.options = function() handlers.config() end

handlers.lock = function()
    local db = MB:GetDB()
    db.locked = true
    ns.display:ApplySettings()
    MB:Print("flask |cff33ff33pinned|r.")
end

handlers.unlock = function()
    local db = MB:GetDB()
    db.locked = false
    ns.display:ApplySettings()
    MB:Print("flask |cffffff00loose|r: drag it with the left mouse button.")
end

handlers.test = function()
    MB:Start(GetTime(), true)
    MB:Print("demo of " .. MB.RULE_DURATION .. " seconds.")
end

handlers.scale = function(value)
    local scale = tonumber(value)
    if not scale or scale < 0.5 or scale > 3 then
        MB:Print("usage: /mb scale <0.5 - 3>")
        return
    end
    MB:GetDB().scale = scale
    ns.display:ApplySettings()
    MB:Print("scale: " .. scale)
end

handlers.size = function(width, height)
    width, height = tonumber(width), tonumber(height)
    if not width or not height or width < 40 or height < 6 then
        MB:Print("usage: /mb size <width >= 40> <height >= 6>")
        MB:Print("the art assumes a square frame; to make it bigger without")
        MB:Print("deforming it, use |cffffff00/mb scale|r.")
        return
    end
    local db = MB:GetDB()
    db.width, db.height = width, height
    ns.display:ApplySettings()
    MB:Print(("size: %dx%d"):format(width, height))
    if db.style == "text" then
        MB:Print("in text mode the widest string sets the width; the height rules.")
    elseif db.style == "bar" then
        MB:Print("in bar mode the width is yours, but never less than about three")
        MB:Print("times the height: below that it stops reading as a bar.")
    end
end

-- Las tres pieles. Por debajo es el mismo addon: cambia lo que se dibuja, no
-- lo que se detecta ni cuanto dura la regla.
local STYLE_MODES = {
    flask = "the animated flask, with liquid, waves and bubbles",
    text = "the figure alone, with the label and the mana per second underneath",
    bar = "a horizontal bar, with the mana per second underneath",
}

local STYLE_ORDER = { "flask", "text", "bar" }

handlers.style = function(value)
    if not value or not STYLE_MODES[value] then
        MB:Print("usage: /mb style flask | text | bar")
        for _, mode in ipairs(STYLE_ORDER) do
            print(("  |cffffff00%s|r - %s"):format(mode, STYLE_MODES[mode]))
        end
        return
    end
    MB:GetDB().style = value
    ns.display:ApplySettings()
    if ns.options then ns.options:Refresh() end
    MB:Print("style: |cff33ff33" .. value .. "|r (" .. STYLE_MODES[value] .. ")")
    if value == "text" then
        -- Tres opciones dejan de tener efecto, y callarselo se lee como que
        -- el mando no funciona.
        MB:Print("text mode has no glow or bubbles, and the counter cannot be")
        MB:Print("turned off: the figure is the only thing there.")
    elseif value == "bar" then
        MB:Print("bar mode has no glow or bubbles.")
    end
    if value ~= "flask" then
        MB:Print("the mana per second shows up with the second tick, which is")
        MB:Print("when there is something measured; |cffffff00/mb rate off|r takes it away.")
    end
end

-- El brillo marca una sola fase, la que se elija: encenderlo en las dos lo
-- dejaria sin decir nada.
local GLOW_MODES = {
    regen = "when the rule ends, while mana is coming back",
    rule = "during the 5 seconds of the rule",
    off = "never",
}

handlers.glow = function(value)
    if not value or not GLOW_MODES[value] then
        MB:Print("usage: /mb glow regen | rule | off")
        for _, mode in ipairs({ "regen", "rule", "off" }) do
            print(("  |cffffff00%s|r - %s"):format(mode, GLOW_MODES[mode]))
        end
        return
    end
    MB:GetDB().glow = value
    ns.display:RefreshGlow()
    if ns.options then ns.options:Refresh() end
    MB:Print("glow: |cff33ff33" .. value .. "|r (" .. GLOW_MODES[value] .. ")")
end

-- La fase de regen se acaba sola de tres maneras: mana lleno, salir de
-- combate o volver a entrar en la regla. Lo dice el comando porque es la
-- diferencia entre un aviso y un elemento fijo de la interfaz.
handlers.regen = function(value)
    local enabled = Toggle("holdRegen", value, "regen tracking")
    if enabled then
        if MB:ManaIsSecret() then
            MB:Print("|cffff9900not on this client|r: mana is a secret value, so there")
            MB:Print("is no mana to follow. The flask goes out when the notice ends.")
        else
            MB:Print("the flask goes on tracking the mana coming in until it fills")
            MB:Print("up, you leave combat or you spend mana again.")
        end
    else
        MB:Print("the flask will go out as soon as the rule ends.")
        ns.display:EndRegen()
    end
end

-- El aviso del final de la regla: el matraz lleno con la palabra "regen".
-- Dura lo que diga esto y despues pasa a marcar el mana que entra, asi que
-- subirlo alarga el aviso, no la fase de regeneracion.
handlers.hold = function(value)
    local seconds = tonumber(value)
    if not seconds or seconds < 0 or seconds > 10 then
        MB:Print("usage: /mb hold <0 - 10>")
        MB:Print("seconds the |cffffff00regen|r notice holds when the rule ends.")
        return
    end
    MB:GetDB().doneHold = seconds
    if ns.options then ns.options:Refresh() end
    MB:Print(("|cffffff00regen|r notice: |cff33ff33%.1fs|r"):format(seconds))
    if seconds == 0 then
        MB:Print("at 0 the flask goes straight to tracking the mana coming in.")
    end
end

handlers.sound = function(value)
    Toggle("sound", value, "sound")
end

handlers.text = function(value)
    Toggle("showText", value, "counter")
    ns.display:ApplySettings()
end

-- El mana por segundo lo dibujan las dos pieles planas: en la barra a la
-- derecha de la etiqueta, en modo texto de tercera linea debajo. En el matraz
-- no hay sitio para una segunda cifra, asi que alli el mando se mide igual
-- pero no se ve, y callarselo se lee como que no funciona.
handlers.rate = function(value)
    local enabled = Toggle("showRate", value, "mana per second")
    ns.display:ApplySettings()
    if ns.options then ns.options:Refresh() end
    if enabled and MB:ManaIsSecret() then
        MB:Print("|cffff9900it cannot be measured here|r: mana is a secret value, and")
        MB:Print("a rate is two readings subtracted.")
    elseif enabled and MB:GetDB().style == "flask" then
        MB:Print("the flask does not draw it: no room for a second figure.")
        MB:Print("it shows in |cffffff00/mb style bar|r and |cffffff00/mb style text|r.")
    end
end

handlers.always = function(value)
    Toggle("alwaysShow", value, "always visible")
    ns.display:UpdateShown()
end

handlers.fallback = function(value)
    local enabled = Toggle("powerFallback", value, "mana fallback")
    if enabled then
        if MB:ManaIsSecret() then
            MB:Print("|cffff9900it will do nothing here|r: mana is a secret value, so a")
            MB:Print("drop cannot be told from a rise. Detection runs on the cost.")
        else
            MB:Print("|cffff9900careful|r: this can produce false positives if something else drains your mana.")
        end
    end
end

handlers.channel = function(value)
    local enabled = Toggle("channelRestart", value, "restart on channel stop")
    if not enabled then
        MB:Print("channels will only start the countdown when they begin.")
    end
end

handlers.verify = function()
    if ns.verify then
        ns.verify:Arm()
    else
        MB:Print("verify not available: Verify.lua is missing.")
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
    MB:Print("options restored.")
end

handlers.status = function()
    local db = MB:GetDB()
    MB:Print(("mana: %s | rule active: %s | left: %.1fs")
        :format(MB:UsesMana() and "yes" or "no",
                MB:IsActive() and "yes" or "no",
                MB:Remaining()))
    MB:Print(("style: %s | pinned: %s | scale: %s | sound: %s | glow: %s")
        :format(tostring(db.style), tostring(db.locked), tostring(db.scale),
                tostring(db.sound), tostring(db.glow)))
    MB:Print(("counter: %s | mana per second: %s")
        :format(tostring(db.showText), tostring(db.showRate)))
    MB:Print(("fallback: %s | channel: %s | track regen: %s | notice: %.1fs")
        :format(tostring(db.powerFallback), tostring(db.channelRestart),
                tostring(db.holdRegen),
                tonumber(db.doneHold) or MB.defaults.doneHold))
    MB:Print("flask phase: " .. tostring(ns.display and ns.display.state))

    MB:Print("mana reads: " .. (MB:ManaIsSecret()
        and "|cffff9900secret|r (no figure, no rate, no verify)" or "plain"))

    if MB.costApi then
        MB:Print("cost reads: " .. MB.costApi)
    else
        MB:Print("cost reads: |cffff5555none available|r")
        MB:Print("every cast will land as 'unknown' and depend on mana.")
    end

    -- Solo si el cliente la tiene. En Forever no existe, y repetirlo en cada
    -- /mb status era una linea de ruido fija: lo que alli importa es si el
    -- mana se puede leer, y eso ya esta arriba.
    MB:UpdateRestrictionState()
    if MB.restrictionApi then
        MB:Print(("restricted context: %s"):format(MB.restricted and "yes" or "no"))
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
    elseif command == "" then
        Help()
    else
        -- Un dedazo no merece volcar las 19 lineas de ayuda encima de lo que
        -- estuvieras leyendo: /mb a secas las sigue dando.
        MB:Print("unknown command: " .. command)
        MB:Print("type |cffffff00/mb help|r for the list.")
    end
end
