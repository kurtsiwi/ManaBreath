# Changelog

## 1.2.0

- **Una gota de agua al cumplirse la regla**, que es el instante en que el mana
  vuelve a subir. Sustituye al `SOUNDKIT.READY_CHECK` de la 1.0, que era un
  sonido prestado de la interfaz sin nada que ver con el mana. Suena en las dos
  pieles y sigue mandado por `/mb sound on/off`: un interruptor, un sonido.
- El audio va en `Sound/ManaDrop.ogg`: 8,5 KB, mono, 44,1 kHz, 0,60 s. OGG y no
  MP3 porque los dos cargan, pero el soporte de MP3 se rompio una vez y, cuando
  falla, no da error: simplemente no suena. Del original se recorto la cola
  muda (de 1,03 s a 0,60 s, con desvanecido para no dejar un chasquido) y se
  normalizo el pico a -1,3 dBFS.
- Si el archivo faltara, `PlaySoundFile` lo dice y el addon lo imprime con
  `/mb debug on`, una vez por sesion. Un mando que no hace nada sin explicar
  por que es peor que uno que no esta.
- **Modo texto.** `/mb style text` cambia el matraz por una lectura sobria,
  solo de letras: la cifra y debajo una etiqueta pequena espaciada (`5 S R`
  durante la regla, `M A N A` mientras regeneras). `/mb style flask` vuelve al
  matraz. Tambien esta en el panel, lo primero de Aspecto.
- Es una **piel, no un segundo display**: las dos corren el mismo motor, con
  los mismos estados, los mismos tiempos y la misma deteccion. Lo unico que
  cambia es que se dibuja, asi que un arreglo en la regla vale para las dos.
  El destello de cada tick de mana existe en las dos: en el matraz lo lleva el
  liquido, en modo texto la cifra.
- En modo texto no hay halo ni burbujas: el halo es la silueta del matraz y las
  burbujas suben por dentro del cristal, asi que sin matraz no rodean ni suben
  por nada. `/mb text off` tampoco hace nada, porque la cifra es lo unico que
  hay en pantalla. El comando lo dice al cambiar de piel, en vez de dejar tres
  mandos que parecen rotos.
- Apagar esas tres cosas es ademas lo que deja al modo texto **sin nada que
  animar**: baja de ~5 llamadas al API por frame a ~1. `tests/profile.lua` mide
  las dos pieles, asi que si algo del matraz se colara en modo texto, se veria.
- El marco se dimensiona a la cadena mas ancha que puede llegar a mostrar,
  medida una sola vez al colocar: asi el bloque no cambia de tamano al pasar de
  `4.3` a `regen` y el area de arrastre abraza lo que se ve. `/mb size` sigue
  poniendo el alto, que es lo que manda sobre el cuerpo de letra; el ancho lo
  pone el texto.
- La cifra del matraz lleva `OUTLINE` porque va sobre el cristal y el liquido.
  La del modo texto va sobre el fondo del juego, donde el borde se lee como un
  contorno grueso: ahi lleva una sombra corta.
- Las pruebas cubren la piel nueva entera, incluido que volver al matraz lo
  devuelva completo y no a medias.
- Nueva comprobacion de que los `.toc` no se desincronizan: solo pueden
  diferenciarse en la linea `## Interface`, y su lista de archivos Lua tiene
  que ser la que las pruebas cargan. Cuatro archivos casi identicos no se
  revisan a ojo.
- **Fuera el `.toc` con sufijo de sabor** (`ManaBreath_Camelot.toc`). El
  sufijo de Forever nunca se confirmo, y daba igual: el generico ya lleva la
  interfaz `16001` y es el que carga cuando ningun sufijo coincide, asi que la
  copia con sufijo solo podia acertar lo que el generico ya hacia. Se publica
  un unico `ManaBreath.toc`.
- Copias de prueba `ManaBreath_Mainline.toc` (Retail, `120001`) y
  `ManaBreath_Vanilla.toc` (Classic Era, `11507`) para poder probar carga,
  dibujo y comandos en clientes vivos antes de que Forever lance. Quedan fuera
  del paquete publicado: anunciarian una compatibilidad sin verificar.
- La huella estatica sube a ~106 KB mas ~12 KB del panel. Los ~12 KB de la
  piel de texto se pagan se use o no, porque las dos se construyen al cargar y
  cambiar de piel no deberia montar widgets a mitad de una regla.

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
- Las olas, las burbujas y el latido del halo pasan a 30 Hz (`ANIM_STEP`). A
  58 px nada avanza más de medio píxel por paso, así que 60 Hz eran el doble de
  llamadas al API para el mismo dibujo: de ~16 a ~5 llamadas por frame. El
  nivel del líquido y el contador siguen yendo por frame.
- `Show()` y `SetAlpha()` de las burbujas solo se llaman cuando cambian de
  verdad. Antes se llamaban las dos en cada frame y cada burbuja pasa el 70 %
  de su vida a opacidad constante.
- El banco de memoria mide con el recolector parado. Corriendo, lo que medía no
  era lo que el addon asigna sino lo que el recolector no alcanzó a liberar, y
  eso depende del tamaño del montón: de ahí salían los "3–12 bytes por casteo"
  de la 1.0, cuando la cifra real es ~320, toda ella la tabla que devuelve
  `C_Spell.GetSpellPowerCost`. Los frames, en cambio, son cero de verdad.
- Nuevo `tests/profile.lua`: cuenta llamadas al API por frame en cada fase.
- **Panel de opciones** en Opciones → AddOns, con `/mb config` y botón en el
  compartimento de addons. Lo dibuja el juego a partir de las opciones que el
  addon declara, y el valor vive en `ManaBreathDB`, así que el panel y los
  comandos no pueden desincronizarse. Si este cliente no expusiera el API de
  ajustes, no se registra panel y todo sigue por `/mb`.
- El modo de brillo se aplica en caliente (`RefreshGlow`): antes, cambiarlo a
  mitad de un ciclo no se notaba hasta el siguiente.
- `debug` pasa a estar declarado en los valores por defecto. El panel necesita
  un valor por defecto del tipo correcto para cada opción que muestra.

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
