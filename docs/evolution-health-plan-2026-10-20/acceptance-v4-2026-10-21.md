# Validación del candidato v4 — evidencia histórica anterior al eje corregido

El defecto visual descrito aquí se corrigió después con TDD y validación completa del candidato v5 en `sleep-hour-axis-2026-10-21.md`. Este documento conserva el estado y los resultados de v4, sin atribuirle esa corrección posterior.

No constituye aprobación final. Se conserva el candidato `/tmp/nido-evolution-acceptance-v4-20261021`, su producto en `/tmp/nido-evolution-acceptance-v4-derived` y todos los resultados anteriores. `/tmp/nido-native-validation` no existe en esta recuperación; no se ha borrado ni sustituido.

La comparación independiente del 21 de octubre confirma igualdad SHA-256 en 176/176 archivos Swift y configuración entre el candidato y `ios/Nido` (excluidos productos y datos de usuario de Xcode). La compilación `build-for-testing` del candidato terminó correctamente. Las acciones de prueba contienen una sola acción `test-without-building`; no se modifican las fuentes del candidato.

## Evidencia comprobada

- Core completo: 248 pruebas en 39 suites, verdes en `/tmp/nido-evolution-core-final.log`.
- Interfaz clara: 158/158, cero fallos y cero omisiones, verificados con el resumen de `/tmp/nido-evolution-phased-v4-results-20261021/light-ui.xcresult`. Incluye el predicado reforzado del reloj de Sueño, persistencia, cambio de cuidador y mutaciones LIVE.
- Snapshots: 70/70, cero fallos, en `snapshots.xcresult` dentro del mismo directorio de resultados.
- Oscuro: 11/11. Diagnósticos de accesibilidad: 1/1 en claro y 1/1 en oscuro. Todos sin omisiones. El resumen verificado de las seis fases está en `/tmp/nido-evolution-phased-v4-results-20261021/verified-v4-phase-summary.json`: 244 ejecuciones programadas, cero fallos; no son 244 casos únicos.
- API finalmente verde: 3/3 en `local-api-clean-ui.xcresult`; cinco sesiones sintéticas reconocidas por HTTP. Se usó `/tmp/nido-api-clean-deps-v4-20261021`, con las mismas fuentes de backend (45 archivos comparados, sin diferencias) y dependencias reinstaladas desde el lockfile mediante `npm ci --ignore-scripts`, sin alterar el proyecto. Evidencia sanitizada en `local-api-clean-ui-evidence-2`. El primer espejo omitió la carpeta de migraciones y después el seeder; estos fallos de preparación se corrigieron antes de los tres casos verdes y no cuentan como rojos de comportamiento.
- Release v4: `BUILD SUCCEEDED` en `/tmp/nido-evolution-v4-release.log`, compilado desde el mismo candidato congelado con destino genérico de simulador y sin firma de distribución.
- API: la fase original y una repetición `--prepare-only` completan migraciones de PostgreSQL efímero, pero el servidor no supera salud tras 90 intentos. Las tres pruebas HTTP/UI todavía no se han ejecutado. La repetición conserva evidencia sanitizada en `/tmp/nido-api-startup-recheck-20261021`.
- Arranque: proceso vivo sin listener y con `api.log` vacío; muestras en `/tmp/nido-api-startup-20261021.sample` y `/tmp/nido-api-startup-second.sample`. Un import aislado de Vite tardó 20,4 segundos y terminó. La causa del bloqueo sigue sin demostrar; no se atribuye al contrato HTTP ni al comportamiento de Evolución.

La fase de snapshots y las siguientes se retoman de manera independiente con `/tmp/nido-resume-v4-remaining.mjs`, sin repetir los 158 casos claros ni sobrescribir resultados. El simulador QA es `4A7A40BF-4FEE-41F7-9019-1D1F5F5B04AD`; las fases son secuenciales y restauran apariencia y Reducir movimiento.

## Límites

Las esperas anteriores no eran fallos de las aserciones de API. Incluso `vinext --version` excedía 30 segundos en las dependencias originales; la copia temporal de sus archivos ejecutables respondió en 0,11 segundos y la instalación temporal completa permitió arrancar el servidor. La copia parcial seguía bloqueada al leer una dependencia original. Esto acota el problema a la lectura del árbol original, sin demostrar el mecanismo concreto de FileProvider ni modificar su configuración.

## Revisión visual y pendiente real

Se revisaron solo cuatro capturas necesarias: resumen claro, periodo de Tomas AXXXL, Sueño oscuro y Sueño diario. Periodo y flechas no se solapan; Sueño oscuro conserva jerarquía, cobertura y navegación. La captura diaria descubre un defecto pese a las pruebas verdes: las 24 horas siguen amontonadas y la primera aparece como puntos suspensivos. `AxisMarks(.automatic(desiredCount: 6))` sobre el dominio categórico no está limitando las etiquetas visibles. Debe reproducirse con una prueba de renderizado antes de corregirlo; no se considera aprobada la revisión visual.

| Before | After | Why |
| --- | --- | --- |
| 24 etiquetas horarias juntas y primera hora truncada | Pendiente de corrección con índices explícitos y comprobación del render | Conservar todas las barras y hacer legible el eje |

Captura causal: `/tmp/nido-v4-sleep-day-visual/9A5EC569-755B-46CB-BB0C-4A607A76568A.png`, exportada de `SleepEvolutionDetailUITests/testAllFiveRangesUpdateThePeriodSummaryTogether` del candidato v4. No hay validación física nueva ni autorización final de la integración. Los resultados v4 no certifican automáticamente un candidato posterior a la corrección del eje.

Esta unidad solo añade evidencia y corrige un pendiente documental obsoleto: no aplica TDD unitario. Se valida contrastando comandos, resúmenes de resultados, rutas y hashes. No se añade un rojo conductual retroactivo ni se cambia producción. No hay commits; el rollback de esta unidad se limita a este documento y a la actualización de estado, preservando todos los cambios anteriores.
