# Validación final de baby care — 17 de octubre de 2026

> **Cierre posterior de apariencia y simuladores (17 de octubre):** el gate final particionado de 167 ejecuciones, la actualización tipográfica de «Ver todo», el diagnóstico de apariencia oscura, los resultados HTTP con sesiones sintéticas y la evidencia de contraste están en [docs/contrast-appearance-closeout-2026-10-17/validation.md](../contrast-appearance-closeout-2026-10-17/validation.md). La reconciliación anterior de 164 casos y su finding `.all` se conserva en [el cierre previo de simuladores](../simulator-closeout-2026-10-17/validation.md); este informe mantiene el historial de la primera ejecución.


## Resultado

La integración añade objetivos manuales opcionales compartidos por hogar y bebé, versionados por fecha efectiva y calendario familiar, junto con historial de peso y talla. Los objetivos no se generan por edad: el primer objetivo entra en vigor hoy, los cambios posteriores proponen mañana y pueden fijarse para hoy o una fecha futura. Los días sin objetivo siguen sin objetivo. Hoy, Historia, vistas por semana y mes y widgets consultan el mismo calendario familiar. El anillo rosa representa sueño, el lima tomas y el turquesa pañales.

El crecimiento conserva muestras históricas independientes de peso y talla, con fecha/hora, nota e identidad estable para editar o borrar; no interpola valores ausentes. El almacenamiento local admite uso sin conexión y muestra sincronización pendiente. Las escrituras usan compare-and-set (CAS), rebasan cambios independientes y preservan conflictos para resolución explícita. La copia de seguridad incluye objetivos y medidas, las copias antiguas decodifican el estado opcional vacío y el modo demo no escribe en producción. Los cambios de cuenta/hogar y el borrado limpian el estado privado.

## Evidencia automatizada

- **Core:** 209 pruebas en 31 suites, salida final en `/tmp/nido-baby-care-core-final-v2.log`.
- **Backend:** 75 aprobadas y 5 omitidas por entorno PostgreSQL (80 en total), según el registro original recogido en `backend-validation.md`. Build de producción y typecheck completos terminaron con código 0 en copia temporal limpia, verificando hashes idénticos de los 93 archivos de código/configuración copiados: `/tmp` y `baby-care-isolated-build.log`, `baby-care-isolated-types.log` referidos allí. La ejecución en el árbol de Documents se vio limitada por lecturas/copia lentas; el informe no atribuye una causa de sistema no confirmada.
- **UI nativa:** prueba focalizada de animación, primero roja por ausencia de `animatableData` y luego verde en `/tmp/nido-goal-motion-red-v2.log` y `/tmp/nido-baby-care-finish-focused.log`. La regresión de rol propietario sin conexión y restauración tras cierre de sesión tuvo rojo inicial en `/tmp/nido-baby-care-role-backup-red-v4.log` y verde de ciclo de sesión en `/tmp/nido-baby-care-final-focused.log`.
- La evidencia original de unión de intervalos de sueño no tuvo un rojo limpio antes de implementarse; la cobertura posterior de solapes y cruces de medianoche/DST es regresión, como explica `docs/core-baby-care-validation.md`. La evidencia API contract RED/GREEN y la reconciliación CAS se detallan en ese documento y `backend-validation.md`.

La inspección visual nativa cubrió capturas en apariencia clara y oscura y accesibilidad. Para esta revisión visual no aplica TDD unitario; la validación sustitutiva es la inspección reproducible de capturas y accesibilidad. Las pruebas automatizadas sí aplican a la lógica ejecutable.

## Estado de la compuerta final

La ejecución completa terminó en `/tmp/nido-baby-care-final-v2-shard-{0,1,2,3}.xcresult`: **164 casos (121 UI + 43 Snapshot), 152 aprobados, 3 fallidos y 9 omitidos**. No se presenta esa primera ejecución como completamente verde.

| Resultado | Aprobados | Fallidos | Omitidos |
| --- | ---: | ---: | ---: |
| Shard 0 | 70 | 1 | 3 |
| Shard 1 | 29 | 0 | 1 |
| Shard 2 | 28 | 1 | 1 |
| Shard 3 | 25 | 1 | 4 |

Dos casos fallaron al abrir la sesión de prueba y al encontrar el mes inicial del calendario. Ambos pasaron con **el mismo binario y las mismas expectativas**, sin cambios de producción ni del test, en `/tmp/nido-baby-care-final-recheck.xcresult` (2/2). La causa intermitente no está confirmada y se conserva la evidencia del fallo inicial.

El tercer fallo era la captura de Hoy con texto grande: intentaba encajar el contenedor completo de anillos y tres métricas (919 puntos de alto) en una ventana de 768 puntos. Se corrigió el selector para desplazar el anillo real `daily-goal-ring-graphic`, manteniendo las pruebas independientes de acceso a cada métrica. Es una adaptación de la prueba al nuevo diseño, no un cambio de producción.

La revisión de las imágenes detectó además que la galería anterior etiquetaba capturas claras como oscuras. El escenario de captura ahora solicita explícitamente la apariencia al lanzar la app y comprueba el brillo de un píxel del fondo antes de guardar la imagen. La comprobación visual usa capturas nativas; no aplica TDD unitario a los ajustes puramente gráficos. La repetición final de ambas pruebas de captura pasó **2/2** en `/tmp/nido-baby-care-gallery-final.xcresult` y su log homónimo. Tras las repeticiones, **155 casos nativos únicos han pasado y 9 siguen omitidos**; las repeticiones no se cuentan como casos nuevos. No se volvió a ejecutar toda la suite después de modificar únicamente esas dos pruebas; el código de producción es el mismo de la ejecución completa.

Las nueve omisiones nativas corresponden a tres flujos con sesión Apple/backend provisionada, dos diagnósticos de accesibilidad que requieren activación, dos escenarios de widgets en SpringBoard, un escenario que exige Reducir movimiento en el sistema y una auditoría oscura anterior que no obtuvo la apariencia solicitada. Los widgets sí compilan y su cálculo compartido tiene cobertura Core; esas interacciones de SpringBoard siguen sin verificarse. No se afirma haber medido FPS en un iPhone físico ni realizado una sesión hablada de VoiceOver.

El build nativo final pasó en `/tmp/nido-baby-care-final-frozen-build.log`; tras modificar únicamente las dos pruebas de captura, el build volvió a pasar en `/tmp/nido-baby-care-gallery-build.log`. La revisión de espacios de los archivos de esta última corrección también pasó. Las lecturas amplias del árbol de Documents volvieron a bloquearse; por eso la ejecución nativa usó la copia sincronizada `/tmp/nido-native-validation`, y no se declara un nuevo hash global final que no llegó a completarse.

La galería `implemented.html` reúne las imágenes reales. Los registros del Core, las cuatro ejecuciones nativas completas, la repetición y los dos rojos finales se conservan también junto a este informe.

## Revisión de diseño

Se inspeccionaron las capturas finales de Hoy, Historia, Crecimiento y Peso, incluyendo apariencia oscura real y Crecimiento al tamaño máximo de texto. Se mantienen el degradado de Nido, las cantidades neutrales, los tres acentos aprobados y el resumen sin divisores verticales. Se corrigieron la escala/unidad de las medidas, la distribución vertical en accesibilidad y las etiquetas de fecha que se truncaban en la gráfica. La revisión visual de estas pantallas queda aprobada dentro de ese alcance; no sustituye una prueba en dispositivo físico.

No se creó commit ni se desplegó. La rama de trabajo es `codex/nido-premium-design`. El límite de rollback es la integración coordinada de API/esquema, Core, store, vistas y widget como una unidad; no se ha aplicado migración en producción. Al revertir, se deben preservar los cambios dirty preexistentes ajenos a esta integración.
