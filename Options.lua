-- ManaBreath - panel de opciones en Ajustes > AddOns.
--
-- Los comandos de barra son la via que nunca falla; esto es la que la gente
-- encuentra. Todo lo que hay aqui existe tambien como /mb, y al reves: el
-- panel escribe directamente en ManaBreathDB, asi que no hay dos verdades.
local _, ns = ...
local MB = ns.addon

local O = {}
ns.options = O

local format = string.format

-- Settings.VarType.Boolean es la cadena "boolean", asi que se pasan las
-- cadenas y no la tabla: si este cliente no expone VarType, esto sigue
-- valiendo. Mismo motivo para los alias de abajo: el API se llamaba
-- CreateCheckBox y CreateDropDown antes de la 11.0.
local BOOL, NUMBER, STRING = "boolean", "number", "string"

local STYLE_OPTIONS = {
    { value = "flask", label = "Animated flask",
      tooltip = "The glass flask: the liquid rises over the 5 seconds, with waves and bubbles." },
    { value = "text", label = "Text only",
      tooltip = "The figure, with a small label and the mana per second underneath, and no drawing. There is no glow or bubbles, and the counter cannot be turned off." },
    { value = "bar", label = "Bar",
      tooltip = "A horizontal bar that fills over the 5 seconds, with the figure on it, and underneath the label and the mana per second. There is no glow or bubbles." },
}

local GLOW_OPTIONS = {
    { value = "regen", label = "While regenerating",
      tooltip = "Glows when the rule ends and mana starts coming back." },
    { value = "rule", label = "During the rule",
      tooltip = "Glows for the 5 seconds in which mana does NOT rise." },
    { value = "off", label = "Never",
      tooltip = "No glow." },
}

-- Que hay que hacer cuando cambia cada opcion. Lo que no esta aqui no
-- necesita nada: se lee de ManaBreathDB cuando toca.
local APPLY = {
    locked = function() ns.display:ApplySettings() end,
    style = function() ns.display:ApplySettings() end,
    scale = function() ns.display:ApplySettings() end,
    showText = function() ns.display:ApplySettings() end,
    showRate = function() ns.display:ApplySettings() end,
    alwaysShow = function() ns.display:UpdateShown() end,
    glow = function() ns.display:RefreshGlow() end,
    holdRegen = function(value)
        if value == false then ns.display:EndRegen() end
    end,
}

-- A proposito no se mira el valor que entrega la retrollamada: su firma ha
-- cambiado entre versiones del API y la posicion del argumento no es algo en
-- lo que quiera apoyarme. El sistema escribe en la tabla antes de avisar, asi
-- que leerlo de ManaBreathDB es correcto y no depende de nada.
local function Apply(key)
    local fn = APPLY[key]
    if fn then fn(MB:GetDB()[key]) end
end

-- Un id unico por opcion para el sistema de ajustes. No es la clave de la DB:
-- esa va aparte y es la que de verdad guarda el valor.
local function Variable(key)
    return "MANABREATH_" .. string.upper(key)
end

function O:Register(key, varType, label, tooltip)
    local db = MB:GetDB()
    local variable = Variable(key)

    -- Forma de la 11.0 en adelante: el valor vive en db[key], no en una
    -- variable aparte, asi que el panel y /mb no se pueden desincronizar.
    local setting = Settings.RegisterAddOnSetting(self.category, variable, key,
        db, varType, label, MB.defaults[key])

    if Settings.SetOnValueChangedCallback then
        Settings.SetOnValueChangedCallback(variable, function() Apply(key) end)
    elseif setting.SetValueChangedCallback then
        setting:SetValueChangedCallback(function() Apply(key) end)
    end

    self.settings[key] = setting
    return setting, tooltip
end

function O:AddCheckbox(key, label, tooltip)
    local create = Settings.CreateCheckbox or Settings.CreateCheckBox
    local setting = self:Register(key, BOOL, label, tooltip)
    create(self.category, setting, tooltip)
end

function O:AddHeader(text)
    if CreateSettingsListSectionHeaderInitializer then
        self.layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

function O:AddButton(label, buttonText, tooltip, onClick)
    if not CreateSettingsButtonInitializer then return end
    self.layout:AddInitializer(
        CreateSettingsButtonInitializer(label, buttonText, onClick, tooltip, true))
end

function O:AddScale()
    local setting = self:Register("scale", NUMBER, "Scale")
    local options = Settings.CreateSliderOptions(0.5, 3, 0.1)
    if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return format("%.1f", value) end)
    end
    Settings.CreateSlider(self.category, setting, options,
        "The flask is 58x58 at scale 1. This is the way to make it bigger without deforming it.")
end

-- El aviso del final de la regla, en segundos. Mismo deslizador que la
-- escala, con su propio rango: el panel y /mb hold escriben en doneHold.
function O:AddHold()
    local setting = self:Register("doneHold", NUMBER, "Time showing \"regen\"")
    local options = Settings.CreateSliderOptions(0, 10, 0.1)
    if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return format("%.1fs", value) end)
    end
    Settings.CreateSlider(self.category, setting, options,
        "How long the word \"regen\" stays on screen when the rule ends, with the "
        .. "flask full, before it switches to tracking the mana coming in. At 0 it "
        .. "goes straight to the mana.")
end

function O:AddChoice(key, label, entries, tooltip)
    local create = Settings.CreateDropdown or Settings.CreateDropDown
    if not create then return end

    local setting = self:Register(key, STRING, label)
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        for i = 1, #entries do
            container:Add(entries[i].value, entries[i].label, entries[i].tooltip)
        end
        return container:GetData()
    end

    create(self.category, setting, GetOptions, tooltip)
end

-- Se construye entera antes de registrar la categoria: si algo de esto no
-- existe en este cliente, el error se atrapa y no aparece un panel a medias.
local function Build(self)
    local category, layout = Settings.RegisterVerticalLayoutCategory("ManaBreath")
    self.category = category
    self.layout = layout
    self.settings = {}

    self:AddHeader("Appearance")
    self:AddChoice("style", "How it is drawn", STYLE_OPTIONS,
        "All three skins count the same and detect the same: only the drawing differs.")
    self:AddCheckbox("locked", "Pin the flask",
        "Unticked, the flask can be dragged with the left mouse button.")
    self:AddScale()
    self:AddCheckbox("showText", "Countdown inside the bulb",
        "The seconds left, and the mana percentage while regenerating. "
        .. "It does not apply in text mode: there the figure is the only thing on screen.")
    self:AddCheckbox("showRate", "Mana per second",
        "The mana coming in while you regenerate, under the figure. The bar and "
        .. "text mode draw it; the flask has no room for a second figure, so it is "
        .. "left out there. It shows up with the second tick, which is when there "
        .. "is something measured.")
    self:AddCheckbox("alwaysShow", "Keep the flask always visible",
        "Idle too. It costs nothing per frame: an idle flask does not animate.")

    self:AddHeader("Alerts")
    self:AddChoice("glow", "When the flask glows", GLOW_OPTIONS,
        "The glow lights exactly one phase, whichever you pick: lighting both "
        .. "would say nothing. There is no glow in text mode.")
    self:AddCheckbox("holdRegen", "Track the mana coming back",
        "When the rule ends the flask goes on tracking the mana coming in, until "
        .. "it fills up, you leave combat or you spend mana again.")
    self:AddCheckbox("sound", "Sound alert when the rule ends")
    self:AddHold()

    self:AddHeader("Detection")
    self:AddCheckbox("powerFallback", "Also detect via mana drops",
        "This can produce false positives if something else drains your mana.")
    self:AddCheckbox("channelRestart", "Restart when a channel is cut",
        "A channel spends mana for as long as it lasts, so the rule should count "
        .. "from the last tick. If Forever charges it all up front, untick this.")
    self:AddButton("Measure the rule", "Check",
        "Arms /mb verify: cast a spell that spends mana and then do nothing else. "
        .. "It measures mana inside and outside the window and says whether the rule really exists.",
        function()
            if ns.verify then ns.verify:Arm() end
        end)

    self:AddHeader("Diagnostics")
    self:AddCheckbox("debug", "Print the cost read for every cast")
    self:AddButton("Options", "Restore defaults",
        "Goes back to the default values, position included.",
        function() SlashCmdList["MANABREATH"]("reset") end)

    Settings.RegisterAddOnCategory(category)
end

function O:Init()
    if self.category or self.failed then return end
    if not (Settings and Settings.RegisterVerticalLayoutCategory
        and Settings.RegisterAddOnSetting and Settings.RegisterAddOnCategory) then
        self.failed = "this client does not expose the settings API"
        return
    end

    local ok, err = pcall(Build, self)
    if not ok then
        -- El panel es un extra: si el API no es el que se espera, el addon
        -- sigue funcionando entero por /mb y aqui queda el motivo.
        self.category = nil
        self.failed = tostring(err)
        MB:Debug("options panel not available:", self.failed)
    end
end

-- Tras un cambio hecho por fuera (un /mb, o restaurar valores) el panel
-- abierto no se enteraria: esto le dice que vuelva a leer la DB.
function O:Refresh()
    if not self.settings then return end
    local db = MB:GetDB()
    for key, setting in pairs(self.settings) do
        if setting.SetValue and db[key] ~= nil then
            pcall(setting.SetValue, setting, db[key])
        end
    end
end

function O:Open()
    if not self.category then
        MB:Print("no options panel: " .. (self.failed or "not registered") .. ".")
        MB:Print("use |cffffff00/mb help|r; everything can be set through commands.")
        return false
    end
    if Settings.OpenToCategory then
        local id = self.category.GetID and self.category:GetID() or nil
        if not (id and pcall(Settings.OpenToCategory, id)) then
            pcall(Settings.OpenToCategory, "ManaBreath")
        end
    end
    return true
end

-- Boton del compartimento de addons, junto al minimapa. El icono es el
-- ## IconTexture del TOC.
_G["ManaBreath_OnAddonCompartmentClick"] = function()
    O:Open()
end
