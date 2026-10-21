# Eje horario de Sueño — TDD y validación del candidato v5

La revisión visual del candidato v4 encontró 24 etiquetas horarias juntas y la primera hora sustituida por puntos suspensivos. Los resultados verdes anteriores no acreditaban la legibilidad de ese eje.

## Rojo y corrección

Se añadió primero `SleepEvolutionDetailUITests.testDailyChartShowsReadableHourlyAxisWithoutDroppingBuckets`. Reconoce texto en un recorte de 52 puntos del pie de la gráfica y exige entre una y seis etiquetas horarias, incluido `00` completo. La selección sigue ofreciendo los 24 intervalos del fixture del 20 de octubre, que no contiene cambio de hora.

- Rojo causal: `/tmp/nido-evolution-axis-red-v5.xcresult` y `.log`. Fallaron la existencia de etiquetas reconocibles y la de `00`; producción todavía usaba `.automatic(desiredCount: 6)`. La comprobación inicial del menú también falló con 17 filas accesibles: era virtualización de la interfaz, no pérdida de buckets. Se corrigió la recogida mediante desplazamiento y unión de identificadores, manteniendo la expectativa de 24.
- Primer intento: valores explícitos del eje mediante `EvolutionChartAxis.visibleIndices`, sin reducir dominio, barras ni selección. El eje ya mostraba cinco horas legibles, pero `00` seguía truncado. `/tmp/nido-evolution-axis-green-v5.xcresult` conserva ese fallo; OCR: `0h`, puntos suspensivos, `04`, `08`, `12`, `16`, `20`. Los 24 intervalos ya pasaban.
- Verde enfocado: `/tmp/nido-evolution-axis-green-v5b.xcresult` y `.log`. Anclaje inicial `.topLeading` y tamaño intrínseco horizontal de las etiquetas; las demás mantienen `.top`. La misma prueba pasa con seis horas legibles y 24 intervalos.

La captura revisada `/tmp/nido-axis-v5b-visual/A8A6A818-B6AD-4B41-BFEE-E220536B9036.png` muestra `00`, `04`, `08`, `12`, `16`, `20` completos. Es un recorte complementario a la prueba, no una aprobación general de la integración.

| Before | After | Why |
| --- | --- | --- |
| Muestreo automático ignorado en dominio categórico | Hasta seis claves explícitas en día y siete en otros rangos | Separar etiquetas conservando todas las barras |
| Primera etiqueta truncada | Primer anclaje hacia el interior y ancho intrínseco | Mostrar `00` completo sin comprimirlo |

La revisión independiente confirma que el dominio, las barras, la selección y el menú usan todos los buckets. Las claves por timestamp mantienen distintas las horas repetidas por DST; las pruebas Core existentes cubren días de 23 y 25 horas. No se ha añadido una expectativa de 24 horas a esos días especiales.

## Comprobaciones

- Core completo v5: 248 pruebas en 39 suites verdes, `/tmp/nido-evolution-axis-v5-core.log`.
- Inventario de QA: rojo por selector nuevo ausente en `/tmp/nido-axis-inventory-red.log`; verde 32/32 en `/tmp/nido-axis-inventory-green-2.log`. El inventario contiene 242 casos base y 245 ejecuciones programadas, sin duplicación accidental de acciones.
- `build-for-testing`: correcto en `/tmp/nido-evolution-axis-v5-test-build.log`.
- Release v5 de simulador: correcto en `/tmp/nido-evolution-axis-v5-release.log`.
- Hashes: 183/183 archivos Swift, configuración y scripts de inventario coinciden entre el proyecto y `/tmp/nido-evolution-axis-green-v5-20261021`.
- Suite completa de app v5: **245/245 ejecuciones verdes, cero omisiones** en `/tmp/nido-evolution-axis-v5-full-results`; log resumido `/tmp/nido-evolution-axis-v5-full-driver-canonical.log` y resumen `appearance-results.json`. Incluye 159 casos claros, tres casos con API real local, 70 snapshots, 11 casos oscuros y dos diagnósticos de accesibilidad. Los seis resúmenes `.xcresult` se comprobaron individualmente: cero fallos y cero omisiones. Son ejecuciones programadas, no 245 casos únicos; el inventario base contiene 242 casos y expande tres variantes claro/oscuro.
- La suite vuelve a cubrir persistencia de fijados, lista vacía, cuidador A → B → A, crecimiento accesible, recálculo tras mutación de cuidados, edición/borrado de Sueño LIVE, avance de Sueño sin interacción, el nuevo OCR del eje y todos sus intervalos. El backend limpio temporal usa las mismas fuentes y versiones fijadas, sin tocar las dependencias originales. Sus datos y sesiones son sintéticos y efímeros.
- Al terminar se repitieron los hashes: 183/183 coincidentes; el simulador quedó restaurado en claro. No se modificaron fuentes durante ninguna compilación ni durante la suite completa.

El driver se invoca desde la ruta canónica `/private/tmp/...`: con `/tmp/...` su comprobación de entrypoint puede terminar sin ejecutar fases, por lo que un exit 0 sin resultados no cuenta como verde.

No hay commits ni instalaciones físicas. El rollback de comportamiento de esta unidad abarca únicamente el muestreo/anclaje nuevo de `SleepEvolutionDetailView`, la nueva prueba OCR y su inscripción/conteos en los tres archivos del inventario. Deben preservarse las demás modificaciones locales de esos archivos. Esta documentación no requiere TDD unitario; su validación es el contraste reproducible de aserciones, resultados, captura y hashes.

La validación técnica en simulador de este candidato está cerrada. La revisión visual se limita a las capturas descritas y al recorte corregido; no se ha medido movimiento en dispositivo físico ni se declara la integración aprobada por el usuario. No hubo publicación ni cambios de App Store.
