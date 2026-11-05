# Copias de `.toc` para clientes vivos

`ManaBreath.toc`, el de la raíz, lleva la interfaz de Forever (`16001`) y es el
único que se publica. Los dos de aquí llevan **otra interfaz**, que es lo que
hace que Retail y Classic Era no vean el addon como desactualizado:

| Archivo | Interfaz | Cliente |
| --- | --- | --- |
| `ManaBreath_Mainline.toc` | `120001` | Retail de Midnight |
| `ManaBreath_Vanilla.toc` | `11507` | Classic Era |

Siguen haciendo falta. En Retail el maná también es secreto, así que es donde
se prueba ese camino sin esperar a Forever; y Classic Era es el único cliente
vivo con la regla real de vanilla, lo único que todavía podría confirmar que
dura 5,0 s y cómo cobran el maná las canalizaciones.

## Por qué no están en la raíz

CurseForge deduce las versiones de juego **escaneando el repositorio**, no el
zip que acaba de armar. Con los dos en la raíz, el `ignore` del `.pkgmeta` los
dejaba fuera del paquete —correcto— pero el archivo publicado salía igual
etiquetado para `12.0.1` y `1.15.7`, anunciando una compatibilidad que nadie
verificó. Fuera de la raíz, CurseForge no los ve y etiqueta solo `1.60.1`.

## Cómo usarlos

WoW solo lee los `.toc` que están en la raíz de la carpeta del addon, así que
hay que copiar el que toque:

```sh
cp tests/clients/ManaBreath_Mainline.toc .    # para probar en Retail
cp tests/clients/ManaBreath_Vanilla.toc .     # para probar en Classic Era
```

El cliente elige solo: con el sufijo presente carga ése, y si no hay ninguno
que coincida cae en `ManaBreath.toc`. Confirmá en qué cliente estás con
`/dump select(4, GetBuildInfo())`.

**Borralos de la raíz al terminar.** Si uno se escapa en un commit, vuelve el
problema de las versiones de juego. La suite no lo detecta: `tests/run.lua`
comprueba que los tres `.toc` no se desincronicen, pero los lee desde aquí.

## Al tocar cualquier `.toc`

Los tres tienen que cambiar juntos: un archivo Lua nuevo, una versión, una
directiva. `tests/run.lua` falla si divergen en algo que no sea la línea de
interfaz, que es justamente lo que los distingue.
