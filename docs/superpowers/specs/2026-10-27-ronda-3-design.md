# Caballo Blanco — Ronda 3: avisos, reto, descubrir y primer vídeo

Fecha: 2026-10-27. App nativa iOS 17 (`ios-prueba`), después del rediseño (rama `main`, `f597f7a`).

## Por qué

El usuario lleva **0 vídeos** del producto que está testeando. El último día que no grabó no fue por olvido: sabía que tenía que hacerlo, pero la pereza y la vergüenza de grabar un producto de calle en público pudieron más. En sus palabras, le faltó "escuchar o leer algo que me motivara, que me obligara a levantarme de la silla… fuera prejuicios y opiniones de la gente".

La auditoría (riesgo de Kelbert: abandonar la primera semana) dejó 4 puntos abiertos. Esta ronda los resuelve así:
1. **Recordatorio:** la app no avisaba nunca. Ahora avisa con un **empujón para actuar**, no con un recordatorio de la tarea.
2. **Testigo → reto personal:** el usuario no quiere testigo ("sin nadie mirando, yo contaré cuando quiera"). Será un reto propio con fecha.
3. **Novedad:** lo que le hace volver a un juego es "seguir explorando y aprendiendo, ver todo lo que podía hacer". Habrá cosas que descubrir, sin pantallas nuevas.
4. **Empezar:** mientras el producto tenga 0 vídeos, la app se centra en conseguir el primero. El usuario no ha fijado fecha y no hay que pedírsela.

## Éxito
- Publica su primer vídeo.
- Abre la app o actúa desde el aviso los días que no la habría abierto.
- Dentro de dos semanas la app todavía le enseña algo nuevo.

## Anti-objetivos (fracaso aunque funcione)
- Avisos que culpan o castigan. El tono es de empujón, nunca de reproche.
- Avisos que siguen llegando después de haber marcado la misión.
- Compartir, testigos o cualquier cosa que enseñe su progreso a otros.
- Pantallas o pestañas nuevas. Todo cabe en historias, hojas, Más y widgets.
- Tocar la **tarjeta de bloqueo** (Actividad en directo) o la **isla dinámica**: se quedan exactamente como están.
- Frases nuevas inventadas o cambiar el texto de `frases.js`.

## Restricciones
- Las mismas del rediseño: iOS 17, sin Mac (compila GitHub Actions), firma gratuita, sin servidor ni pagos. Ids de bundle, App Group y nombre "Caballo Blanco" sin cambios. Colores solo por rol de `Tema` (tokens en `design/tokens.json`; si hacen falta colores nuevos, se añaden ahí y pasan `design/contrast.py`). Fuente del sistema y etiquetas de VoiceOver en español.
- El estado sigue en el JSON `version: 1` con `normalizeState`: los campos nuevos tienen valor por defecto y los datos actuales del usuario se conservan.
- La lógica del juego va en `Resources/core.js` + `puente.js`, como hasta ahora. Swift solo pinta y programa avisos.

---

## 1. Avisos (notificaciones locales)

**Lo que decidió el usuario**
- Solo texto, sin audio.
- El aviso lleva una **frase para levantarse de la silla** (vergüenza, qué dirán, actuar sin ganas) y, debajo, la misión del día.
- Si lo quita sin querer, **vuelve cada 3 horas** mientras la misión siga sin hacer, cada vez con otra frase.
- Estilo de notificación del sistema con el icono de la app (maqueta aprobada `.superpowers/brainstorm/…/bloqueo-con-tu-diseno.html`).

**Cómo funciona**
- **Aviso de grabar:** a la hora que elige el usuario. Título "Caballo Blanco"; cuerpo: la frase en una línea y la misión pendiente principal en la siguiente.
  - Producto de calle: la misión baja el listón ("Solo 3 tomas de prueba, no se publican"), en línea con las rondas de ensayo de la investigación.
- **Repeticiones:** cada 3 h desde la hora de grabar mientras quede misión de vídeo sin hacer. **La última sale a las 22:00 como mucho** (mi decisión: el usuario no dio hora tope).
- **Racha en peligro:** a las 22:00, solo si hoy no ha hecho nada y la racha es mayor que 0. Propone "Lo mínimo" (la acción `minimo` que ya existe). Sustituye a la repetición de esa hora; nunca llegan dos a la vez.
- **Cuándo paran** (decidido por el usuario: "hay que subir 3 vídeos al día"): los avisos siguen mientras quede **cualquier misión de vídeo** del día sin hacer. Marcar 1 de 3 no los para; marcar el último vídeo, sí. Marcar misiones que no son de vídeo (métricas, comentarios, pedidos) no cambia nada. También se cancelan los que quedaban hoy al usar "Lo mínimo" o al saltar el día.
- **El texto de cada repetición** dice cuántos faltan, por ejemplo "Te quedan 2 vídeos hoy", y lleva la siguiente misión de vídeo pendiente.
- **Acción "Hecho"** en la notificación (mantener pulsado): marca la misión sin abrir la app.
- **Frases de los avisos:** se eligen de `frases.js` por su `categoria` ya existente: `verguenza` (37), `accion` (76), `imperfecto` (28). Sin repetir el mismo día y distinta de la frase del día.
- **Permiso:** iOS lo pide la primera vez que se abre la app tras actualizar. Si lo deniega, todo lo demás funciona igual y Ajustes muestra cómo activarlo.
- **Ajustes (Más):** interruptor "Avisos" y selector "Hora de grabar". **Por defecto 18:00** (mi decisión: las misiones de vídeo de un vídeo al día van en el bloque de tarde).

- **Acción "Hecho" de la notificación:** marca la misión que se ve en el aviso si sigue pendiente. Si ya no lo está, marca la siguiente misión de vídeo pendiente. *(mi decisión)*

**Para el constructor:** los avisos se programan por adelantado, así que hay que dejar programados también los de mañana, por si el usuario no abre la app.
- Los de mañana se calculan con el estado previsto y pueden ser aproximados (*mi decisión*). La cola se reprograma cada vez que cambia el estado: al abrir la app, tras cada acción y en cada recarga del widget (cada 30 min), que es lo que corrige el texto.
- El aviso de racha en peligro solo se programa para hoy, nunca para mañana.
- No se programa nada después de las 22:00. Si la hora de grabar es 22:00 o más tarde, solo sale ese aviso.

## 2. Reto personal (sin testigo)

**Lo que decidió el usuario**
- Reto: **facturar más de 10.000 € antes del 31 de diciembre de 2026** (Q4).
- Nadie lo ve y no hay botón de compartir.
- La facturación la **apunta él a mano**: el total que le marca la tienda, de vez en cuando.
- Los 10k son **la suma de todos los productos**. Es un solo número para todo el negocio, no uno por producto.

**Cómo funciona**
- **Historia "Reto"** en la fila de Hoy:
  - el anillo es lo facturado sobre la meta;
  - al abrirla: cantidad, días que quedan y, en pequeño, los vídeos publicados desde que empezó el reto (lo que sí controla);
  - botón "Apuntar facturación", donde escribe el **total** (no cada venta), así que corregir es volver a escribir.
- **Al llegar a la meta:** aviso de logro grande y medalla especial.
- **Al vencer la fecha sin llegar:** sin castigo. Se muestra un resumen de lo hecho y se propone un reto nuevo.
- **Un solo reto activo.** En Más se puede cambiar la meta y la fecha.
- **Arranque** *(mis decisiones)*:
  - Al actualizar la app, el reto se crea solo con 10.000 € y fecha 31-12-2026 (ese día incluido). Es lo que dijo el usuario.
  - Se guarda el día de inicio y la base de vídeos: la suma de `videos` de todos los productos en ese momento. "Vídeos del reto" es la suma actual menos esa base.
  - Se cumple al **alcanzar** la meta (≥ 10.000 €).
  - Editar la meta o la fecha mantiene el inicio y la base. Solo "Empezar reto nuevo" (tras vencer o desde Más) los reinicia.

## 3. Widgets de la pantalla de bloqueo: "Hoy + Reto"

**Lo que decidió el usuario** (maqueta aprobada `bloqueo-con-tu-diseno.html`, opción A "Hoy + Reto")
- Dos widgets rectangulares distintos que, puestos juntos, funcionan como uno.
- **Hoy** (el rectangular actual, sin cambios de contenido): caballo de Phosphor, "Nv 4 · 🔥12", la misión y ✅.
- **Reto** (widget nuevo, solo rectangular): "Reto Q4 · 65 días", barra de progreso, "1.240 € de 10k · 23 vídeos".
- **Sinergia:** al tocar ✅ en Hoy, el contador de vídeos del Reto sube. Los dos se recargan juntos.
- iOS los pinta en blanco translúcido; no llevan colores propios.

**Mis decisiones (a revisar):**
- El widget **en línea** se queda como está ("Nv · 🔥 · 🛡️"). La maqueta enseñaba una frase ahí, pero las frases más cortas del banco tienen 38 caracteres y la línea admite unos 25: no caben sin recortarlas.
- El **widget mediano** de inicio no cambia. El reto vive en la historia y en el widget de bloqueo.

## 4. Descubrir (novedad sin pantallas nuevas)

**Lo que aprobó el usuario**
- **Técnicas que se desbloquean:** cada nivel desbloquea una técnica de vídeo o de venta sacada de la investigación (`WHorse/docs/investigacion/`: Sielmann, Kelbert, Víctor Heras), reescrita y nunca copiada literalmente.
  - Aparece como historia nueva el día que se desbloquea.
  - Después, de vez en cuando, la misión de vídeo la incluye ("Prueba el gancho de pregunta en tu próximo vídeo").
  - Hacen falta unas 15, una por nivel hasta la Leyenda.
- **Encuentros raros:** más o menos una vez por semana, sin aviso previo, sale una misión especial con más XP (ej. "Graba 3 ganchos distintos del mismo producto"). Es determinista por día, igual que la frase del día.
- **Medallas ocultas:** no se ven hasta conseguirlas y no se sabe cuántas hay. Mínimo: primer vídeo, primer vídeo en la calle, primera semana sin saltar, reto cumplido.
- **Mis decisiones sobre cómo encaja:**
  - **Técnicas:** 15, una por nivel del 1 al 15. Al actualizar, se desbloquean sin ruido las de los niveles ya alcanzados, con una sola historia "Técnicas desbloqueadas: N". Después, una historia por cada subida de nivel.
  - **Medallas ocultas:** se guardan en un campo propio (no en `medals`, que son días de racha) y no se conceden con efecto retroactivo.
  - **Encuentros raros:** se **añaden** como una misión más del día, ligada al producto en test. Cuentan para la racha y el XP y, si son de vídeo, también para `videos`. No salen en días de "Tu primer vídeo" ni en días de "Lo mínimo". No cambian la regla de los avisos.
- **El caballo cambia al subir de rango** (Jinete novato → Jinete → Explorador → Forajido → Leyenda): cambia el halo o el color del círculo. El icono sigue siendo el de Phosphor.

## 5. "Tu primer vídeo"

**Propuesto al usuario, que no se opuso; él no fijó fecha.**
- Mientras el producto en test tenga 0 vídeos, la misión de vídeo de Hoy se sustituye por dos pasos:
  1. "Graba 3 tomas en casa o en el portal, sin publicarlas" (ensayo).
  2. "Publica una, aunque no te guste" (cuenta como vídeo).
- Al publicarlo se desbloquea la medalla oculta "Primer vídeo".
- Esos días, los avisos hablan de empezar aunque salga mal, no de vender.
- **Mis decisiones sobre cómo encaja:**
  - El modo se activa mientras el usuario **no haya publicado ningún vídeo nunca** (la suma de `videos` de todos los productos es 0) y haya un producto en test con misiones de vídeo ese día. Un segundo producto más adelante no lo reactiva.
  - Los dos pasos son del mismo día. El paso 2 aparece en cuanto se marca el 1. Sustituyen a las misiones de vídeo de ese día; las demás misiones no cambian.
  - El paso 1 cuenta para la racha y da el XP base. El paso 2 cuenta como vídeo normal.
  - Si el paso 2 no se publica, al día siguiente se vuelve a empezar desde el paso 1. El día de test sigue avanzando como siempre.

---

## Qué se queda igual
Misiones normales, racha, escudos, "Saltar hoy", productos, "He vendido", decisión del día 14, bajón, tarjeta de bloqueo, isla dinámica, widgets de inicio y en línea.

## Lo que decide el constructor
- Cómo se reparten los cambios entre `core.js`, `puente.js` y Swift, siempre que la lógica de juego quede en JS.
- La lista de técnicas y encuentros, a partir de la investigación.
- Los colores de los rangos, como tokens nuevos que pasen el contraste.
- Cómo se programa y reprograma la cola de avisos, dentro del límite de iOS de 64 pendientes.
- La versión de Scriptable (`WHorse/src/`) **ya no se usa** (confirmado por el usuario). No recibe estos cambios.
- La subida progresiva de la primera semana (1, 1, 2, 2, 2, 3, 3 vídeos y luego 3 al día) **se mantiene** (confirmado por el usuario).
