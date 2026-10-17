# Historia: detalle diario y calendario inspirados en Fitness

Plan de implementación, 17 de octubre de 2026. Esta entrega solo investiga y planifica; no modifica la app. [Evidencia y límites de la investigación](evidence.md).

## Resultado que buscamos

Entrar en Historia debe permitir recorrer días como en el detalle de actividad de Fitness: seleccionar un día en la franja semanal, ver su reloj grande, bajar por sus gráficos y abrir un calendario mensual con miniaturas. El conjunto mantiene la personalidad aprobada de Nido: fondo suave, verde bosque, tipografía de sistema y rosa para sueño, lima para tomas y turquesa para pañales. El resumen conserva iconos de esos colores y texto neutro.

Se traslada el comportamiento de exploración de Fitness. La representación sigue significando lo mismo que en Nido: **el sueño ocupa tiempo; tomas y pañales ocurren en instantes**. Las miniaturas serán versiones del reloj temporal aprobado, no tres anillos que se llenan según cifras arbitrarias.

### Composición del detalle

1. Cabecera compacta con fecha y acceso al calendario. En la raíz de la pestaña no se dibuja una flecha de volver sin destino.
2. Franja de siete días con mini-relojes. Permanece visible al desplazar el detalle; la superficie garantiza lectura sobre los gráficos.
3. Reloj grande del día seleccionado y resumen exterior, reutilizando el lenguaje aprobado de Hoy.
4. Secciones Sueño, Tomas y Pañales: título, total y gráfico horario con el color correspondiente, sin tarjetas decorativas para cada bloque.
5. Registros del día, con filtros y edición/borrado existentes. Los cuidados siguen siendo consultables, sin inventar una cuarta puntuación de salud.

El calendario es una hoja modal con cierre visible y meses consecutivos en desplazamiento vertical. Sus días muestran mini-relojes, fecha y selección. No se convierte cada día en una tarjeta.

## Contratos de interacción

| Acción | Resultado propuesto en Nido |
|---|---|
| Abrir Historia por primera vez | Mostrar hoy y su semana. Al volver desde otra pestaña, conservar el día y el contexto mientras exista la misma sesión y bebé. |
| Abrir Historia desde «Ver todo» de un día de Hoy | Abrir ese día, incluso si no es hoy. Usar el mismo estado de selección que la pestaña. |
| Tocar un mini-reloj semanal | Actualizar fecha, reloj, resumen, gráficos y registros conjuntamente. No mezclar fecha nueva con contenido anterior. |
| Recorrer semanas | Mostrar semanas reales según el calendario del sistema, en lugar de siete días que terminan siempre en la selección. Los días futuros se ven como tales y no se seleccionan. |
| Deslizar el detalle horizontalmente | Día anterior/siguiente, sin pasar de hoy. Es un contrato propuesto, apoyado por la estructura paginada encontrada en Fitness; la prioridad exacta de sus gestos no se ha observado. |
| Explorar un gráfico | Mostrar intervalo, valor y registros relacionados sin cambiar de día. Dentro del área interactiva del gráfico, ese gesto tiene prioridad sobre paginar días. Hay alternativa de toque y VoiceOver. |
| Bajar por el detalle | El reloj grande sale de pantalla; fecha y franja semanal permanecen disponibles. |
| Cambiar de día estando en una sección inferior | Conservar la sección semántica visible —por ejemplo Pañales—, no un desplazamiento en píxeles que podría caer en otra sección. |
| Tocar un total del resumen | Desplazar a su sección. El área completa del total es el control, sin exigir acertar en un icono pequeño. |
| Abrir el calendario | Centrar el mes de la selección actual. Meses anteriores/siguientes se recorren verticalmente, con encabezado que sigue el mes visible. |
| Elegir un día en el calendario | Seleccionar el día, cerrar la hoja y sincronizar franja, reloj y contenido. |
| Cerrar sin elegir | Conservar fecha y posición anteriores. |
| Tocar «Hoy» | Regresar a hoy y su semana. |
| Editar o borrar | Mantener los flujos actuales y recalcular todos los resúmenes afectados; conservar la posición de lectura. |

La paginación tendrá botones accesibles de día anterior/siguiente. Si el prototipo revela conflicto con la exploración del gráfico o con volver, se limitará la zona de paginación; no se resolverá haciendo fallar silenciosamente uno de los gestos. La franja podrá recorrer semanas sin cambiar el día seleccionado hasta que se toque otro día.

## Un significado común para todos los tamaños

El reloj grande, las siete miniaturas y el calendario mensual derivan de la misma distribución temporal. Sueño rosa se dibuja como intervalos; tomas lima y pañales turquesa como marcas en su hora. También se conservan los eventos púrpura de cuidados presentes en el reloj de Hoy y sus grupos mixtos; simplificarlos en miniaturas no debe eliminarlos del dato temporal. Su contador o metadatos acompañan la sección de registros como en Hoy, sin añadir una cuarta puntuación o anillo de cumplimiento. En miniaturas se simplifica el dibujo: no hay números, símbolos microscópicos ni objetivos táctiles por registro. Todo el día es un único botón con área suficiente y una descripción accesible con fecha y totales.

Los días sin registros muestran una base discreta y se anuncian como «Sin registros», no como ausencia de cuidados. No se rellenan anillos con `sueño / 720`, `tomas / 10` o `pañales / 8`. Se retirará esa escala actual junto a su texto explicativo; el reloj ya expresa un dato real sin necesitar esa justificación.

El detalle del reloj permite tocar un registro o desplegar un grupo, reutilizando la selección y edición de Hoy. El calendario no intenta reproducir ese detalle dentro de una miniatura.

## Datos y gráficos

### Una única fotografía coherente del día

Crear un modelo de presentación del día —por ejemplo `HistoryDaySnapshot`— que reúna el resultado temporal, totales, muestras de gráficos y referencias a registros originales. Reloj, resumen, gráficas y lista consumen esa misma fotografía. Su identidad incluye bebé, día, zona horaria y revisión de los registros, para evitar mezclar datos al sincronizar o cambiar de bebé.

Reutilizar `CircularTimeline.day` y los modelos existentes. Hay que resolver expresamente dos diferencias actuales:

- En los sueños finalizados, `Entry.date` representa el final y `durationMinutes` determina el inicio. La lista actual de Historia filtra por fecha del registro y puede omitir un sueño que sí contribuye al día anterior. La lista nueva debe derivar de los elementos temporales del día y sus identificadores originales. Editar abre el registro completo, no una copia del fragmento diario.
- Incluir las sesiones abiertas hasta el instante actual. Si cruzan medianoche, repartir su parte transcurrida por límites de día sin crear registros persistidos artificiales ni incluir minutos futuros. Añadir el contrato probado compartido que necesite el cálculo temporal actual; no introducir reglas distintas para Hoy e Historia.

### Representación por categoría

| Categoría | Gráfico propuesto | Magnitud y detalle |
|---|---|---|
| Sueño | Barras finas con remates redondeados, rosa; intervalos de 15 minutos | Segundos/minutos de sueño registrados dentro de cada intervalo, repartiendo correctamente los tramos que cruzan sus límites. Total en h/min. |
| Tomas | Barras lima por intervalo de 15 minutos | Número de tomas. Los ml, si existen, se muestran como información adicional diferenciada; no se suman duración, volumen y número en una misma serie. |
| Pañales | Barras o marcas turquesa por intervalo de 15 minutos | Número de cambios registrados. Tipo y observaciones se consultan en el detalle del intervalo. No copiar las 24 cápsulas de «De pie»: significarían otra cosa. |
| Cuidados | Lista cronológica filtrable | Mantener síntomas, notas y mediciones originales. No convertir magnitudes incompatibles en una puntuación ni rellenar un anillo. |

Todos usan el mismo día y referencias horarias comparables: 00, 06, 12 y 18 cuando proceda. La escala vertical parte de cero y se expresa con unidades claras. No se normalizan días diferentes contra su propio máximo para aparentar equivalencia. No hay divisores verticales entre totales; las guías horizontales del gráfico, si son necesarias, son discretas como en la referencia.

Las barras agrupan datos para leerlos; no cambian los registros ni sus totales. Los solapamientos existentes no se corrigen o descartan silenciosamente: se preserva la política común del cálculo temporal y se señalan en el detalle si afectan a la interpretación. La suma de las muestras debe reconciliarse con el total de su misma fuente, antes de redondeos de presentación.

### Fechas y zona horaria

Usar límites calculados con `Calendar`, no sumas constantes de 86.400 segundos. Los intervalos son `[inicio del día, inicio del siguiente)`: un evento exactamente a medianoche pertenece una sola vez. Se conserva inicialmente la política actual de calendario y zona local del dispositivo, inyectable en pruebas.

Los días con cambio horario pueden tener 23 o 25 horas reales. El reloj sigue siendo una lectura de hora civil; las gráficas y duraciones conservan el tiempo real. Las horas repetidas se distinguen en la exploración accesible o el detalle mediante su zona/desfase. Estos casos requieren pruebas antes de conectar los gráficos a la vista.

## Reutilización y cambios de código

| Parte actual | Trabajo previsto |
|---|---|
| `Features/History/HistoryView.swift` | Convertirla en composición del detalle diario; retirar el resumen de tres anillos y el selector de fecha como tarjeta grande. Preservar filtros, editor, borrado y estados vacíos. |
| `Core/HistoryPresentation.swift` | Semanas de calendario, selección y modelo común del día; sustituir las fracciones arbitrarias. Corregir la pertenencia diaria de sueños que cruzan medianoche. |
| `Features/Today/CircularTimelineView.swift` | Reutilizar o extraer la presentación compartida del reloj y resumen. Su resultado visual aprobado en Hoy debe mantenerse. |
| Componentes nuevos de Historia | `HistoryWeekStrip`, `HistoryDayDetail`, `HistoryDayCharts`, `HistoryMonthCalendar` y mini-reloj simplificado, en archivos separados. Nombres orientativos, no una dependencia nueva. |
| Modelo de analítica nuevo en `Core` | Generación de muestras y descripciones accesibles fuera de las vistas, comprobable con Swift Testing. |
| `RootView.swift` y selección de pestaña | Pasar una fecha al abrir Historia desde Hoy sin duplicar rutas o estados de selección. |
| `NidoStore` y `NidoAPI` | Conservar carga, caché, mutaciones pendientes y edición. Inicialmente sin cambio de contrato HTTP. |

Actualmente la API recorre todas las páginas por cursor antes de completar la carga; Historia consume `store.entries`. La primera implementación aprovecha ese contrato, pero debe distinguir caché/sincronización de un día confirmado vacío. Indexar o agrupar los registros una vez por revisión, evitando recorrer todo el historial para cada celda del calendario. Dibujar meses perezosamente y mantener solo días vecinos preparados para paginar. Si las mediciones con historiales largos muestran que hace falta carga por rango, tratarla como una ampliación de API separada, empezando por prueba del contrato HTTP.

El mínimo actual es iOS 17. Las APIs posteriores necesitan alternativa o disponibilidad explícita; no se sube el despliegue para conseguir un efecto visual. No se reutilizan frameworks privados de Fitness.

## Fases y criterio de salida

1. **Modelo temporal y pruebas.** Tests en rojo de semanas, pertenencia diaria, muestras, sesiones abiertas y selección. Implementación mínima en verde. Mantener coherencia con Hoy y conciliación de totales.
2. **Primera pantalla nativa.** Un día con cabecera, franja semanal, reloj rosa aprobado, resumen y una sección real de gráfico. Antes de implementar su comportamiento, prueba UI en rojo de fecha, contenido accesible y coherencia de totales; después implementación y verde. Los ajustes exclusivamente visuales usan comparación de renders definida antes de editar, sin presentarla como TDD unitario. Datos de ejemplo deterministas. Mostrar claro y oscuro tras revisión crítica propia. Esta es la primera entrega visual; no extender el rediseño a todas las pantallas antes de verla.
3. **Navegación diaria y franja fija.** Pruebas UI en rojo de selección conjunta, día anterior/siguiente, paginación y conservación de sección. Implementación y prueba en verde de convivencia con scroll/gráficos.
4. **Calendario mensual.** Meses consecutivos, selección centrada, mini-relojes, cierre y «Hoy». Pruebas de límites de mes/año, futuro, vacío y retorno sin perder contexto.
5. **Tres categorías y registros.** Completar gráficos con datos reales, exploración accesible y lista derivada del mismo día. Preservar editar/borrar/filtros, offline y sincronización.
6. **Revisión final.** Claro, oscuro, contraste aumentado, texto normal y accesibilidad, Reduce Motion, VoiceOver, contenido largo e historiales extensos. Suite core completa, suite UI/snapshots completa, compilación y escenarios reales. Comparar también Hoy para garantizar que no ha cambiado visualmente.

Compartir aparece en la referencia, pero no es necesario para demostrar el recorrido de Historia. Se plantea como entrega posterior con hoja nativa y previsualización explícita del contenido a compartir, reutilizando los mecanismos existentes cuando encajen. No se activa ningún envío automáticamente.

## Pruebas y entrega exigida

Por cambio de comportamiento: rojo verificable antes de producción, verde enfocado, suite completa y escenario UI correspondiente. Casos mínimos: evento exactamente a medianoche; sueño de 23:30 a 02:15; edición que mueve un intervalo a otro día; sesión abierta al cambiar de día; solapamientos y eventos simultáneos; semana entre meses/años; cambio horario de marzo y octubre en Europe/Madrid; cambio de zona y bebé; día vacío frente a carga/error; persistencia de selección y scroll al cambiar pestaña; lista, reloj y gráficos con el mismo total; selección con VoiceOver y sin gestos.

La entrega de cada fase incluye capturas nativas inspeccionadas, resultados, omisiones, límites conocidos y unidad de rollback. Los retoques exclusivamente gráficos usan comparación visual y snapshots como sustituto declarado del TDD unitario. Cada unidad futura de comportamiento debe ser reversible con sus pruebas; los cambios previos del árbol se preservan.

La aprobación final exige que la fecha y el contenido nunca se contradigan, que el calendario y la semana seleccionen el mismo día, que las miniaturas no parezcan objetivos, que no se pierdan registros nocturnos, y que los gráficos aporten lectura horaria sin sacrificar la calma y personalidad aprobadas de Nido. El plan no acredita todavía ninguna de esas implementaciones.
