# Evolución — contrato del detalle de Sueño

El usuario aprobó visualmente el resumen nativo y autorizó continuar el 20 de octubre de 2026. Este siguiente punto de revisión desarrolla el hito 3 del plan: una interacción vertical de Sueño, antes de extender su patrón a las demás métricas y a la personalización de los datos fijados. Se conserva la pantalla aprobada y el funcionamiento habitual de Ritmos.

## Alcance de esta revisión

- Escenario DEBUG interactivo `evolution-design-sleep`; su equivalente vacío es `evolution-design-sleep-empty`.
- Tarjeta de Sueño → detalle nativo → selección de periodo y gráfica → registros de ejemplo → vuelta al mismo detalle.
- Los escenarios anteriores `evolution-design-summary` y `evolution-design-empty` conservan su contrato de revisión sin acciones.
- Los registros de ejemplo son de solo lectura y nunca se envían al editor, al borrado ni a la API del store real.
- No se modifica el backend ni se instala esta revisión en los iPhone.

## Calendario y cifras

Se inyectan calendario de la familia, fecha de referencia y registros. Los intervalos son semiabiertos `[inicio, fin)`. Se utilizan días, semanas, meses, semestres enero–junio/julio–diciembre y años naturales. No se cambia `GrowthRange`, cuyos intervalos existentes tienen otra semántica.

| Periodo | Barras | Cifra principal |
| --- | --- | --- |
| D | Horas naturales del día; 23 o 25 al cambiar la hora | Total registrado; hoy, hasta ahora |
| S | Días de la semana | Promedio por día completo con registros |
| M | Días del mes | Promedio por día completo con registros |
| 6M | Meses del semestre | Promedio por día completo con registros |
| A | Meses del año | Promedio por día completo con registros |

Las barras mensuales representan promedios diarios registrados de cada mes; no totales mensuales. El promedio de todo el intervalo se calcula a partir de las sumas y los días registrados, nunca como promedio de promedios mensuales. La etiqueta explica esa unidad al seleccionar una barra.

Los días sin registros quedan ausentes (`nil`). «Día completo» significa un día natural terminado; no acredita que se hayan registrado todos los cuidados. La cobertura presenta explícitamente el denominador de días terminados y los que contienen registros. Hoy y el futuro se excluyen de los promedios de varios días.

Se aceptan sueños terminados con duración positiva y fecha de fin no posterior a ahora. El fin del registro es `Entry.date`; el inicio se obtiene restando su duración. Se deduplican identificadores y se unen intervalos solapados antes de contar segundos. Un sueño que cruza medianoche contribuye a cada día con su parte correspondiente; uno que termina exactamente a medianoche no contribuye al día siguiente.

El sueño activo contribuye únicamente al detalle D de hoy, recortado hasta ahora. Se identifica visualmente y no se convierte en una entrada editable. Nunca entra en los promedios de días terminados.

La serie conserva todas las posiciones del intervalo natural, incluidas las fechas todavía no terminadas, que permanecen sin valor. La pertenencia al promedio y la pertenencia a «Todos los registros» son distintas: `recordIDs` describe los registros del agregado; `periodRecordIDs` incluye todos los sueños guardados válidos que intersectan el periodo, también los terminados hoy. Excluir hoy del promedio no debe ocultar esos registros en la lista.

## Interacción y accesibilidad

El selector D/S/M/6M/A actualiza cifra, intervalo, cobertura y gráfica conjuntamente. Los controles anterior/siguiente usan componentes de calendario; no se puede avanzar más allá del intervalo actual. Volver al actual conserva el periodo elegido. Un cambio de periodo o intervalo elimina la selección anterior.

La selección de una barra muestra su intervalo y cifra. Una acción explícita permite volver al resumen del periodo. La interacción de la gráfica dispone de una alternativa accesible; la información esencial no depende de arrastrar con precisión.

La lista de todos los registros mantiene su alcance de periodo aunque exista una selección en la gráfica. La fecha de la selección se muestra expresamente junto a la cifra. Todas las etiquetas de fechas y horas usan el mismo calendario y zona horaria que el cálculo. Las marcas del eje vertical representan sus valores reales, sin truncar intervalos de segundos a horas enteras.

Las superficies mantienen el degradado y la tipografía del resumen aprobado. Se comprueban claro, oscuro, estado vacío, texto de accesibilidad máximo y Reducir movimiento. Los valores deben quedar íntegros dentro del área útil tras desplazarse, por encima de la barra flotante y por debajo de la navegación nativa.

## Validación y reversión

Todo comportamiento seguirá prueba roja → implementación → prueba verde enfocada → suite completa correspondiente. El modelo puro cubre límites de calendario, cambios de hora, medianoche, solapamientos, duplicados, ausencia de datos, sueño activo y ponderación de promedios. XCTest UI cubre navegación, periodos, selección, registros y retorno, además de accesibilidad y apariencia.

Este documento no tiene comportamiento ejecutable: no aplica TDD unitario; se valida contrastando el contrato con las pruebas y revisando su diff. Las evidencias de ejecución se registrarán por separado. No se considera finalizado por compilar. La reversión del hito retira únicamente sus archivos nuevos y los cambios concretos de acceso al nuevo escenario; conserva todo el trabajo anterior y la pantalla aprobada.

Las comprobaciones añadidas después de una implementación se identificarán como regresiones. Los controles negativos sobre una implementación ya corregida no se presentarán como un ciclo TDD previo a la corrección.
