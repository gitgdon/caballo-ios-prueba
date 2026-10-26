# Componentes de Caballo Blanco (replica-design)

Inspiración: sistema de Apple (tipografía del sistema, tarjetas, anillos de progreso, claro/oscuro) e historias de Instagram (fila de círculos arriba). Todo es propio:

- **Paleta:** colores propios, en `tokens.json`.
- **Caballo:** icono `horse` de **Phosphor Icons** (licencia MIT, se cita en Ajustes → Créditos).
- **Fuente:** la del sistema de iOS.
- **Textos:** escritos para esta app.

Nada de logos, colores ni iconos de Apple o Instagram.

Todos los colores se usan por rol (`Tema.texto`, `Tema.superficie`…), nunca como hex suelto. Los toques tienen una zona mínima de 44×44 pt y todo lleva su etiqueta de VoiceOver.

---

## Caballo
- **Forma:** icono Phosphor `horse` en variante *fill* sobre un círculo de fondo (`surface-2`).
- **Estados:**
  - **radiante:** icono `ring-xp` y halo suave del mismo color detrás;
  - **normal:** icono `text`;
  - **barro:** icono `text-muted` al 70 %, sin halo.
- **Tamaños:** 28 (widgets pequeños), 40 (filas), 64 (historia), 96 (cabecera).
- **A11y:** "Tu caballo: radiante" (o "normal", "con barro").

## Historia (círculo con anillo)
- **Partes:** círculo de 64 pt con el icono o número dentro, un anillo de progreso alrededor (4 pt de grosor, 3 pt de hueco) y la etiqueta debajo (`caption`, `text-muted`).
- **Variantes:**

  | Historia | Dentro | Anillo | Color |
  |---|---|---|---|
  | Frase | icono comillas | lleno | `ring-frase` |
  | Racha | número | progreso a la siguiente medalla | `ring-racha` |
  | Nivel | caballo | XP | `ring-xp` |
  | Producto | "2/30" | días del test /14 | `ring-producto` |
  | Medalla | solo si hay una nueva | — | — |

- **Estados:**
  - **nueva:** anillo con brillo, hasta que se ve;
  - **vista:** anillo apagado al 40 %;
  - **pulsada:** escala 0,94 con muelle.
- **A11y:** botón "Racha: 12 días, 5 para la siguiente medalla".

## Visor de historia (pantalla completa)
- **Fondo:** degradado de marca (crema → dorado → marrón) en claro; `bg` con halo dorado en oscuro.
- **Arriba:** barras de progreso, una por historia, como en las historias.
- **Contenido:** grande y centrado; la frase en `frase` (24/600).
- **Gestos:** tocar a la derecha pasa a la siguiente, a la izquierda vuelve, deslizar hacia abajo cierra. **Sin avance automático**, para no hacer perder el tiempo.
- **A11y:** botones "Siguiente", "Anterior" y "Cerrar".

## Misión principal (tarjeta grande)
- **Contenido:** `surface`, radio `lg`, sombra `card`. Etiqueta del bloque (`caption`, `text-muted`, mayúsculas), texto de la misión (`title`, 22/700, hasta 3 líneas) y línea del producto (`footnote`).
- **Botón ✅ Hecho:** a lo ancho, 52 pt de alto, `accent` con texto `on-accent`.
- **Estados:**
  - **normal**;
  - **completada:** check animado, se cambia a la siguiente misión;
  - **día cerrado:** texto "Día cerrado. Descansa, jinete.", sin botón;
  - **sin productos:** se muestra *Nuevo producto*.
- **A11y:** "Misión de la tarde: Graba 1 vídeo… Botón: marcar como hecha".

## Fila de misión
- **Contenido:** etiqueta del bloque arriba, texto `body` y, a la derecha, un círculo de check de 28 pt con borde `border-input` que se rellena de `success` al tocarlo.
- **Estados:** pendiente, hecha (tachada al 50 % y se va).

## Botón
- **Variantes:**
  - **principal:** `accent` / `on-accent`;
  - **secundario:** `surface-2` / `text`;
  - **fantasma:** solo texto `accent`;
  - **peligro:** `danger`.
- **Tamaños:** md 44 pt, lg 52 pt. Radio `md`.
- **Estados:** normal, pulsado (opacidad 0,8), desactivado (40 %) y cargando (mantiene el texto para VoiceOver).

## Tarjeta
- **Estilo:** `surface`, radio `lg`, margen interior 16, sombra `card`, borde `border` en oscuro.

## Lista "Más…"
- **Estilo:** lista agrupada al estilo de los Ajustes de iOS. Cada fila lleva un icono Phosphor de 20 pt en un cuadrado redondeado de color, el texto y una flecha.
- **Filas:** Un vídeo ha funcionado, Ha pasado de 10k, He vendido, Nuevo producto, Mi porqué, Ajustes.

## Saltar hoy
- **Forma:** botón fantasma discreto al final de la pantalla.
- **Confirmación:** hoja inferior con el aviso del escudo (`warning`), la frase de disciplina y tres botones: "Vale, voy a hacer algo" (principal), "😮‍💨 Mejor hago lo mínimo" (secundario) y "Saltar igualmente" (peligro).

## Decisión del día 14
- **Forma:** hoja a media pantalla, paso a paso, con una pregunta por paso y botones grandes.
- **Al descartar:** pantalla de checkpoint con la animación del caballo.

## Aviso de logros
- **Forma:** píldora que baja desde arriba, con icono, título y detalle. Dura 3 s y se puede tocar para cerrarla.
- **Variantes:** nivel, medalla, escudo, récord y ganador.

## Ajustes
- **Contenido:** interruptor "Tarjeta en la pantalla de bloqueo" (con su nota sobre la isla dinámica) y créditos (Phosphor Icons, MIT).

## Widgets
- **Mediano:**
  - arriba, la frase en `callout` itálica, hasta 2 líneas;
  - abajo, a la izquierda, el caballo de 40 con el nivel y una mini barra de XP;
  - abajo, a la derecha, la misión, con el ✅ como círculo de 36 pt.
  - Fondo `surface` del sistema (respeta claro/oscuro), con un toque de degradado de marca en la esquina.
- **Pequeño:** el caballo, "Nv 4 · 🔥12", la misión en 3 líneas y el ✅.
- **Bloqueo rectangular:** "🐴 Nv 4 · 🔥12", la misión y un ✅ circular.
- **Bloqueo circular:** el anillo de racha con el número dentro, con `Gauge` de iOS.
- **En línea:** "Nv 4 · 🔥12 · 🛡️2".

## Tarjeta de bloqueo (Actividad en directo)
- **Estilo:** fondo `bg` oscuro, translúcido.
- **Arriba:** el caballo de 44 con la línea de nivel y la frase en 3 líneas.
- **Abajo:** la misión `headline` con el ✅ (círculo de 44 pt, `accent`).
- **Isla dinámica:** sin contenido (el mínimo posible).
