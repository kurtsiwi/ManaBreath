-- ManaBreath - el matraz que se llena durante los 5 segundos de la regla.
local ADDON_NAME, ns = ...
local MB = ns.addon

local D = {}
D.state = "idle"
D.fill = 0
ns.display = D

-- El nombre de la carpeta del addon es el nombre del TOC, asi que la ruta del
-- arte sale sola y no hay que tocarla si el paquete se renombra.
local ART = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Art\\"

-- Una gota, al cumplirse la regla, que es el instante en que el mana vuelve
-- a subir. OGG y no MP3: los dos cargan, pero el soporte de MP3 se rompio
-- una vez y cuando falla no da error, simplemente no suena.
local SOUND_DROP = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Sound\\ManaDrop.ogg"

local COLOR_ACTIVE = { 0.26, 0.52, 0.98 }
local COLOR_DONE   = { 0.35, 0.95, 0.62 }
local COLOR_IDLE   = { 0.40, 0.40, 0.46 }
-- Destello de cada tick de mana: el verde de arriba, aclarado.
local COLOR_TICK   = { 0.72, 1.00, 0.86 }

local HOLD_AFTER_DONE = 0.7
local FADE_DURATION = 0.5

-- La fase de regeneracion se cierra sola si el mana deja de subir: puede que
-- ya este lleno, o que este cliente no avise de cada tick. Sin esto el matraz
-- se quedaria encendido para siempre.
local REGEN_TIMEOUT = 4.0
local TICK_FLASH = 0.30
-- A que velocidad persigue el liquido al nivel de mana real. Al acabar la
-- regla el matraz esta lleno y el mana casi nunca lo esta: saltar de golpe al
-- nivel real se lee como un fallo de dibujo, bajar hasta el no.
local FILL_SETTLE = 6.0

local DONE_TEXT = "regen"
local HINT_TEXT = "arrastrame"
local IDLE_FILL = 0.12

-- Modo texto: sin matraz, solo la cifra y una etiqueta pequena debajo. El
-- motor es el mismo (estados, tiempos, fase de regeneracion); lo unico que
-- cambia es que se dibuja, asi que un arreglo en la regla vale para los dos.
local TEXT_VALUE_H = 0.42   -- alto de la cifra, en fracciones del alto del marco
local TEXT_LABEL_H = 0.17   -- alto de la etiqueta
local TEXT_GAP     = 0.06   -- aire entre las dos
local TEXT_PAD     = 0.26   -- margen alrededor del bloque
-- Espaciadas a mano: el API de fuentes no expone letter-spacing, y es
-- justamente el aire entre letras lo que hace que una etiqueta en
-- mayusculas se lea como tipografia y no como un grito.
local LABEL_RULE  = "5 S R"
local LABEL_REGEN = "M A N A"
local IDLE_TEXT   = "--"
local COLOR_LABEL = { 0.55, 0.55, 0.62 }

-- Las cadenas mas anchas que puede llegar a mostrar cada linea. El marco se
-- dimensiona a estas y no a la que hay ahora: si no, cambiaria de tamano al
-- pasar de "4.3" a "regen" y el bloque bailaria en pantalla.
local WIDEST_VALUE = { DONE_TEXT, "100%", "0.0", IDLE_TEXT }
local WIDEST_LABEL = { LABEL_RULE, LABEL_REGEN }

-- Modo barra: una barra horizontal que se llena durante los 5 s, con un
-- destello en el borde de avance, la cifra centrada encima, y debajo la
-- etiqueta a la izquierda y el mana por segundo a la derecha. Todo en
-- fracciones del alto del marco, como el matraz.
local BAR_PAD     = 0.07   -- margen alrededor de la barra
local BAR_H       = 0.56   -- alto de la barra
local BAR_GAP     = 0.10   -- aire entre la barra y la linea de abajo
local BAR_LABEL_H = 0.18   -- alto de la etiqueta y del mana por segundo
local BAR_VALUE_H = 0.30   -- alto de la cifra, que va centrada sobre la barra
local BAR_BORDER  = 1      -- grosor del contorno, en pixeles
-- Estos dos estan tambien en tools/make_art.py, que dibuja la vista previa.
local BAR_SPARK_W = 0.55   -- ancho del destello, en fracciones del alto de la barra
local BAR_SPARK_H = 1.55   -- alto del destello: sobresale por arriba y por abajo
-- Una barra tan alta como ancha no se lee como barra. El ancho sale del mayor
-- entre el configurado y este multiplo del alto, asi que el tamano por defecto
-- (58x58, pensado para el matraz) da una barra y no un cuadrado.
local BAR_MIN_ASPECT = 3.2
-- Cuerpo de letra minimo: el alto del marco lo elige quien lo usa y puede
-- bajar hasta 6 px, donde la etiqueta saldria a 1 px, o sea a nada.
local MIN_FONT = 6

local COLOR_TRACK  = { 0.07, 0.07, 0.09 }
local COLOR_BORDER = { 0.00, 0.00, 0.00 }

-- Mana por segundo. Se mide entre ticks y solo lo dibuja la barra, que es la
-- unica piel con sitio para una segunda cifra.
local RATE_FORMAT = "%.1f/s"
-- Antes de medio segundo no hay intervalo que promediar: lo que saldria es el
-- trozo de tick que hubiera caido dentro, no una tasa.
local RATE_MIN_SPAN = 0.5

-- Geometria del dibujo, en fracciones del marco. Estos mismos numeros estan
-- en tools/make_art.py: si se mueve el matraz alla, hay que moverlos aqui.
local FILL_BOTTOM = 0.040   -- fondo interior del bulbo
local FILL_TOP    = 0.660   -- hasta donde sube el liquido estando lleno
local BULB_CENTER = 0.345   -- centro del bulbo, para centrar el contador
local WAVE_H      = 0.16    -- alto de la banda de ola
local WAVE_SPAN   = 1.6     -- repeticiones de la banda de lado a lado
local GLOW_SCALE  = 0.74    -- el halo se dibuja a 1/GLOW_SCALE del marco

-- Burbujas: desplazamiento respecto al centro, fase, tamano y velocidad.
-- Son fijas a proposito: math.random en el OnUpdate seria basura por frame.
local BUBBLES = {
    { x = -0.105, phase = 0.00, size = 0.085, speed = 0.48 },
    { x =  0.070, phase = 0.37, size = 0.115, speed = 0.37 },
    { x = -0.020, phase = 0.64, size = 0.070, speed = 0.55 },
    { x =  0.125, phase = 0.86, size = 0.095, speed = 0.43 },
}

local WAVE_SPEED_1 = 0.33
local WAVE_SPEED_2 = -0.21

-- La animacion (olas, burbujas y latido del halo) corre a 30 Hz, no por frame.
-- A 58 px el liquido mide 36 px de alto y la burbuja mas rapida lo recorre en
-- 2 s, o sea 0,6 px por paso de 30 Hz: pedir 60 Hz era pagar el doble de
-- llamadas al API para mover medio pixel. El contador y el nivel del liquido
-- SI van por frame, que es lo que se mira de cerca. Si en el juego se ve a
-- saltos, baja esto a 1/60.
local ANIM_STEP = 1 / 30

-- La ventana es fija (0.0 - 5.0), asi que las 51 cadenas posibles del contador
-- se construyen una sola vez al cargar. Con esto el OnUpdate no asigna nada:
-- un string.format por frame generaria basura 60 veces por segundo.
local TENTH_TEXT = {}
for i = 0, math.floor(MB.RULE_DURATION * 10) do
    TENTH_TEXT[i] = string.format("%.1f", i / 10)
end

local sin, abs, floor, min, max = math.sin, math.abs, math.floor, math.min, math.max
local format = string.format

-- Color de trabajo del destello. Se reutiliza: una tabla nueva por frame seria
-- basura 60 veces por segundo.
local FLASH = { 0, 0, 0 }

local function Approach(current, target, elapsed)
    local delta = target - current
    if abs(delta) < 0.004 then return target end
    return current + delta * min(1, elapsed * FILL_SETTLE)
end

local function AnchorWave(wave, liquid, height)
    wave:ClearAllPoints()
    wave:SetPoint("BOTTOMLEFT", liquid, "TOPLEFT", 0, -height / 2)
    wave:SetPoint("BOTTOMRIGHT", liquid, "TOPRIGHT", 0, -height / 2)
    wave:SetHeight(height)
end

-- El matraz pide OUTLINE: la cifra va sobre el cristal y el liquido, y sin
-- borde se pierde. El modo texto va sobre el fondo del juego, donde el borde
-- se lee como un contorno grueso: ahi una sombra corta es mas limpia.
local function SetFontSize(fontString, size, flags)
    local file = fontString:GetFont()
    if file then
        fontString:SetFont(file, size, flags)
    end
end

local function MeasureWidest(fontString, candidates, fallback)
    local keep = fontString:GetText()
    local widest = 0
    for i = 1, #candidates do
        fontString:SetText(candidates[i])
        local w = fontString:GetStringWidth() or 0
        if w > widest then widest = w end
    end
    fontString:SetText(keep or "")
    -- Si el cliente no sabe medir la cadena, una estimacion por numero de
    -- letras deja el marco utilizable en vez de dejarlo a cero.
    if widest <= 0 then widest = fallback end
    return widest
end

function D:Init()
    if self.frame then return end

    local f = CreateFrame("Frame", "ManaBreathFrame", UIParent)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:Hide()

    -- El matraz no es rectangular, asi que desbloqueado se marca la zona que
    -- responde al raton; si no, no se sabe de donde agarrarlo.
    local dragArea = f:CreateTexture(nil, "BACKGROUND", nil, -5)
    dragArea:SetAllPoints(f)
    dragArea:SetColorTexture(0, 0, 0, 0.3)
    dragArea:Hide()

    -- Halo. Se dibuja mas grande que el marco porque el TGA lleva la silueta
    -- encogida: asi el difuminado cabe dentro de la textura sin recortarse.
    local glow = f:CreateTexture(nil, "BACKGROUND", nil, -3)
    glow:SetTexture(ART .. "FlaskGlow")
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER")
    glow:Hide()

    -- Mascara con la forma del interior del cristal. Todo lo que es liquido
    -- pasa por ella, asi que ni la ola ni las burbujas se salen del matraz.
    local mask
    if f.CreateMaskTexture then
        mask = f:CreateMaskTexture()
        mask:SetTexture(ART .. "FlaskMask",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(f)
    end
    self.masked = mask ~= nil

    local liquid = f:CreateTexture(nil, "ARTWORK", nil, 0)
    liquid:SetTexture(ART .. "FlaskLiquid")

    -- Dos capas de ola a velocidades distintas: una sola se ve como una
    -- plantilla deslizandose, dos se leen como superficie.
    local wave2 = f:CreateTexture(nil, "ARTWORK", nil, 1)
    wave2:SetTexture(ART .. "FlaskWave", "REPEAT", "CLAMP")
    wave2:SetAlpha(0.5)

    local wave1 = f:CreateTexture(nil, "ARTWORK", nil, 2)
    wave1:SetTexture(ART .. "FlaskWave", "REPEAT", "CLAMP")

    local bubbles = {}
    for i = 1, #BUBBLES do
        local tex = f:CreateTexture(nil, "ARTWORK", nil, 3)
        tex:SetTexture(ART .. "FlaskBubble")
        tex:SetBlendMode("ADD")
        tex:Hide()
        bubbles[i] = tex
    end

    local glass = f:CreateTexture(nil, "OVERLAY", nil, 0)
    glass:SetTexture(ART .. "FlaskGlass")
    glass:SetAllPoints(f)

    -- Modo barra. El contorno y el carril son color liso: una barra vacia no
    -- necesita arte, y un TGA para dos rectangulos seria peso por nada.
    local barBorder = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    barBorder:SetColorTexture(COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3], 0.85)
    barBorder:Hide()

    local barTrack = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    barTrack:SetColorTexture(COLOR_TRACK[1], COLOR_TRACK[2], COLOR_TRACK[3], 0.75)
    barTrack:Hide()

    local barFill = f:CreateTexture(nil, "ARTWORK", nil, 0)
    barFill:SetTexture(ART .. "BarFill")
    barFill:Hide()

    local barSpark = f:CreateTexture(nil, "ARTWORK", nil, 2)
    barSpark:SetTexture(ART .. "BarSpark")
    barSpark:SetBlendMode("ADD")
    barSpark:Hide()

    -- El mana por segundo. Solo se dibuja en modo barra, pero se crea siempre
    -- por lo mismo que la etiqueta: cambiar de piel no deberia construir nada.
    local rateText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rateText:SetDrawLayer("OVERLAY", 7)
    rateText:Hide()

    if mask then
        liquid:AddMaskTexture(mask)
        wave1:AddMaskTexture(mask)
        wave2:AddMaskTexture(mask)
        for i = 1, #bubbles do
            bubbles[i]:AddMaskTexture(mask)
        end
    end

    local timeText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetDrawLayer("OVERLAY", 7)

    -- Solo se dibuja en modo texto. Se crea siempre porque crear un
    -- FontString cuesta una vez y cambiar de estilo en caliente no deberia
    -- tener que construir nada.
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetDrawLayer("OVERLAY", 7)
    label:Hide()

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", f, "BOTTOM", 0, -2)
    hint:SetText(HINT_TEXT)
    hint:Hide()

    f:SetScript("OnDragStart", function(self)
        if not MB:GetDB().locked then
            self:StartMoving()
        end
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        D:SavePosition()
    end)

    -- El OnUpdate solo esta instalado mientras hay algo que animar, asi que el
    -- matraz visible pero en reposo (desbloqueado o con `/mb always on`) no
    -- cuesta nada por frame.
    self.onUpdate = function(_, elapsed)
        D:OnUpdate(elapsed)
    end

    self.frame = f
    self.dragArea = dragArea
    self.glow = glow
    self.liquid = liquid
    self.wave1 = wave1
    self.wave2 = wave2
    self.bubbles = bubbles
    self.glass = glass
    self.barBorder = barBorder
    self.barTrack = barTrack
    self.barFill = barFill
    self.barSpark = barSpark
    self.timeText = timeText
    self.label = label
    self.rateText = rateText
    self.hint = hint
    self.waveOffset1 = 0
    self.waveOffset2 = 0
    self.animElapsed = 0
    self.bubblesShown = false
    self.barShown = false
    -- Ultima opacidad escrita en cada burbuja, para no repetir la llamada.
    self.bubbleAlpha = {}

    self:ApplySettings()
end

function D:SavePosition()
    local db = MB:GetDB()
    local point, _, relPoint, x, y = self.frame:GetPoint()
    db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
end

-- Todo lo que depende del tamano del marco se calcula aqui, no por frame.
function D:Layout()
    if self.textMode then
        self:LayoutText()
    elseif self.barMode then
        self:LayoutBar()
    else
        self:LayoutFlask()
    end
end

-- El bloque de texto se dimensiona a la cadena mas ancha que puede aparecer,
-- una sola vez aqui. Asi el area de arrastre abraza lo que se ve y el marco
-- no cambia de tamano a mitad de una cuenta atras.
function D:LayoutText()
    local f = self.frame
    local h = MB:GetDB().height

    self.valueSize = floor(h * TEXT_VALUE_H + 0.5)
    self.labelSize = floor(h * TEXT_LABEL_H + 0.5)
    self.textSize = nil

    SetFontSize(self.timeText, self.valueSize, nil)
    SetFontSize(self.label, self.labelSize, nil)
    self.textSize = self.valueSize

    for _, fs in ipairs({ self.timeText, self.label }) do
        fs:SetShadowColor(0, 0, 0, 0.85)
        fs:SetShadowOffset(1, -1)
    end
    self.label:SetTextColor(COLOR_LABEL[1], COLOR_LABEL[2], COLOR_LABEL[3])

    local valueW = MeasureWidest(self.timeText, WIDEST_VALUE, self.valueSize * 3.2)
    local labelW = MeasureWidest(self.label, WIDEST_LABEL, self.labelSize * 7)
    local gap = h * TEXT_GAP
    local pad = h * TEXT_PAD

    f:SetSize(max(valueW, labelW) + pad,
        self.valueSize + gap + self.labelSize + pad)

    self.timeText:ClearAllPoints()
    self.timeText:SetPoint("TOP", f, "TOP", 0, -pad / 2)
    self.label:ClearAllPoints()
    self.label:SetPoint("TOP", self.timeText, "BOTTOM", 0, -gap)
end

-- La barra se dimensiona sola, como el bloque de texto, pero por otro motivo:
-- alla manda la cadena mas larga, aqui que una barra necesita ser mas ancha
-- que alta para leerse como tal.
function D:LayoutBar()
    local f = self.frame
    local db = MB:GetDB()
    local h = db.height
    local w = max(db.width, floor(h * BAR_MIN_ASPECT + 0.5))
    f:SetSize(w, h)

    local pad = floor(h * BAR_PAD + 0.5)
    local barH = max(4, floor(h * BAR_H + 0.5))
    local inner = max(1, w - pad * 2 - BAR_BORDER * 2)
    local gap = floor(h * BAR_GAP + 0.5)

    self.barWidth = inner

    self.barBorder:ClearAllPoints()
    self.barBorder:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
    self.barBorder:SetSize(inner + BAR_BORDER * 2, barH + BAR_BORDER * 2)

    self.barTrack:ClearAllPoints()
    self.barTrack:SetPoint("TOPLEFT", self.barBorder, "TOPLEFT", BAR_BORDER, -BAR_BORDER)
    self.barTrack:SetSize(inner, barH)

    self.barFill:ClearAllPoints()
    self.barFill:SetPoint("TOPLEFT", self.barTrack, "TOPLEFT", 0, 0)
    self.barFill:SetHeight(barH)

    -- El destello cuelga del borde derecho del relleno, igual que las olas
    -- cuelgan de la superficie del liquido: asi avanza solo cuando la barra
    -- crece y el OnUpdate no tiene que recolocarlo.
    self.barSpark:ClearAllPoints()
    self.barSpark:SetPoint("CENTER", self.barFill, "RIGHT", 0, 0)
    self.barSpark:SetSize(max(2, floor(barH * BAR_SPARK_W + 0.5)),
        floor(barH * BAR_SPARK_H + 0.5))

    self.valueSize = max(MIN_FONT, floor(h * BAR_VALUE_H + 0.5))
    self.labelSize = max(MIN_FONT, floor(h * BAR_LABEL_H + 0.5))
    self.textSize = nil

    -- La cifra va sobre el relleno, asi que pide OUTLINE y no sombra, como en
    -- el matraz. La linea de abajo va sobre el fondo del juego, como el modo
    -- texto, asi que pide lo contrario.
    self.timeText:SetShadowOffset(0, 0)
    -- El color de la fase lo lleva la barra; si la cifra lo llevara tambien,
    -- diria dos veces lo mismo y se perderia sobre su propio relleno.
    self.timeText:SetTextColor(1, 1, 1)
    self.timeText:ClearAllPoints()
    self.timeText:SetPoint("CENTER", self.barTrack, "CENTER", 0, 0)

    for _, fs in ipairs({ self.label, self.rateText }) do
        SetFontSize(fs, self.labelSize, nil)
        fs:SetShadowColor(0, 0, 0, 0.85)
        fs:SetShadowOffset(1, -1)
    end
    self.label:SetTextColor(COLOR_LABEL[1], COLOR_LABEL[2], COLOR_LABEL[3])
    -- El mana por segundo solo existe mientras regeneras, asi que lleva el
    -- verde de esa fase: es la cifra de lo que esta entrando.
    self.rateText:SetTextColor(COLOR_DONE[1], COLOR_DONE[2], COLOR_DONE[3])

    self.label:ClearAllPoints()
    self.label:SetPoint("TOPLEFT", self.barBorder, "BOTTOMLEFT", 0, -gap)
    self.rateText:ClearAllPoints()
    self.rateText:SetPoint("TOPRIGHT", self.barBorder, "BOTTOMRIGHT", 0, -gap)
end

function D:LayoutFlask()
    local f = self.frame
    local w, h = f:GetWidth(), f:GetHeight()
    local waveH = WAVE_H * h

    self.height = h
    self.width = w
    self.bottomPx = FILL_BOTTOM * h
    self.spanPx = (FILL_TOP - FILL_BOTTOM) * h

    self.liquid:ClearAllPoints()
    if self.masked then
        self.liquid:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        self.liquid:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    else
        -- Sin mascara el liquido seria un rectangulo asomando por fuera del
        -- cristal, asi que se encoge al ancho que cabe dentro del bulbo.
        local inset = 0.26 * w
        self.liquid:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", inset, 0)
        self.liquid:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, 0)
    end

    -- Las olas cuelgan del borde superior del liquido, asi que suben solas
    -- cuando el matraz se llena: el OnUpdate no las reposiciona.
    AnchorWave(self.wave1, self.liquid, waveH)
    AnchorWave(self.wave2, self.liquid, waveH)

    for i = 1, #self.bubbles do
        local size = BUBBLES[i].size * w * 2
        self.bubbles[i]:SetSize(size, size)
    end

    self.glow:SetSize(w / GLOW_SCALE, h / GLOW_SCALE)

    self.timeText:ClearAllPoints()
    self.timeText:SetPoint("CENTER", f, "BOTTOM", 0, BULB_CENTER * h)
    self.digitSize = floor(h * 0.30 + 0.5)
    self.wordSize = floor(h * 0.17 + 0.5)
    self.textSize = nil

    -- Sobre el cristal manda el OUTLINE, que lo pone SetText. La sombra y el
    -- color de fase son del modo texto: si se viene de ahi, hay que soltarlos,
    -- que si no el contador se queda verde sobre un matraz azul.
    self.timeText:SetShadowOffset(0, 0)
    self.timeText:SetTextColor(1, 1, 1)
end

function D:ApplySettings()
    if not self.frame then return end
    local db = MB:GetDB()

    self.frame:SetSize(db.width, db.height)
    self.frame:SetScale(db.scale)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    self.frame:EnableMouse(not db.locked)

    self:ApplyStyle()
    self:Layout()

    self.dragArea:SetShown(not db.locked)
    self.hint:SetShown(not db.locked)
    -- En modo texto la cifra ES el aviso: apagarla no dejaria nada en
    -- pantalla, asi que showText solo manda sobre el contador del matraz.
    self.timeText:SetShown(self.textMode or db.showText)

    self:SetFill(self.fill, true)
    self:UpdateShown()
end

-- El color de la fase en la que esta el motor. Cambiar de piel a mitad de un
-- ciclo tiene que repintarla, y cada piel lo lleva en una pieza distinta.
function D:PhaseColor()
    if self.state == "active" then return COLOR_ACTIVE end
    if self.state == "idle" or self.state == nil then return COLOR_IDLE end
    return COLOR_DONE
end

-- Enciende las piezas de una piel y apaga las de las otras. Va antes de Layout
-- porque todo lo demas se ramifica en estos tres booleanos.
function D:ApplyStyle()
    local style = MB:GetDB().style
    local textMode = style == "text"
    local barMode = style == "bar"
    self.textMode = textMode
    self.barMode = barMode
    -- El matraz es el valor por defecto y tambien el refugio: una piel que no
    -- conozcamos (una DB de una version mas nueva) dibuja el matraz, no nada.
    self.flaskMode = not (textMode or barMode)

    self.glass:SetShown(self.flaskMode)
    self.liquid:SetShown(self.flaskMode)
    self.wave1:SetShown(self.flaskMode)
    self.wave2:SetShown(self.flaskMode)
    self.label:SetShown(textMode or barMode)
    self.barBorder:SetShown(barMode)
    self.barTrack:SetShown(barMode)
    self.rateText:SetShown(barMode)
    if not barMode then
        -- El relleno y el destello los enciende SetFill, que sabe si hay barra
        -- que dibujar; aqui solo se apagan al salir de la piel.
        self.barShown = false
        self.barFill:Hide()
        self.barSpark:Hide()
    end

    if self.flaskMode then
        -- Volver al matraz a mitad de un ciclo tiene que devolverlo entero:
        -- estos dos se apagaron al salir y nadie los volveria a encender hasta
        -- el siguiente casteo.
        if self.state ~= "idle" and self.state ~= nil then
            self:ShowBubbles(true)
            self:RefreshGlow()
        end
    else
        -- El halo es la silueta del matraz y las burbujas suben por dentro del
        -- cristal: sin matraz no rodean ni suben por nada. Apagarlos aqui es
        -- ademas lo que deja a las otras dos pieles sin animacion por frame.
        self:SetGlow(false)
        self:ShowBubbles(false)
    end

    -- La etiqueta, el mana por segundo y el color de fase solo se escriben
    -- cuando cambian, y lo que cambia aqui es la pieza que los lleva: sin
    -- repintarlos, la piel nueva sale en blanco hasta la fase siguiente.
    self.shownLabel = nil
    self.shownRate = nil
    self:SetLabel(self.state == "regen" and LABEL_REGEN or LABEL_RULE)
    self:SetRate(self.regenRate)
    self:SetPhaseColor(self:PhaseColor())
end

function D:SetText(text, big)
    if self.flaskMode then
        local size = big and self.digitSize or self.wordSize
        if size ~= self.textSize then
            self.textSize = size
            SetFontSize(self.timeText, size, "OUTLINE")
        end
    else
        -- Un solo cuerpo de letra para la cifra y para la palabra: si midieran
        -- distinto, la linea daria un salto al pasar de "0.1" a "regen". El
        -- borde solo en la barra, que es donde la cifra va sobre el relleno.
        if self.textSize ~= self.valueSize then
            self.textSize = self.valueSize
            SetFontSize(self.timeText, self.valueSize, self.barMode and "OUTLINE" or nil)
        end
    end
    self.timeText:SetText(text)
end

-- La etiqueta solo cambia entre fases, no por frame, pero el guarda cuesta
-- menos que la llamada al API y mantiene la regla de la casa: nada se vuelve
-- a escribir si no ha cambiado.
function D:SetLabel(text)
    if self.flaskMode or text == self.shownLabel then return end
    self.shownLabel = text
    self.label:SetText(text)
end

-- El mana por segundo, o nil cuando todavia no hay medida. Se guarda aunque la
-- piel de turno no lo dibuje: el motor es uno, y asi cambiar a la barra a
-- mitad de la regeneracion no empieza en blanco.
function D:SetRate(rate)
    self.regenRate = rate
    if not self.barMode then return end
    local text = rate and format(RATE_FORMAT, rate) or ""
    if text == self.shownRate then return end
    self.shownRate = text
    self.rateText:SetText(text)
end

-- frac va de 0 a 1. force redibuja aunque no haya cambiado, que es lo que
-- hace falta tras un cambio de tamano.
function D:SetFill(frac, force)
    if frac == self.fill and not force then return end
    self.fill = frac
    -- Se sigue llevando la cuenta en modo texto aunque no haya nada que mover:
    -- es el mismo motor, y asi volver al matraz no empieza en blanco.
    if self.flaskMode then
        self.liquid:SetHeight(self.bottomPx + frac * self.spanPx)
    elseif self.barMode then
        self:DrawBar(frac)
    end
end

-- Lo unico que se mueve por frame en modo barra: el ancho del relleno. El
-- destello va colgado de su borde derecho, asi que avanza solo.
function D:DrawBar(frac)
    local width = floor(frac * self.barWidth + 0.5)
    if width < 1 then
        -- Cero no es un ancho valido, y a un pixel no hay barra que leer: se
        -- apagan las dos piezas en vez de encogerlas.
        if self.barShown then
            self.barShown = false
            self.barFill:Hide()
            self.barSpark:Hide()
        end
        return
    end

    if not self.barShown then
        self.barShown = true
        self.barFill:Show()
        self.barSpark:Show()
    end
    self.barFill:SetWidth(width)
end

-- El color de la fase. En el matraz lo lleva el liquido; en modo texto, la
-- cifra. Todo el motor llama aqui y no a uno de los dos, que es lo que hace
-- que el destello de cada tick funcione igual en las dos pieles.
function D:SetPhaseColor(color)
    if self.textMode then
        self.timeText:SetTextColor(color[1], color[2], color[3])
    elseif self.barMode then
        self.barFill:SetVertexColor(color[1], color[2], color[3])
        -- El destello, un punto por encima del relleno: es un borde de avance,
        -- no una parte mas de la barra.
        self.barSpark:SetVertexColor(min(1, color[1] * 1.3), min(1, color[2] * 1.3),
            min(1, color[3] * 1.3))
    else
        self:SetLiquidColor(color)
    end
end

function D:SetLiquidColor(color)
    self.liquid:SetVertexColor(color[1], color[2], color[3])
    self.wave1:SetVertexColor(color[1], color[2], color[3])
    self.wave2:SetVertexColor(color[1], color[2], color[3])
end

function D:SetGlow(enabled, color)
    if not self.flaskMode then enabled = false end
    self.glowing = enabled
    if enabled then
        self.glow:SetVertexColor(min(1, color[1] * 1.3), min(1, color[2] * 1.3),
            min(1, color[3] * 1.3))
        self.glow:SetAlpha(1)
    end
    self.glow:SetShown(enabled)
end

-- Releer la opcion del brillo en caliente. Sin esto, cambiarla a mitad de un
-- ciclo no se notaba hasta el siguiente, que parece que el mando no funciona.
function D:RefreshGlow()
    if not self.frame then return end
    local mode = MB:GetDB().glow
    if self.state == "active" then
        self:SetGlow(mode == "rule", COLOR_ACTIVE)
    elseif self.state == "done" or self.state == "regen" then
        self:SetGlow(mode == "regen", COLOR_DONE)
    end
end

function D:ShowBubbles(enabled)
    if not self.flaskMode then enabled = false end
    if enabled == self.bubbling then return end
    self.bubbling = enabled
    if not enabled then
        self.bubblesShown = false
        for i = 1, #self.bubbles do
            self.bubbles[i]:Hide()
        end
    end
end

function D:UpdateShown()
    if not self.frame then return end
    local db = MB:GetDB()

    local show
    if self.state ~= "idle" then
        show = true
    elseif not db.locked then
        -- Desbloqueado: siempre visible para poder colocarlo.
        show = true
    else
        show = db.alwaysShow and MB:UsesMana()
    end

    if show and self.state == "idle" then
        self:SetFill(IDLE_FILL)
        self:SetPhaseColor(COLOR_IDLE)
        -- El matraz en reposo se lee solo, con el liquido bajo y apagado. El
        -- texto en reposo no seria nada: necesita un marcador.
        self:SetText(self.textMode and IDLE_TEXT or "", false)
        self:SetLabel(LABEL_RULE)
        self:SetGlow(false)
        self:ShowBubbles(false)
    end

    self.frame:SetShown(show)
end

function D:SetUpdating(enabled)
    if enabled == self.updating then return end
    self.updating = enabled
    self.frame:SetScript("OnUpdate", enabled and self.onUpdate or nil)
end

function D:Start(startedAt, expires)
    if not self.frame then return end
    self.startedAt = startedAt
    self.expires = expires
    self.state = "active"
    self.holdLeft = nil
    self.shownTenths = nil
    self.flashLeft = nil
    -- El mana por segundo es de la fase de regeneracion: mientras la regla
    -- corre no entra mana, asi que dejar la ultima cifra ahi seria mentir.
    self:ClearRate()
    self.frame:SetAlpha(1)
    self:SetFill(0)
    self:SetPhaseColor(COLOR_ACTIVE)
    self:SetLabel(LABEL_RULE)
    self:SetGlow(MB:GetDB().glow == "rule", COLOR_ACTIVE)
    self:ShowBubbles(true)
    self.frame:Show()
    self:SetUpdating(true)
end

function D:Finish()
    local db = MB:GetDB()
    self.state = "done"
    self.holdLeft = HOLD_AFTER_DONE
    self:SetFill(1)
    self:SetPhaseColor(COLOR_DONE)
    self:SetText(DONE_TEXT, false)
    -- Aqui se acaba la regla: a partir de este instante el mana vuelve a
    -- subir, y eso es lo que marca el brillo.
    self:SetGlow(db.glow == "regen", COLOR_DONE)
    if db.sound then
        -- PlaySoundFile dice si va a sonar. Si el archivo falta porque alguien
        -- descomprimio el addon a medias, callarlo dejaria un mando que no
        -- hace nada sin que nadie sepa por que. Se avisa una vez por sesion.
        local willPlay = PlaySoundFile and PlaySoundFile(SOUND_DROP, "Master")
        if not willPlay and not self.soundWarned then
            self.soundWarned = true
            MB:Debug("no se pudo reproducir", SOUND_DROP)
        end
    end
end

-- Arranca la fase que ensena la regeneracion, y devuelve si ha arrancado.
-- Pide mana que subir: con el mana lleno no hay ticks que mostrar, asi que el
-- matraz se apaga como siempre.
function D:BeginRegen(now)
    if not MB:GetDB().holdRegen then return false end
    local fraction = MB:GetManaFraction()
    if fraction == nil or fraction >= 1 then return false end

    self.state = "regen"
    self:SetLabel(LABEL_REGEN)
    self.manaFraction = fraction
    self.manaPercent = floor(fraction * 100)
    self.shownPercent = nil
    self.lastTickAt = now
    self:ClearRate()
    return true
end

function D:ClearRate()
    self.rateMana = nil
    self.rateAt = nil
    self:SetRate(nil)
end

-- Mana por segundo, medido desde el PRIMER tick de la fase y no desde que
-- empieza: entre el fin de la regla y el primer tick cabe cualquier fraccion
-- del intervalo, y dividir por ella daria una cifra disparatada justo en el
-- momento que mas se mira. A cambio, la primera cifra aparece con el segundo
-- tick. El promedio es acumulado, asi que se va afinando solo.
function D:MeasureRate(now)
    local mana = MB:GetMana()
    if mana == nil then return end

    if self.rateMana == nil or mana < self.rateMana then
        -- Primer tick, o el mana ha bajado: no hay de donde medir todavia.
        self.rateMana, self.rateAt = mana, now
        return
    end

    local span = now - self.rateAt
    if span >= RATE_MIN_SPAN then
        self:SetRate((mana - self.rateMana) / span)
    end
end

-- Un tick de regeneracion. Core.lua lo llama cada vez que el mana sube, pero
-- solo significa algo durante la fase de regen.
function D:ManaTick()
    if self.state ~= "regen" then return end
    local now = GetTime()
    self.lastTickAt = now
    -- Se mide en las tres pieles aunque solo la barra lo dibuje: es una
    -- llamada al API por tick, uno cada dos segundos, y asi el motor sigue
    -- siendo uno. Lo que se apaga en una piel es lo que cuesta por frame.
    self:MeasureRate(now)

    local fraction = MB:GetManaFraction()
    if fraction == nil then return end

    self.manaFraction = min(1, fraction)
    self.manaPercent = floor(self.manaFraction * 100)

    if self.manaFraction >= 1 then
        -- Lleno: ya no hay nada que contar.
        self.flashLeft = nil
        self.state = "fading"
        self:SetFill(1)
        self:SetPhaseColor(COLOR_DONE)
        self:SetText("100%", false)
        return
    end

    self.flashLeft = TICK_FLASH
end

-- Fin de la fase desde fuera: salir de combate, o apagar la opcion. Deja el
-- mismo fundido de siempre.
function D:EndRegen()
    if self.state ~= "regen" then return end
    self.state = "fading"
end

function D:Reset()
    if not self.frame then return end
    self.state = "idle"
    self.holdLeft = nil
    self.shownTenths = nil
    self.flashLeft = nil
    self.manaFraction = nil
    self.manaPercent = nil
    self.shownPercent = nil
    self.lastTickAt = nil
    self:ClearRate()
    self.frame:SetAlpha(1)
    self:SetFill(0)
    self:SetText(self.textMode and IDLE_TEXT or "", false)
    self:SetLabel(LABEL_RULE)
    self:SetPhaseColor(COLOR_IDLE)
    self:SetGlow(false)
    self:ShowBubbles(false)
    self:SetUpdating(false)
    self:UpdateShown()
end

function D:UpdateBubbles(now)
    local surface = self.bottomPx + self.fill * self.spanPx
    local travel = surface - self.bottomPx
    if travel <= 2 then
        -- Casi sin liquido: no hay sitio por donde subir.
        if self.bubblesShown then
            self.bubblesShown = false
            for i = 1, #self.bubbles do
                self.bubbles[i]:Hide()
            end
        end
        return
    end

    -- Show() y SetAlpha() solo cuando cambian de verdad: llamarlos siempre era
    -- un tercio de las llamadas al API de la animacion, y la burbuja pasa el
    -- 70 % de su vida a opacidad constante.
    if not self.bubblesShown then
        self.bubblesShown = true
        for i = 1, #self.bubbles do
            self.bubbles[i]:Show()
        end
    end

    local w = self.width
    local alphas = self.bubbleAlpha
    for i = 1, #self.bubbles do
        local b = BUBBLES[i]
        local tex = self.bubbles[i]
        local t = (now * b.speed + b.phase) % 1
        local x = (b.x + sin(t * 6.0 + b.phase * 10.0) * 0.018) * w
        tex:SetPoint("CENTER", self.frame, "BOTTOM", x, self.bottomPx + t * travel)

        -- Aparece al despegar del fondo y se deshace al llegar arriba.
        local fade = 1
        if t < 0.12 then
            fade = t / 0.12
        elseif t > 0.82 then
            fade = (1 - t) / 0.18
        end
        local alpha = 0.55 * fade
        if alpha ~= alphas[i] then
            alphas[i] = alpha
            tex:SetAlpha(alpha)
        end
    end
end

-- Todo lo que se mueve por si solo, junto y a 30 Hz. step es el tiempo real
-- transcurrido desde el paso anterior, no ANIM_STEP: asi la ola avanza lo
-- mismo sea cual sea la tasa de frames.
function D:Animate(now, step)
    if self.glowing then
        -- Latido lento. abs(sin) sube y baja mas rapido que un seno pelado,
        -- que es lo que se quiere de un brillo.
        self.glow:SetAlpha(0.5 + 0.5 * abs(sin(now * 3.0)))
    end

    if self.bubbling then
        self.waveOffset1 = (self.waveOffset1 + WAVE_SPEED_1 * step) % 1
        self.waveOffset2 = (self.waveOffset2 + WAVE_SPEED_2 * step) % 1
        self.wave1:SetTexCoord(self.waveOffset1, self.waveOffset1 + WAVE_SPAN, 0, 1)
        self.wave2:SetTexCoord(self.waveOffset2, self.waveOffset2 + WAVE_SPAN * 0.7, 0, 1)
        self:UpdateBubbles(now)
    end
end

function D:OnUpdate(elapsed)
    local now = GetTime()

    -- Destello de un tick: el liquido se aclara y vuelve. Es lo que hace que
    -- la fase de regen se lea como "esta entrando mana" y no como una imagen fija.
    if self.flashLeft then
        self.flashLeft = self.flashLeft - elapsed
        if self.flashLeft <= 0 then
            self.flashLeft = nil
            self:SetPhaseColor(COLOR_DONE)
        else
            local t = self.flashLeft / TICK_FLASH
            for i = 1, 3 do
                FLASH[i] = COLOR_DONE[i] + (COLOR_TICK[i] - COLOR_DONE[i]) * t
            end
            self:SetPhaseColor(FLASH)
        end
    end

    if self.state == "active" then
        local remaining = self.expires - now
        if remaining <= 0 then
            self:Finish()
            return
        end

        local filled = MB.RULE_DURATION - remaining
        self:SetFill(filled / MB.RULE_DURATION)

        -- El contador solo cambia cuando hay algo nuevo que mostrar: a 60 fps
        -- cambia 10 veces por segundo. Sin esto serian 60 SetText por segundo
        -- para el mismo resultado visible.
        local tenths = floor(remaining * 10)
        if tenths ~= self.shownTenths then
            self.shownTenths = tenths
            self:SetText(TENTH_TEXT[tenths] or "", true)
        end

    elseif self.state == "done" then
        self.holdLeft = self.holdLeft - elapsed
        if self.holdLeft <= 0 and not self:BeginRegen(now) then
            self.state = "fading"
        end

    elseif self.state == "regen" then
        -- El liquido persigue al mana: el matraz pasa de estar lleno (la regla
        -- acabada) a marcar lo que de verdad tienes, y sube con cada tick.
        if self.fill ~= self.manaFraction then
            self:SetFill(Approach(self.fill, self.manaFraction, elapsed))
        end

        if self.shownPercent ~= self.manaPercent then
            self.shownPercent = self.manaPercent
            -- Un format por cambio de entero, no por frame: unas pocas veces
            -- por segundo y, siendo cadenas cortas, Lua las reaprovecha.
            self:SetText(format("%d%%", self.manaPercent), false)
        end

        if now - self.lastTickAt >= REGEN_TIMEOUT then
            self.state = "fading"
        end

    elseif self.state == "fading" then
        local alpha = self.frame:GetAlpha() - elapsed / FADE_DURATION
        if alpha <= 0 then
            self:Reset()
            return
        end
        self.frame:SetAlpha(alpha)
    end

    -- Olas, burbujas y halo siguen corriendo mientras el matraz se apaga:
    -- congelarlos justo cuando se llena deja el ultimo segundo con cara de
    -- captura. Pero a 30 Hz, no por frame.
    if self.bubbling or self.glowing then
        self.animElapsed = self.animElapsed + elapsed
        if self.animElapsed >= ANIM_STEP then
            local step = self.animElapsed
            self.animElapsed = 0
            self:Animate(now, step)
        end
    end
end
