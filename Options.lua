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
    { value = "flask", label = "Matraz animado",
      tooltip = "El matraz de cristal: el liquido sube durante los 5 segundos, con olas y burbujas." },
    { value = "text", label = "Solo texto",
      tooltip = "La cifra y una etiqueta pequena debajo, sin dibujo. No hay halo ni burbujas, y el contador no se puede apagar." },
}

local GLOW_OPTIONS = {
    { value = "regen", label = "Al regenerar",
      tooltip = "Brilla cuando la regla acaba y el mana vuelve a subir." },
    { value = "rule", label = "Durante la regla",
      tooltip = "Brilla los 5 segundos en los que el mana NO sube." },
    { value = "off", label = "Nunca",
      tooltip = "Sin brillo." },
}

-- Que hay que hacer cuando cambia cada opcion. Lo que no esta aqui no
-- necesita nada: se lee de ManaBreathDB cuando toca.
local APPLY = {
    locked = function() ns.display:ApplySettings() end,
    style = function() ns.display:ApplySettings() end,
    scale = function() ns.display:ApplySettings() end,
    showText = function() ns.display:ApplySettings() end,
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
    local setting = self:Register("scale", NUMBER, "Escala")
    local options = Settings.CreateSliderOptions(0.5, 3, 0.1)
    if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return format("%.1f", value) end)
    end
    Settings.CreateSlider(self.category, setting, options,
        "El matraz mide 58x58 a escala 1. Esta es la forma de agrandarlo sin deformarlo.")
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

    self:AddHeader("Aspecto")
    self:AddChoice("style", "Como se dibuja", STYLE_OPTIONS,
        "Las dos pieles cuentan lo mismo y detectan igual: solo cambia el dibujo.")
    self:AddCheckbox("locked", "Fijar el matraz",
        "Desmarcado, el matraz se puede arrastrar con el boton izquierdo.")
    self:AddScale()
    self:AddCheckbox("showText", "Contador dentro del matraz",
        "Los segundos que faltan, y el porcentaje de mana durante la regeneracion. "
        .. "En modo texto no se aplica: ahi la cifra es lo unico que hay.")
    self:AddCheckbox("alwaysShow", "Mostrar el matraz siempre",
        "Tambien en reposo. No cuesta nada por frame: el matraz en reposo no se anima.")

    self:AddHeader("Avisos")
    self:AddChoice("glow", "Cuando brilla el matraz", GLOW_OPTIONS,
        "El brillo alumbra una sola fase, la que elijas: encenderlo en las dos lo "
        .. "dejaria sin decir nada. En modo texto no hay halo.")
    self:AddCheckbox("holdRegen", "Seguir el mana que vuelve",
        "Al acabar la regla el matraz se queda marcando el mana que entra, hasta "
        .. "que se llene, salgas de combate o vuelvas a gastar mana.")
    self:AddCheckbox("sound", "Aviso sonoro al terminar la regla")

    self:AddHeader("Deteccion")
    self:AddCheckbox("powerFallback", "Detectar tambien por bajadas de mana",
        "Puede dar falsos positivos si algo mas te quita mana.")
    self:AddCheckbox("channelRestart", "Reiniciar al cortar una canalizacion",
        "Una canalizacion gasta mana mientras dura, asi que la regla deberia "
        .. "contar desde el ultimo tick. Si Forever lo cobra todo al empezar, desmarcalo.")
    self:AddButton("Medir la regla", "Comprobar",
        "Arma /mb verify: lanza un hechizo que gaste mana y no hagas nada mas. "
        .. "Mide el mana dentro y fuera de la ventana y dice si la regla existe de verdad.",
        function()
            if ns.verify then ns.verify:Arm() end
        end)

    self:AddHeader("Diagnostico")
    self:AddCheckbox("debug", "Imprimir el coste leido de cada casteo")
    self:AddButton("Opciones", "Restaurar valores",
        "Vuelve a los valores por defecto, posicion incluida.",
        function() SlashCmdList["MANABREATH"]("reset") end)

    Settings.RegisterAddOnCategory(category)
end

function O:Init()
    if self.category or self.failed then return end
    if not (Settings and Settings.RegisterVerticalLayoutCategory
        and Settings.RegisterAddOnSetting and Settings.RegisterAddOnCategory) then
        self.failed = "este cliente no expone el API de Ajustes"
        return
    end

    local ok, err = pcall(Build, self)
    if not ok then
        -- El panel es un extra: si el API no es el que se espera, el addon
        -- sigue funcionando entero por /mb y aqui queda el motivo.
        self.category = nil
        self.failed = tostring(err)
        MB:Debug("panel de opciones no disponible:", self.failed)
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
        MB:Print("no hay panel de opciones: " .. (self.failed or "sin registrar") .. ".")
        MB:Print("usa |cffffff00/mb help|r; todo se puede configurar por comandos.")
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
