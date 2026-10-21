# Revisión de integración — pendiente de aprobación final

No es una entrega aprobada. La evidencia vigente de compilación y simulador la mantiene QA por candidato congelado.

## Actualización vigente — eje horario v5

El defecto visual del eje diario detectado después de los verdes de v4 ya tiene rojo causal, corrección y verde de renderizado: seis horas legibles, incluido `00`, y 24 intervalos disponibles en el fixture sin DST. Core 248/248, inventario 32/32 y Release v5 pasan. La suite completa de la app v5 terminó con 245/245 ejecuciones verdes, cero fallos y cero omisiones; los 183 archivos comparados siguen coincidiendo con el proyecto. La validación técnica en simulador de este candidato está cerrada; véase `sleep-hour-axis-2026-10-21.md` para resultados, alcance visual y rollback. No se declara aprobada la integración por el usuario ni se atribuyen resultados de v4 a otro binario. No hay validación física nueva.

## Actualización 21 octubre — candidatos 12–16

La tabla histórica inferior no describe por sí sola el estado recuperado. `recovery-2026-10-21.md` registra los verdes de edición/borrado LIVE, recálculo de días terminados, fijados tras relanzar y cuidador A → B → A, y acceso a la última medida con texto máximo. Es evidencia por candidato, no aprobación final.

- Periodo de Tomas con texto máximo: candidato 12 pasó la geometría contra el dock, pero esa comprobación no detectaba el año partido. El candidato 13 reprodujo anchura insuficiente; se descartó usar la anchura accesible como medida exacta del contenedor porque XCTest devuelve el rectángulo del texto.
- Rojo válido de la comprobación final: candidato 15, fecha y flechas en la misma fila (`maxY` de fecha 437,33 > `minY` de flecha 317,67). Verde enfocado: candidato 16, fecha en fila propia en tamaños de accesibilidad y controles completos por encima del dock. Captura `care-period-accessibility-xxxl` revisada: ambos años completos, sin solapamiento de fecha ni controles. Resultados: `/tmp/nido-resume-period-red-15.xcresult` y `/tmp/nido-resume-period-green-16.xcresult`.
- Desconexión y pendientes: implementados en el resumen LIVE con agregado estrecho del store que incluye entradas, crecimiento y sueño durable. UI roja por ausencia de ambos avisos, verde enfocado 1/1; integración real del store 2/2; Core completo 242 pruebas en 38 suites. Véase `sync-state-2026-10-21.md` para logs, límites y rollback.
- El reloj del sueño activo ya tiene rojo y verde en `sleep-clock-2026-10-21.md`. La aserción reforzada (elemento existente, etiqueta no vacía y distinta) pasó también en la fase clara del candidato v4: 158/158, sin omisiones. El candidato coincide con el proyecto en 176/176 archivos Swift/configuración. Las seis fases suman 244 ejecuciones verdes, Core 248/248 y Release v4 correcto. La revisión visual sigue abierta: la captura diaria de Sueño muestra 24 etiquetas amontonadas y primera hora truncada; véase `acceptance-v4-2026-10-21.md`.

TDD aplicado a la redisposición accesible. La captura es una regresión visual complementaria. No hay commits; el rollback de este bloque abarca `EvolutionCareDetailView.swift` y la prueba del periodo, conservando los cambios locales anteriores. Esta documentación se valida contrastando rutas, aserciones y resultados; no aplica TDD unitario a su texto.

La tabla siguiente conserva observaciones históricas del punto de partida; para el estado actual prevalecen la actualización anterior, `recovery-2026-10-21.md` y la evidencia v4.

| Observación | Resolución o estado |
| --- | --- |
| Fecha truncada en Sueño con AXXXL | OCR confirmó la fecha completa tras permitir varias líneas. La contención del resto del contenido sigue en validación. |
| Veinticuatro etiquetas horarias amontonadas | Helper limita etiquetas sin quitar barras. Pendiente revisar captura final del primer `00`, que antes se convertía en puntos suspensivos. |
| Tarjetas duplicadas entre ejemplo aprobado y LIVE | Extraído `EvolutionMetricCard`, con jerarquía y disposición accesible del aprobado. Pendiente regresión visual final. |
| Corazón para Tomas y gota para Pañales en editor nuevo | Sustituidos por `EntryGlyph`, mismo símbolo de las tarjetas. Estados vacíos de los detalles también usan el símbolo unificado. |
| Fechas del nuevo componente sin zona explícita | Usa `Date.FormatStyle` con calendario, locale y zona familiar explícitos. |
| Horas AM/PM ambiguas | Corregido con TDD de Core; tres pruebas enfocadas y suite completa aprobadas. |
| Lista de Sueño sin editar/eliminar en LIVE | Hallazgo independiente pendiente de RED UI y corrección. Las acciones estaban solo en las filas de Tomas/Pañales. |
| Datos de detalle tras borrar/editar | Nueva comprobación de regresión pendiente; se declarará posterior a la implementación cuando corresponda. |
| Fijados tras relanzamiento y cambio de cuidador | Pendiente RED de persistencia antes de conectar carga/guardado al store. El modelo Core ya está probado. |
| Última medida por encima del dock | Pendiente reproducción UI; vista de crecimiento existente solo tenía padding inferior de 32 puntos. |

La revisión independiente del código confirma que los ejemplos navegan con `readOnly: true` o una fuente inmutable de crecimiento, sin callbacks reales de mutación. Esto no sustituye la validación UI de las rutas ni la revisión final.

Las pruebas nuevas de detalles puramente visuales posteriores a su ajuste son regresiones; no se presentan como TDD retroactivo. La eliminación de headings vacíos, alineación, tipografía e iconos se valida mediante renderizado y revisión visual, sin exigir una ronda roja separada por cada ajuste de presentación. Los nuevos flujos y la persistencia sí conservan el ciclo rojo → verde.
