# Caballo Blanco — Ronda 4: frases, avisos de frases, técnicas abiertas, deshacer y apariencia

Fecha: 2026-10-29. App nativa iOS 17 (`ios-prueba`, rama `main` en `555d707`, con la ronda 3 ya fusionada).

## Por qué

El usuario describe el momento que quiere cortar: "estoy en casa sin hacer nada, quemando dopamina y viendo contenido sobre ganar dinero, pero por mucho que vea el contenido si no empiezo no sirve de nada". Las frases tienen que interrumpir ese bucle y empujarle a actuar, y quiere tenerlas a mano "para no caer en la perezosería y el no continuar".

Las técnicas estaban bloqueadas por nivel porque había dicho que le engancha explorar. Aclaró que para él explorar es aprender trabajando: "ver cómo poco a poco sé más y voy generando dinero, además de encontrar mis técnicas". Esconderlas le corta el aprendizaje.

Detectó además que un producto creado sin querer no se puede borrar, y pidió: "contempla estas cosas en todo lo que hacemos en la app".

## Éxito
- En un momento de pereza abre la app y en un toque tiene una frase que le mueve.
- Durante el día le llegan frases sueltas a su ritmo, nunca de madrugada.
- Lee cualquier técnica cuando la necesita y va construyendo su propio libro de técnicas.
- Ningún error se queda para siempre: lo que se crea se puede borrar o editar, y lo que se marca se puede deshacer.

## Anti-objetivos
- Avisos de frases con la misión o el botón "Hecho": ya existen los avisos de misión. **Solo la frase.**
- Avisos de madrugada o fuera de la franja que elija.
- Frases de dinero o estatus en los avisos: alimentan el bucle de ver contenido.
- Borrar sin confirmación algo que no se puede recuperar.
- Pestañas nuevas: todo va en filas de Más, historias y hojas.
- Tocar la tarjeta de bloqueo o la isla dinámica.

## Restricciones
- Las de las rondas anteriores siguen vigentes:
  - iOS 17, sin Mac; compila GitHub Actions, que también pasa `node --test test/*.test.js`;
  - ids de bundle, App Group, nombre "Caballo Blanco" y texto de `frases.js` sin cambios;
  - colores por rol de `Tema`, con `design/contrast.py` en verde;
  - etiquetas de VoiceOver en español y zonas táctiles de 44×44;
  - estado `version: 1` con valores por defecto en `normalizeState`;
  - lógica de juego en JS y ninguna función actual se quita.
- Límite de iOS: 64 notificaciones pendientes en total. Los avisos de misión ocupan como mucho 17.

---

## 1. Apartado "Frases" (fila en Más)

**Lo que decidió el usuario:** quiere un apartado con todas las frases para "ver frases que me motiven y no caiga en la perezosería". Aprobó la propuesta siguiente.

- **Botón grande "Dame una frase"** arriba. Muestra una al azar de las categorías que empujan a actuar (`accion`, `disciplina`, `imperfecto`, `verguenza`), en grande. Si no le convence, toca otra vez y sale otra, sin repetir las últimas que ha visto en esa sesión.
- **Debajo, las 477 frases** agrupadas por categoría, con buscador por texto o autor. Al tocar una se ve el texto, el detalle, el autor y el vídeo de origen (título).
- **Favoritas:** una estrella en cada frase. Las favoritas salen primero, en su propia sección. Se guardan en el estado del juego, así que sobreviven a reinstalar mientras se conserven los datos del App Group.

## 2. Avisos con frases

**Lo que decidió el usuario:** "Solo la frase, ya que ya tengo un recordatorio de misiones". La frecuencia la elige él, y nunca de madrugada.

- **Contenido:**
  - título "Caballo Blanco" y cuerpo con la frase y su autor;
  - sin acción "Hecho": van en una categoría de notificación propia, sin acciones;
  - al tocar el aviso se abre la app en el apartado Frases, con esa frase destacada. *(mi decisión)*
- **De dónde salen:** de `accion`, `disciplina`, `imperfecto` y `verguenza`, sin repetir en el mismo día y distintas de la frase del día.
  - Opción "Solo mis favoritas": si está activa y hay al menos 3 favoritas, salen solo de ellas. Si hay menos de 3, se usan las categorías.
- **Configuración** (Más → Ajustes → "Frases durante el día"):
  - interruptor;
  - "Cada" N horas (1 a 6);
  - "Desde" y "Hasta" (horas).
  - **Por defecto:** activado, cada 3 h, de 10:00 a 22:00. *(mi decisión)*
  - Validación: "Desde" anterior a "Hasta"; si no lo es, se usan los valores por defecto.
- **Programación:**
  - como los avisos de misión, se calcula un plan para hoy y mañana y se reprograma tras cada cambio de estado;
  - ids estables `frase-YYYY-MM-DDTHH:MM`;
  - si a la misma hora y minuto hay un aviso de misión, el de la frase se salta. *(mi decisión)*
  - Con cada 1 h y de 0:00 a 23:00 serían 48. El plan se limita para que el total con los de misión no pase de 60. *(mi decisión)*
- **Independiente de los avisos de misión:** cada uno tiene su interruptor y su configuración.

## 3. Técnicas abiertas y "Mis técnicas"

**Lo que decidió el usuario:** quiere aprender, así que las técnicas deben estar a mano. Aprobó la propuesta siguiente.

- **Las 15 técnicas se pueden leer desde el primer día** en Más → Técnicas, ordenadas por nivel y sin 🔒. Cada una lleva una etiqueta "Nivel N", y la del nivel actual se marca como "Practicando ahora".
- **El nivel solo decide qué se practica.** Las misiones de vídeo siguen llevando el sufijo de técnicas hasta el nivel actual, como ahora, y al subir de nivel sigue apareciendo la historia "Técnica nueva". No cambia nada más de la ronda 3.
- **"Mis técnicas"**, una sección en la misma pantalla:
  - incluye los ganchos del banco, con las visitas que consiguió cada uno;
  - incluye técnicas propias que el usuario escribe a mano: texto corto (≤ 140 caracteres) y producto opcional;
  - todo se puede editar y borrar, con confirmación al borrar;
  - "Mis ganchos" deja de ser una fila aparte de Más y pasa a estar aquí. *(mi decisión)*

## 4. Deshacer y borrar en toda la app

**Lo que decidió el usuario:** "si creamos un producto sin querer no podemos eliminarlo, contempla estas cosas en todo lo que hacemos en la app". Aprobó la propuesta siguiente.

**Regla para todo, a partir de ahora:** todo lo que se crea se puede editar o borrar, y toda acción que cambia el juego se puede deshacer.

- **Deshacer la última acción:**
  - Tras cualquier acción hecha desde la app, abajo aparece durante 6 s una píldora con el texto "<qué se hizo> · Deshacer". Ejemplos: "Misión hecha · Deshacer", "Producto creado · Deshacer", "Facturación apuntada · Deshacer".
  - Al tocar "Deshacer", el juego vuelve exactamente al estado anterior: XP, racha, escudos, medallas, secretas, reto, calendario, productos. Después se recargan los widgets, la tarjeta y los avisos.
  - **Mecanismo:** antes de cada acción se guarda la copia del estado anterior, y solo se guarda una, la de la última acción. *(mi decisión)*
  - Si entretanto cambió el estado desde fuera de la app (widget o notificación), "Deshacer" ya no se ofrece, para no pisar ese cambio. *(mi decisión)*
  - Las acciones hechas desde el widget o la notificación no ofrecen deshacer. En la app se pueden corregir con las opciones de editar y borrar. *(mi decisión)*
- **Productos:**
  - **renombrar;**
  - **borrar**, con una confirmación que dice qué se pierde, por ejemplo "Se borrará «Lámpara» con sus 3 vídeos y 1 ganador. No se puede recuperar". Se puede deshacer durante los 6 s de la píldora.
  - Si el producto borrado es el último creado, deja de contar para el "Producto N/30". *(mi decisión)*
  - El XP ya ganado se mantiene. *(mi decisión)*
- **Gastos:** además de borrar, que ya existe, se pueden editar importe y concepto.
- **Ganchos y técnicas propias:** editar y borrar.
- **Facturación:** se corrige escribiendo otro total, como ya funciona.

## 5. Apariencia (modo claro y oscuro)

**Lo que decidió el usuario:** poder elegir el tema desde la app.

- En Más → Ajustes, "Apariencia" con tres valores:
  - **Automático:** sigue al iPhone, como ahora, y es el valor por defecto;
  - **Claro;**
  - **Oscuro.**
- Se aplica al momento a toda la app, hojas y visor de historias incluidos.
- Es una preferencia de la app, no del juego, así que no va en el estado JSON.
- **Limitación de iOS:** los widgets y la tarjeta de bloqueo siguen el modo del iPhone. La app no puede cambiarlos; se avisa con una nota bajo el selector.

---

## Qué se queda igual
- Las misiones y los avisos de misión, la racha, los escudos, el reto, el calendario y "Tu primer vídeo".
- Los encuentros, las medallas, los widgets, la tarjeta de bloqueo y la isla dinámica.
- La lógica de técnicas en las misiones y la historia "Técnica nueva".

## Lo que decide el constructor
- Cómo se reparte la lógica entre `core.js`, `puente.js` y Swift. La aleatoriedad de "Dame una frase" puede vivir en Swift o en JS.
- Cómo se dibuja la lista de 477 frases para que el desplazamiento vaya fluido.
- Dónde se guarda la copia para deshacer: en el estado o aparte en `UserDefaults` del App Group.
- El nombre de las nuevas acciones y campos del puente.
