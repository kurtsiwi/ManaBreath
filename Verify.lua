-- ManaBreath - comprobacion en el juego de que la regla de 5 s existe y dura
-- lo que creemos. La API no informa del estado de la regla, asi que esto no
-- detecta nada: mide si el mana regenera cuando la barra dice que no deberia.
local ADDON_NAME, ns = ...
local MB = ns.addon

local V = {}
ns.verify = V

local AFTER_RULE = 2.0   -- segundos de margen tras la ventana para ver regen

-- GetPowerRegen devuelve (fuera de la regla, durante la regla) en mana/s.
-- En clientes antiguos el nombre es GetManaRegen, con el mismo orden.
local function RegenRates()
    local fn = _G.GetPowerRegen or _G.GetManaRegen
    if type(fn) ~= "function" then return nil, nil, false end
    local ok, inactive, active = pcall(fn)
    if not ok then return nil, nil, false end
    local function clean(v)
        if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
        return type(v) == "number" and v or nil
    end
    return clean(inactive), clean(active), true
end

local function num(v, suffix)
    if v == nil then return "?" end
    return ("%.1f%s"):format(v, suffix or "")
end

function V:Arm()
    if not MB:UsesMana() then
        MB:Print("verificacion: esta clase o forma no usa mana.")
        return
    end
    if MB:GetMana() == nil then
        MB:Print("verificacion: el mana llega protegido, aqui no se puede medir.")
        MB:Print("prueba fuera de instancia y fuera de combate.")
        return
    end
    if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
        MB:Print("verificacion: C_Timer no esta disponible en este cliente.")
        return
    end

    local inactive, active, hasApi = RegenRates()
    if hasApi then
        MB:Print(("regen declarado | fuera de la regla: %s | durante: %s")
            :format(num(inactive, "/s"), num(active, "/s")))
    else
        MB:Print("regen declarado: GetPowerRegen no esta disponible.")
    end

    MB.verifyArmed = true
    MB:Print("|cffffff00armada|r: lanza un hechizo que gaste mana y no hagas nada mas.")
end

function V:Run(startedAt)
    local mana0 = MB:GetMana()
    if mana0 == nil then
        MB:Print("verificacion abortada: el mana paso a estar protegido.")
        return
    end

    local inactive = RegenRates()
    local duration = MB.RULE_DURATION

    -- Muestra justo antes de que acabe la ventana, y otra un margen despues.
    C_Timer.After(duration - 0.15, function()
        V.midMana = MB:GetMana()
    end)

    C_Timer.After(duration + AFTER_RULE, function()
        local mid, after = V.midMana, MB:GetMana()
        V.midMana = nil

        if mid == nil or after == nil then
            MB:Print("verificacion abortada: el mana paso a estar protegido.")
            return
        end

        local during = mid - mana0
        local outside = after - mid
        local expected = inactive and (inactive * (AFTER_RULE + 0.15)) or nil

        -- %+.0f y no %+d: el mana con MP5 puede ser fraccionario, y "%d" con
        -- un float sin representacion entera revienta en Lua 5.4 y trunca en
        -- silencio en el 5.1 de WoW.
        MB:Print(("durante la ventana (%.1fs): %+.0f mana"):format(duration - 0.15, during))
        MB:Print(("despues (%.1fs): %+.0f mana%s"):format(AFTER_RULE + 0.15, outside,
            expected and (" | esperado ~%+.0f"):format(expected) or ""))

        -- El veredicto se apoya en el contraste entre los dos tramos, no en
        -- valores absolutos: el MP5 del equipo si regenera dentro de la regla.
        if outside <= 0 and during <= 0 then
            MB:Print("|cffff9900sin concluir|r: no regeneraste en ningun tramo.")
            MB:Print("repite con el mana por debajo del maximo y sin combate.")
        elseif during <= 0 and outside > 0 then
            MB:Print("|cff33ff33coherente|r: sin regen dentro de la ventana y con regen fuera.")
        elseif during > 0 and outside > during then
            MB:Print("|cffffff00parcial|r: regeneraste algo dentro (puede ser MP5) y mas fuera.")
        else
            MB:Print("|cffff5555incoherente|r: regeneraste dentro de la ventana igual o mas que fuera.")
            MB:Print("Forever puede no aplicar la regla, o durar menos de " .. duration .. " s.")
        end
    end)
end
