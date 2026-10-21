# Validación del detalle de Sueño

Estado: validación en curso; este documento sigue siendo provisional. El alcance de este registro corresponde al hito 3 del plan y solo cubre la ruta DEBUG de Sueño. La autorización del usuario incluye continuar con los detalles de las demás métricas y los datos fijados; este punto de Sueño es una revisión intermedia del patrón, no una nueva condición de aprobación del usuario. El trabajo posterior espera el cierre de las comprobaciones de este documento.

## Alcance y límites

Se valida la interacción de ejemplo `evolution-design-sleep` y su estado vacío `evolution-design-sleep-empty`: abrir el detalle nativo desde la tarjeta, cambiar periodo, explorar la gráfica, consultar registros y volver. `evolution-design-summary` y `evolution-design-empty` siguen siendo escenarios de revisión sin acciones. Los datos de ejemplo son de solo lectura. No se ha probado integración con datos reales, permisos ni sincronización, y no se han cambiado los iPhone.

## Evidencia de lógica

- **Roja inicial del contrato:** antes de implementar los tipos del modelo, `swift test --filter SleepEvolutionTests` falló en compilación porque no existían `SleepEvolutionPeriod` y `SleepEvolutionSnapshot`.
- **Roja de identificadores del periodo:** la prueba falló porque faltaba `periodRecordIDs`; evidencia: `/tmp/nido-sleep-period-recordids-red.log`.
- **Roja de formato de fecha:** antes de añadir `SleepEvolutionDateFormatting`, las pruebas enfocadas fallaron porque no existía el helper; evidencia: `/tmp/nido-sleep-date-format-red.log`.
- **Verdes enfocadas:** 12 pruebas de `SleepEvolutionTests` pasaron (`/tmp/nido-sleep-focused.log`); las pruebas de `SleepEvolutionDateFormattingTests` también pasaron (`/tmp/nido-sleep-date-format-focused.log`).
- **Suite:** `swift test` pasó 228 pruebas en 34 suites (`/tmp/nido-full-suite.log`). Esta ejecución cubre el estado de lógica registrado allí; no sustituye la validación final de UI tras los ajustes actualmente en curso.
- Varias pruebas de bordes y controles negativos se añadieron después de implementar la lógica. Son regresiones, no evidencia TDD. Los controles temporales verificaron fallos al revertir manejo horario y expansión de intervalos; esos cambios de control se revirtieron.

## Evidencia de navegación e interfaz

- La primera prueba UI de ruta fue roja (`sleep-route-red.xcresult`, 0/1) antes de conectar la navegación. La primera ejecución verde de esa ruta fue `sleep-route-initial-green`, 1/1.
- La primera ejecución amplia de UI informó 7 casos y 18 fallos en el registro de texto. Su `.xcresult` quedó corrupto (`no Info.plist`) cuando se interrumpieron diagnósticos tras quedar bloqueados. **No es un resultado válido de suite ni debe citarse como tal.**
- La inspección visual inicial rechazó el resultado por fecha partida en líneas, unidades de peso y divisor. Esos defectos requieren confirmación en la revisión posterior.
- **Dos rojas causales confirmadas:** `/private/tmp/nido-evolution-preview-2026-10-20/sleep-causal-red-confirmed.log` y su `.xcresult` registran 0/2. El resumen semanal mostraba 12 h 30 min y 1 de 1 día registrado elegible, pero la selección del intervalo no se exponía como `sleep-evolution-selected-interval` y la lista omitía `sleep-evolution-record-evolution-preview-sleep-today-completed`. Una prueba independiente también detectó que el gesto nativo de seleccionar en la gráfica no respondía.
- **Verde enfocada:** las dos regresiones causales pasaron 2/0 en `sleep-causal-green-stable.xcresult` con `TEST SUCCEEDED`. La selección ahora usa un gesto nativo estable. Este resultado cubre las dos regresiones causales; no equivale al cierre de la suite UI completa.
- La primera suite válida de nueve casos registró 7 aprobados y 2 fallidos: una consulta del contenedor vacío y una coordenada de viewport incorrecta del arnés. No se estableció un defecto de producto con esos dos fallos. QA prepara una repetición con el arnés corregido.
- Se añadió una prueba de la fila más antigua sobre la barra flotante. El primer intento tuvo una medición incorrecta del marco de la barra; al corregir el arnés, la ejecución quedó bloqueada por falta de espacio durante la compilación (`database or disk is full`, 158 MiB libres). Ese registro no es evidencia de comportamiento. Se liberaron únicamente cachés y dependencias regenerables antiguas de Nido; se conservaron el Release firmado y todos los resultados.
- El resultado anterior de siete casos con 18 fallos tiene texto conservado, pero su `.xcresult` está corrupto (`no Info.plist`); no se considera una ejecución válida.

## Pendiente antes de cerrar

1. Completar la suite final válida de nueve casos, ahora en ejecución, y registrar sus resultados `.xcresult`.
2. Revisar las capturas visuales finales de Día/Semana, claro/oscuro, vacío y texto XXXL. La composición visual v2 recibió aprobación interna; quedan pendientes las capturas con glifos finales y la comprobación visual de esos estados.
3. Confirmar navegación, periodo, selección nativa de gráfica, lista de registros, retorno y contención sobre la barra flotante con los resultados finales. La suite completa de 208 escenarios no se ejecutará en este hito; solo se harán las regresiones de alcance acordadas. Las pruebas pendientes de resumen de siete casos, navegación y Release deben quedar identificadas en la entrega final.
4. Registrar la verificación de congelación de fuentes: fuente canónica y espejo coinciden con SHA-256 `fd1762fcf460abd869007d4e164f5fd8c538656d8e542dd11dcfd172e7255fa6` para Detail y `a97758d06a07071a8c8ee34b909ea5a5a377bc672772855a9ff282297e871af0` para Records. El equipo corrigió la copia de FileProvider mediante staging nuevo y renombrado atómico; no se borraron datos del usuario ni resultados.

No se declara completo este punto de validación hasta incorporar esos resultados. Las 228 pruebas de lógica en 34 suites, incluidas 12 de Sueño y 2 de formato, pasaron; esta suite no sustituye la final UI ni una compilación Release. La matriz completa de 208 escenarios permanece sin ejecutar. Los detalles de otras métricas, los datos fijados y la integración en vivo todavía no se han implementado; la autorización para continuar con los primeros dos ámbitos ya está dada. La reversión del hito se limita a los archivos nuevos de detalle y los cambios necesarios para exponer el escenario DEBUG, conservando la pantalla aprobada y el trabajo previo.

Este documento describe validación, no añade comportamiento ejecutable: no aplica TDD unitario. La comprobación proporcional consiste en contrastar cada afirmación con logs y artefactos válidos y revisar su diff. La aceptación final requiere adjuntar evidencia reproducible, no solo una compilación.
