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
- Comandos `/mb` (lock, unlock, test, scale, size, sound, text, always, fallback, reset, status).
