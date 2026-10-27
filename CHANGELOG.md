# Changelog

## 1.1.0

- La barra pasa a ser un **matraz**: el líquido sube durante los 5 segundos y
  el contador va dentro del bulbo.
- Superficie animada (dos capas de ola a distinta velocidad) y burbujas que
  suben mientras la regla corre.
- **Fase de regeneración**: al acabar la regla el matraz no se apaga, se pone
  verde y se queda marcando el maná que entra. El líquido sigue tu maná real,
  el número pasa a ser el porcentaje y cada tick de maná da un destello. La
  fase se cierra al llenarse el maná, al salir de combate, al volver a gastar
  maná (que reinicia la regla) o a los 4 segundos sin ningún tick, que es la
  red de seguridad si el cliente no avisa de cada uno. `/mb regen off` vuelve
  al aviso corto de la 1.0.
- **Brillo alrededor del matraz** mientras estás regenerando, que es la fase
  verde. `/mb glow rule` lo pasa a los 5 segundos de la regla y `/mb glow off`
  lo apaga.
- Arte propio, generado con `tools/make_art.py`: el líquido se recorta con una
  `MaskTexture` con la forma del interior del cristal, así que nada se sale del
  matraz. Sin la máscara el addon sigue funcionando con el líquido encogido.
- Icono propio en la lista de addons.
- Tamaño por defecto 58x58. El dibujo está pensado para un marco cuadrado:
  para agrandarlo sin deformarlo, `/mb scale`.
- El `OnUpdate` sigue sin asignar memoria por frame —la fase verde incluida— y
  sigue desinstalado en reposo.

## 1.0.0

Primera versión.

- Barra que se llena durante los 5 segundos de la regla de regeneración de maná.
- Detección por `UNIT_SPELLCAST_SUCCEEDED` + `C_Spell.GetSpellPowerCost`, sin depender del combat log.
- Soporte de canalizaciones (inicio y fin del canal).
- Manejo de Secret Values: confirmación por bajada de maná cuando el costo no se puede leer.
- Deduplicación de casteos por `castGUID`.
- Respaldo opcional por `UNIT_POWER_UPDATE` (`/mb fallback on`).
- `/mb status` informa del contexto restringido vía `C_RestrictedActions`.
- Visible solo en clases y formas con maná.
- Barra arrastrable, con posición y opciones guardadas en SavedVariables.
- `OnUpdate` instalado solo mientras hay algo que animar: 0 bytes por frame en
  reposo, incluso con la barra visible.
- Contador sin asignaciones: las 51 cadenas de la ventana de 5 s se
  precalculan al cargar.
- Texto y chispa se actualizan solo cuando cambian.
- Ventana de confirmación simétrica: el orden en que llegan
  `UNIT_POWER_UPDATE` y `UNIT_SPELLCAST_SUCCEEDED` no afecta la detección.
- Los costes con `hasRequiredAura` no cuentan como coste seguro, así que un
  hechizo que un aura dejó gratis no arranca la regla.
- `/mb channel off` desactiva el reinicio al cortar una canalización.
- `/mb verify` mide contra el cliente si la regla de 5 s existe y cuánto dura,
  usando `GetPowerRegen()` como referencia.
- Un coste `nil` se interpreta como "sin coste de recursos" y no como
  "ilegible", así que un instantáneo gratis no reclama una bajada de maná ajena.
- `/mb status` informa de qué API de costes se encontró, para que la falta de
  las dos no degrade el addon en silencio.
- Comandos `/mb` (lock, unlock, test, scale, size, sound, text, always, fallback, reset, status).
