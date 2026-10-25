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
3. **Secret Values** — si el costo llega protegido, el addon espera ~0.35 s y
   confirma el gasto solo si el maná baja en esa ventana. Todo valor que viene
   del juego pasa por `issecretvalue()` antes de usarse.
4. **Respaldo opcional** (`/mb fallback on`, apagado por defecto) — cualquier
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

### Sobre `## Interface: 16001`

La interfaz se codifica como `MMmmpp`. El Midnight estándar usa `120001`
(= 12.0.1), pero Forever reporta su propia banda de versión: `16001` decodifica
como **1.60.1**, que coincide con el build documentado del cliente. Por eso
aquí no va `120001` aunque el motor sea el de Midnight.

Tampoco se declara `## AllowLoadGameType:`. Ese campo restringe la carga a un
tipo de cliente concreto (`Mainline`, `Classic`, …) y no está confirmado cuál
reporta Forever: si se pusiera el valor equivocado, el addon simplemente no
cargaría.

## Verificar en el juego (pendiente hasta el lanzamiento)

- [ ] `/dump select(4, GetBuildInfo())` — confirmar que la interfaz es `16001`.
- [ ] Confirmar el sufijo de `.toc` que usa Forever. El repo incluye
      `ManaBreath.toc` y `ManaBreath_Camelot.toc`: el cliente carga el
      específico de su sabor si existe y, si no, el genérico. Si el sufijo real
      es otro, renombra la copia.
- [ ] Confirmar que el `spellID` de `UNIT_SPELLCAST_SUCCEEDED` del propio
      jugador no llega como Secret Value en combate (con `/mb debug on` se
      imprime `yes` / `no` / `unknown` por cada casteo).
- [ ] Confirmar que Forever mantiene la regla de 5 s igual que vanilla.
- [ ] Confirmar la ruta final de addons del cliente (en la beta era
      `_classic_beta_\Interface\AddOns\`).

## Desarrollo

Las pruebas corren fuera del juego, contra una API falsa de WoW:

```
lua tests/run.lua
```

Cubren el arranque y reinicio del contador, canalizaciones, deduplicación por
`castGUID`, Secret Values, contexto restringido (con y sin
`C_RestrictedActions`), clases y formas sin maná, y todos los comandos.

## Licencia

MIT — ver [LICENSE](LICENSE).
