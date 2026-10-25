# Changelog

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
