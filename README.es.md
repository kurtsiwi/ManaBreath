# ManaBreath

[English](README.md) · **Español**

Addon para **World of Warcraft: Forever** que muestra cuándo está activa la
**regla de 5 segundos** de regeneración de maná (5SR): una barra se llena
durante los 5 segundos posteriores a gastar maná y avisa cuando la
regeneración vuelve.

Liviano y enfocado en una sola cosa: nada de pociones, gemas ni runas.

## Instalación

1. Copia la carpeta del addon en `Interface\AddOns\` del cliente de Forever.
   **La carpeta debe llamarse exactamente `ManaBreath`.**
2. Reinicia el juego (o `/reload`) y activa el addon en la lista de addons.

## Uso

La barra aparece sola cuando gastas maná y se oculta al terminar. Para
colocarla:

```
/mb unlock     arrastra la barra con el botón izquierdo
/mb lock       la fija en su sitio
```

### Comandos

| Comando | Qué hace |
| --- | --- |
| `/mb lock` / `/mb unlock` | Fija o libera la barra |
| `/mb test` | Demo de 5 segundos |
| `/mb scale <0.5 - 3>` | Escala de la barra |
| `/mb size <ancho> <alto>` | Tamaño de la barra |
| `/mb sound on/off` | Aviso sonoro al terminar la regla |
| `/mb text on/off` | Textos sobre la barra |
| `/mb always on/off` | Mantener la barra siempre visible |
| `/mb fallback on/off` | Detectar también por bajadas de maná |
| `/mb channel on/off` | Reiniciar el contador al cortar una canalización |
| `/mb verify` | Mide contra el cliente si la regla de 5 s existe de verdad |
| `/mb debug on/off` | Imprime el costo leído de cada casteo |
| `/mb status` | Estado actual, incluido el contexto restringido |
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
3. **Costes condicionados** — una entrada de coste con `hasRequiredAura` solo
   aplica si cierta aura está presente, así que no cuenta como coste seguro y
   se confirma mirando el maná. Sin esto, un hechizo que un aura dejó gratis
   arrancaría la regla sin que hubieras gastado nada.
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

La **barra no toca datos protegidos en ningún momento**. Se dibuja con
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
→ mismo estado, sin aleatoriedad, independiente del framerate (la barra usa
diferencias de `GetTime()`, no cuenta frames) y sin deriva acumulada. Y falla
cerrado: un coste ilegible nunca produce una barra falsa.

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

Medido fuera del juego con `lua tests/bench.lua`:

| | |
| --- | --- |
| Huella estática (cargado e inicializado) | ~56 KB |
| En reposo, barra oculta | **0 bytes/frame, sin `OnUpdate` instalado** |
| Barra visible pero en reposo (`/mb always on`) | **0 bytes/frame, sin `OnUpdate` instalado** |
| Barra activa a 60 fps | ~1 byte/frame |
| Ciclo completo de 5 s | ~0,18 KB |
| `UNIT_POWER_UPDATE` | sin basura medible |
| Por casteo | 3–12 bytes |
| Deriva tras 200 ciclos + 400 casteos + 2000 `UNIT_POWER_UPDATE` | **−0,04 KB (sin fuga)** |

Tres decisiones explican esos números:

- **El `OnUpdate` solo está instalado mientras hay algo que animar.** Se pone
  al arrancar el contador y se quita al acabar el fundido. En reposo el addon
  no ejecuta nada por frame, ni siquiera con la barra visible.
- **El contador no construye cadenas.** La ventana es fija (0,0–5,0), así que
  las 51 cadenas posibles se precalculan al cargar. Un `string.format` por
  frame generaría basura 60 veces por segundo.
- **Texto y chispa solo se actualizan cuando cambian.** A 60 fps el contador
  cambia 10 veces por segundo y la chispa se mueve un píxel cada varios
  frames; el resto de los `SetText` y `SetPoint` serían trabajo invisible.

De esos ~56 KB, unos 8 KB son `Verify.lua`, que solo se usa una vez para
comprobar la regla en el juego. Es una decisión consciente: cuesta memoria
residente a cambio de poder medir en vez de suponer.

Lo único que asigna de forma inevitable es `C_Spell.GetSpellPowerCost`, que
devuelve una tabla nueva en cada llamada. Son unos pocos bytes por casteo y
**no se cachea a propósito**: una aura tipo Clearcasting puede dejar un hechizo gratis,
y un coste cacheado arrancaría la regla en un casteo que no gastó maná.

## Verificar en el juego (pendiente hasta el lanzamiento)

- [ ] `/dump select(4, GetBuildInfo())` — confirmar que la interfaz es `16001`.
- [ ] Confirmar el sufijo de `.toc` que usa Forever. El repo incluye
      `ManaBreath.toc` y `ManaBreath_Camelot.toc`: el cliente carga el
      específico de su sabor si existe y, si no, el genérico. Si el sufijo real
      es otro, renombra la copia.
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

## Desarrollo

Las pruebas corren fuera del juego, contra una API falsa de WoW:

```
lua tests/run.lua
```

Cubren el arranque y reinicio del contador, canalizaciones, deduplicación por
`castGUID`, Secret Values, contexto restringido (con y sin
`C_RestrictedActions`), clases y formas sin maná, y todos los comandos. El
mock hace que tocar un valor secreto lance error, igual que WoW, así que una
guarda `issecretvalue()` que falte sale como fallo y no pasa inadvertida.

El banco de memoria va aparte:

```
lua tests/bench.lua
```

## Licencia

MIT — ver [LICENSE](LICENSE).
