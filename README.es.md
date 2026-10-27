# ManaBreath

[English](README.md) · **Español**

Addon para **World of Warcraft: Forever** que muestra cuándo está activa la
**regla de 5 segundos** de regeneración de maná (5SR): un matraz animado se
llena durante los 5 segundos posteriores a gastar maná, lleva la cuenta atrás
dentro del bulbo y, cuando la regla acaba, se queda encendido marcando el maná
que entra con cada tick hasta que se llene o salgas de combate.

Liviano y enfocado en una sola cosa: nada de pociones, gemas ni runas.

## Instalación

1. Copia la carpeta del addon en `Interface\AddOns\` del cliente de Forever.
   **La carpeta debe llamarse exactamente `ManaBreath`.**
2. Reinicia el juego (o `/reload`) y activa el addon en la lista de addons.

## Uso

El matraz aparece solo cuando gastas maná y se oculta cuando ya no queda nada
que contar. Para colocarlo:

```
/mb unlock     arrastra el matraz con el botón izquierdo
/mb lock       lo fija en su sitio
```

### Qué muestra el matraz

El matraz pasa por dos fases y el color las distingue.

**Azul — la regla corre.** No estás regenerando maná.

| | |
| --- | --- |
| Nivel del líquido | Cuánto ha pasado de los 5 segundos: lleno significa que la regla terminó |
| Número en el bulbo | Segundos que faltan, con un decimal |
| Olas y burbujas | La regla está corriendo |

**Verde — estás regenerando.** Empieza en el instante en que la regla acaba.

| | |
| --- | --- |
| Nivel del líquido | Tu maná real, de 0 a 100 % |
| Número en el bulbo | El porcentaje de maná |
| Destello del líquido | Acaba de entrar un tick de regeneración |
| **Brillo alrededor del matraz** | Estás regenerando maná |

La fase verde se cierra de cuatro maneras: el maná se llena, sales de combate,
vuelves a gastar maná (y entonces arranca otra vez la regla azul) o pasan
4 segundos sin un solo tick. Lo último es una red de seguridad: si este cliente
no avisa de cada tick de maná, el matraz se apaga en vez de quedarse encendido
para siempre. Con `/mb regen off` el matraz se apaga en cuanto acaba la regla.

Con `/mb sound on` suena una gota justo al cumplirse la regla, que es el
instante en que el maná vuelve a subir. Es un archivo propio del addon
(`Sound/ManaDrop.ogg`, 8,5 KB) y no un sonido prestado de la interfaz, y suena
en las dos pieles. Si el archivo faltara por haber descomprimido el addon a
medias, `/mb debug on` lo dice, en vez de dejar un mando que no hace nada.

El brillo alumbra una sola fase, la que elijas: encenderlo en las dos lo dejaría
sin decir nada. Por defecto (`/mb glow regen`) alumbra la verde, que es la única
en la que de verdad estás recuperando maná; `/mb glow rule` lo pasa a los
5 segundos de la regla y `/mb glow off` lo apaga.

### Las dos pieles

El matraz es una piel, no el addon. `/mb style text` lo cambia por una lectura
sobria, solo de letras: la cifra, y debajo una etiqueta pequeña espaciada.

```
      4.3                 62%
     5 S R               M A N A
```

| | Matraz | Texto |
| --- | --- | --- |
| La regla corriendo | Líquido subiendo, olas, burbujas | `4.3` en azul, sobre `5 S R` |
| La regla cumplida | Matraz lleno, `regen` | `regen` en verde, sobre `5 S R` |
| Regenerando | El líquido sigue tu maná | `62%` en verde, sobre `M A N A` |
| Entra un tick | Destella el líquido | Destella la cifra |
| Halo | Opcional, alrededor del matraz | No hay: no hay silueta que rodear |

Las dos pieles corren el **mismo motor**: los mismos estados, los mismos
tiempos, la misma detección. Lo único que cambia es el dibujo, así que un
arreglo en la regla vale para las dos y no hay una segunda verdad que mantener
al día.

En modo texto cambian tres cosas, y el comando lo dice al cambiar: no hay halo,
no hay burbujas y `/mb text off` no hace nada, porque la cifra es lo único que
hay en pantalla y apagarla dejaría el marco vacío. El marco se dimensiona a la
cadena más larga que puede llegar a mostrar, medida una sola vez, para que el
bloque no baile a mitad de la cuenta atrás; `/mb size` sigue poniendo el alto,
que es lo que manda sobre el cuerpo de letra, y el ancho lo pone el texto.

El modo texto es además el barato: sin olas, burbujas ni halo no queda nada que
animar, y eso lo baja de ~5 llamadas al API por frame a ~1.

### Configuración

Todo se puede configurar de dos maneras, y las dos escriben en el mismo sitio:

- **Opciones → AddOns → ManaBreath**, o `/mb config`, o el botón del
  compartimento de addons junto al minimapa. El panel lo dibuja el propio juego
  a partir de las opciones que el addon declara, así que no hay una interfaz
  propia que se vea fuera de lugar.
- **Comandos de barra**, la vía que nunca falla. Si este cliente no expusiera
  el API de ajustes, el addon no registra panel, lo dice al abrirlo y sigue
  funcionando entero por `/mb`.

Los cambios se aplican al momento, sin `/reload`, y en los dos sentidos: un
`/mb glow rule` deja el desplegable del panel al día, y marcar una casilla se
nota en el matraz aunque la regla esté corriendo.

### Comandos

| Comando | Qué hace |
| --- | --- |
| `/mb config` | Abre el panel de opciones |
| `/mb lock` / `/mb unlock` | Fija o libera el matraz |
| `/mb test` | Demo de 5 segundos |
| `/mb style flask/text` | Matraz animado, o solo letras |
| `/mb scale <0.5 - 3>` | Escala del matraz: la forma correcta de agrandarlo |
| `/mb size <ancho> <alto>` | Tamaño del marco; el dibujo supone un marco cuadrado |
| `/mb sound on/off` | Una gota de agua al terminar la regla |
| `/mb glow regen/rule/off` | Cuándo brilla el matraz |
| `/mb regen on/off` | Seguir el maná que vuelve cuando la regla acaba |
| `/mb text on/off` | Contador dentro del bulbo |
| `/mb always on/off` | Mantener el matraz siempre visible |
| `/mb fallback on/off` | Detectar también por bajadas de maná |
| `/mb channel on/off` | Reiniciar el contador al cortar una canalización |
| `/mb verify` | Mide contra el cliente si la regla de 5 s existe de verdad |
| `/mb debug on/off` | Imprime el costo leído de cada casteo |
| `/mb status` | Estado actual, el contexto restringido y de dónde se leen los costes |
| `/mb reset` | Vuelve a los valores por defecto |

`/manabreath` funciona como alias de `/mb`.

## Cómo detecta el gasto de maná

Forever corre sobre el cliente **Retail de Midnight**, donde
`COMBAT_LOG_EVENT_UNFILTERED` ya no sirve para addons. La detección no depende
del combat log:

1. **Principal** — `UNIT_SPELLCAST_SUCCEEDED` filtrado a `player`; el costo se
   consulta con `C_Spell.GetSpellPowerCost(spellID)`, que es el reemplazo 12.0
   del antiguo `GetSpellPowerCost` global (el addon usa el global como
   respaldo). Los datos estáticos de hechizo del namespace `C_Spell` no son
   secretos, así que esta es la vía fiable.
2. **Canalizaciones** — `UNIT_SPELLCAST_CHANNEL_START` arranca el contador y
   `UNIT_SPELLCAST_CHANNEL_STOP` lo reinicia, porque el maná se consume
   mientras dura el canal. Como una canalización dispara `SUCCEEDED` y
   `CHANNEL_START` a la vez, el addon descarta el duplicado comparando el
   `castGUID`, que nunca es secreto.
3. **Costes condicionados** — una entrada con `hasRequiredAura` solo aplica si
   cierta aura está presente (normalmente de especialización o de forma), así
   que no cuenta como coste seguro y se confirma mirando el maná. Y si el API
   devuelve `nil` o una tabla vacía, el hechizo no cuesta recursos: eso es un
   "no", no un "no se pudo leer".
4. **Secret Values** — si el coste llega protegido, el addon confirma el gasto
   solo si el maná baja dentro de ~0,35 s. La ventana es **simétrica**: no está
   garantizado el orden en que el cliente entrega `UNIT_POWER_UPDATE` y
   `UNIT_SPELLCAST_SUCCEEDED`, así que vale tanto si el descuento llega antes
   del casteo como después. Todo valor que viene del juego pasa por
   `issecretvalue()` antes de usarse.
5. **Respaldo opcional** (`/mb fallback on`, apagado por defecto) — cualquier
   bajada de maná en `UNIT_POWER_UPDATE` arranca el contador. Da falsos
   positivos: si un enemigo te quema maná, eso no activa la regla.

Los hechizos fallidos o interrumpidos no disparan `UNIT_SPELLCAST_SUCCEEDED`,
así que no arrancan el contador.

### Secret Values: qué toca y qué no

El **matraz no toca datos protegidos en ningún momento**. Se dibuja con
`GetTime()` y la constante de 5 segundos, ambos valores normales, así que no
necesita `Curve`, `ColorCurve` ni `Duration` para pintarse.

Lo único que mira datos de combate es la **detección**, y solo en dos puntos:
el `spellID` del casteo y `UnitPower("player", MANA)` del respaldo. Los dos van
envueltos en `issecretvalue()`; si llegan protegidos, el addon no adivina ni
hace aritmética: se queda en el camino de confirmación por maná.

`/mb status` informa de `C_RestrictedActions.IsRestricted()`. Es lo primero que
hay que mirar si el addon funciona en el mundo abierto pero falla dentro de una
mazmorra: indica que estás en un contexto donde más valores llegan protegidos.

### Qué es determinista y qué no

La API de WoW **no informa del estado de la regla de 5 segundos**. No hay
evento, bandera ni consulta: es una mecánica del servidor de la que el cliente
nunca se entera. Lo más cercano es `GetPowerRegen()`, que devuelve tus dos
tasas de regeneración pero no cuál está vigente ni cuándo empezó la ventana.
Todo addon de 5SR que ha existido reconstruye la regla por inferencia.

Lo que la API **sí** da de forma determinista son tres hechos: que completaste
un casteo, cuánto cuesta ese hechizo, y que tu maná cambió y en cuánto. Lo que
no da es la **atribución**: por qué bajó el maná. Combinar casteo + coste
resuelve la atribución para el caso normal, y eso no es una adivinanza.

Sobre esa base, el addon es determinista en lo suyo: misma secuencia de eventos
→ mismo estado, sin aleatoriedad, independiente del framerate (el matraz usa
diferencias de `GetTime()`, no cuenta frames) y sin deriva acumulada. Y falla
cerrado: un coste ilegible nunca produce un contador falso.

Lo que queda fuera de nuestro control:

- **Latencia.** La ventana arranca cuando el cliente recibe la confirmación del
  servidor, no cuando el servidor cobró el maná. Límite de cualquier addon.
- **El 5.0 está fijo en el código** y es una suposición sobre Forever.
  `/mb verify` sirve para comprobarla.
- **El reinicio al cortar una canalización es una inferencia** de la mecánica
  de vanilla, no un hecho verificado. Si resulta falso, `/mb channel off`.
- **Drenajes de maná enemigos** dentro de la ventana de confirmación pueden dar
  un falso positivo. Acotado a ~0,35 s, o sin acotar si activas
  `/mb fallback on`.

### Sobre `## Interface: 16001`

La interfaz se codifica como `MMmmpp`. El Midnight estándar usa `120001`
(= 12.0.1), pero Forever reporta su propia banda de versión: `16001` decodifica
como **1.60.1**, que coincide con el build documentado del cliente. Por eso
aquí no va `120001` aunque el motor sea el de Midnight.

Tampoco se declara `## AllowLoadGameType:`. Ese campo restringe la carga a un
tipo de cliente concreto (`Mainline`, `Classic`, …) y no está confirmado cuál
reporta Forever: si se pusiera el valor equivocado, el addon simplemente no
cargaría.

## Eficiencia y memoria

Medido fuera del juego con `lua tests/bench.lua`, **con el recolector parado
durante cada medición**. Eso importa: si el recolector corre, lo que se lee no
es lo que el addon asigna sino lo que no alcanzó a liberar, y eso cambia con el
tamaño del montón. El banco medía así hasta la 1.1.0, y por eso daba 3–12 bytes
por casteo cuando la cifra real es 320.

| | |
| --- | --- |
| Huella estática (cargado e inicializado) | ~106 KB, más ~12 KB al registrar el panel |
| En reposo, matraz oculto | **0 bytes/frame, sin `OnUpdate` instalado** |
| Matraz visible pero en reposo (`/mb always on`) | **0 bytes/frame, sin `OnUpdate` instalado** |
| 600 frames de fase azul | **0 bytes** |
| 600 frames de fase verde | **0 bytes/frame** · ~24 bytes por cambio de porcentaje |
| `UNIT_POWER_UPDATE` | **0 bytes** |
| Por casteo | ~320 bytes, todo la tabla que devuelve `C_Spell.GetSpellPowerCost` |
| Ciclo completo de 5 s | ~370 bytes, el casteo incluido |
| Llamadas al API por frame animando | ~5 (matraz) · ~1 (texto) |
| Deriva tras 200 ciclos + 400 casteos + 2000 `UNIT_POWER_UPDATE` | **−0,04 KB (sin fuga)** |

Cuatro decisiones explican esos números:

- **El `OnUpdate` solo está instalado mientras hay algo que animar.** Se pone
  al arrancar el contador y se quita al acabar el fundido. En reposo el addon
  no ejecuta nada por frame, ni siquiera con el matraz visible.
- **La animación corre a 30 Hz, no por frame.** A 58 px el líquido mide 36 px
  de alto y la burbuja más rápida lo recorre en 2 segundos: 0,6 px por paso de
  30 Hz. Pedir 60 Hz era pagar el doble de llamadas al API para mover medio
  píxel. El nivel del líquido y el contador sí van por frame, que es lo que se
  mira de cerca. Es `ANIM_STEP` en `Display.lua`.
- **El contador no construye cadenas.** La ventana es fija (0,0–5,0), así que
  las 51 posibles se precalculan al cargar; el contador cambia diez veces por
  segundo. El porcentaje de la fase verde **no** se precalcula: cambia unas
  pocas veces por segundo, y Lua reaprovecha las cadenas cortas, así que
  formatearlo en el momento sale gratis en régimen y ahorra ~4 KB residentes.
  Precalcularlo también era pagar memoria permanente por nada.
- **La animación no asigna nada.** Las burbujas son una tabla fija, sin
  `math.random` por frame; las olas se desplazan con `SetTexCoord`; y las
  bandas de ola cuelgan del borde superior del líquido, así que subir el nivel
  las sube con él sin un solo `SetPoint`. El contador solo se redibuja cuando
  cambia la décima, y el porcentaje solo cuando cambia el entero. El color del
  destello de cada tick se calcula sobre una tabla que se reutiliza.

De esos ~118 KB, unos 6 KB son `Verify.lua`, que solo se usa una vez para
comprobar la regla en el juego, y unos 29 KB son el panel de opciones: ~17 KB
de `Options.lua` y ~12 KB de los objetos que el sistema de ajustes crea al
declarar las once opciones. Las dos son decisiones conscientes y del mismo
tipo: memoria residente a cambio de que el addon se pueda medir y configurar
sin leerse el README. Si alguna vez esos 29 KB molestaran, quitar `Options.lua`
del `.toc` devuelve el addon a ~89 KB sin tocar nada más: los comandos no
dependen del panel.

La piel de texto cuesta unos 12 KB de ese total, y los cuesta se use o no: las
dos pieles se construyen al cargar, así que cambiar de una a otra dibuja al
momento en vez de montar widgets a mitad de una regla.

Lo único que asigna de forma inevitable es `C_Spell.GetSpellPowerCost`, que
devuelve una tabla nueva en cada llamada. Son ~320 bytes por casteo y
**no se cachea a propósito**: una aura tipo Clearcasting puede dejar un hechizo gratis,
y un coste cacheado arrancaría la regla en un casteo que no gastó maná.

## Verificar en el juego (pendiente hasta el lanzamiento)

- [ ] `/dump select(4, GetBuildInfo())` — confirmar que la interfaz es `16001`.
- [ ] Confirmar que el addon aparece en la lista. El paquete lleva un solo
      `ManaBreath.toc`, sin sufijo de sabor: el cliente carga el específico de
      su sabor si existe y, si no, el genérico, así que el genérico cubre
      cualquier sufijo que use Forever. Si no carga, el problema es el número
      de interfaz, no el nombre del archivo.
- [ ] Confirmar que el `spellID` de `UNIT_SPELLCAST_SUCCEEDED` del propio
      jugador no llega como Secret Value en combate (con `/mb debug on` se
      imprime `yes` / `no` / `unknown` por cada casteo).
- [ ] Confirmar que Forever mantiene la regla de 5 s igual que vanilla, con
      `/mb verify`: ármalo, lanza un hechizo que gaste maná y no hagas nada
      más. Mide el maná dentro y fuera de la ventana y compara contra
      `GetPowerRegen()`. Hazlo fuera de combate, fuera de instancia y con el
      maná por debajo del máximo, o no hay regeneración que medir.
- [ ] Confirmar si una canalización cobra el maná por tick o todo al empezar.
      Si es al empezar, `/mb channel off`.
- [ ] Confirmar la ruta final de addons del cliente (en la beta era
      `_classic_beta_\Interface\AddOns\`).
- [ ] Confirmar que los TGA cargan. Si el matraz sale como un damero verde y
      negro, el cliente rechazó el formato; si no sale nada, revisar que la
      carpeta se llame exactamente `ManaBreath`, porque la ruta del arte se
      construye con el nombre del addon.
- [ ] Confirmar que la `MaskTexture` recorta el líquido. Si el líquido sale
      como un rectángulo asomando por fuera del cristal, la máscara no cargó.
- [ ] Confirmar que el panel aparece en Opciones → AddOns y que los controles
      mueven de verdad las opciones. El API de ajustes es de la 10.0 y su firma
      cambió en la 11.0; el addon asume la moderna y, si no es esa, no registra
      panel y lo dice con `/mb config`. En ese caso hay que mirar
      `O:Register` en `Options.lua`, que es el único punto que depende de la
      firma.
- [ ] Confirmar que la fase verde sigue al maná de verdad: que el porcentaje
      suba con cada tick, que el matraz se apague al llenarse el maná y que
      `PLAYER_REGEN_ENABLED` lo apague al salir de combate. Si el cliente no
      dispara `UNIT_POWER_UPDATE` por cada tick, la fase se cerrará sola a los
      4 segundos; en ese caso sube `REGEN_TIMEOUT` en `Display.lua`.

## El arte

El matraz está generado, no dibujado a mano:

```
python tools/make_art.py
```

Ese script escribe los siete TGA de `Art/` a partir de campos de distancia
—cristal, máscara del interior, líquido, banda de ola, burbuja, halo y el icono
de la lista de addons— y además `tools/preview.png` para mirarlos fuera del
juego. No necesita ninguna biblioteca externa. `tools/` no se empaqueta.

El líquido, las olas y las burbujas van recortados por una `MaskTexture` con la
forma del interior del cristal, así que nada se sale del matraz por mucho que
se cambie el tamaño del marco. Si un cliente no expone `CreateMaskTexture`, el
addon se degrada en vez de romperse: el líquido se encoge para caber dentro del
bulbo.

Las constantes de geometría viven en dos sitios: `tools/make_art.py` y las
constantes `FILL_*` / `GLOW_SCALE` de `Display.lua`. Mover el dibujo es mover
los dos.

## Desarrollo

El repo trae un `.luarc.json` que declara los globales de la API de WoW y fija
el runtime en Lua 5.1. Sin él, el servidor de lenguaje marca las 44
referencias a la API como indefinidas y avisa de `unpack` como obsoleto,
ruido que tapa cualquier aviso de verdad. No se empaqueta.


Las pruebas corren fuera del juego, contra una API falsa de WoW:

```
lua tests/run.lua
```

Cubren el arranque y reinicio del contador, canalizaciones, deduplicación por
`castGUID`, Secret Values, contexto restringido (con y sin
`C_RestrictedActions`), clases y formas sin maná, y todos los comandos. El
mock hace que tocar un valor secreto lance error, igual que WoW, así que una
guarda `issecretvalue()` que falte sale como fallo y no pasa inadvertida.

El banco de memoria va aparte, y mide con el recolector parado:

```
lua tests/bench.lua
```

Y el perfilador cuenta llamadas al API por frame en cada fase, que es la otra
mitad de la pregunta: una animación puede no asignar un solo byte y estar
llamando al cliente cuarenta veces por frame.

```
lua tests/profile.lua
```

## Licencia

MIT — ver [LICENSE](LICENSE).
