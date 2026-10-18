# Validación final del cierre de calendario

**Gate recuperado aprobado: 186 ejecuciones, cero fallos y cero omisiones.** Los resúmenes completos confirman Light, API, capturas y Dark; sus identificadores coinciden con el plan en cada fase. Son 186 identificadores actuales distintos: la base histórica de 183 sustituye tres pruebas visuales combinadas por seis variantes clara/oscura. No hay casos del plan ausentes ni añadidos inesperados.

## Estado y evidencia vigente

| Fase | Resultado | Evidencia |
|---|---|---|
| Light UI | 114 pruebas, 0 fallos, 0 omitidas | `final-run-recovered/light-ui.xcresult` |
| API UI | 3 pruebas, 0 fallos, 0 omitidas; base de datos nueva | `final-run-recovered/local-api-ui.xcresult` |
| Capturas | 59 pruebas, 0 fallos, 0 omitidas; verificación independiente de root | `final-run-recovered/snapshots.xcresult` |
| Dark UI | 10 pruebas, 0 fallos, 0 omitidas | `final-run-recovered/dark-ui.xcresult` |
| Core y contratos | 209 pruebas en 31 suites y 16 pruebas Node, aprobadas | `/tmp/nido-final-calendar-gate-2026-10-18/nonnative-final/` |
| Release para simulador | Build de app y `NidoLiveActivity.appex` aprobado; no es un archivo de distribución firmado | `final-run-recovered/release-build.log` |

La revisión visual manual de las exportaciones de Light y Dark no detecta regresiones en la composición o paleta de Hoy ni obstrucción de la fecha. La captura `light-visual-attachments/C17A0479-9AC1-4BA3-AD3A-18495A6B604B.png` y su geometría muestran el 18 de septiembre en `(229, 279, 55.67, 57)`, debajo del encabezado (`y201.67`) y dentro del viewport. Se revisaron también Hoy en `light-visual-attachments/premium-today/` y Hoy/calendario en `dark-visual-attachments/`. Nido Luminoso permanece sin cambios. La revisión cubre estos estados, no cada pantalla posible.

## Causa reproducida y alcance

La reproducción limpia mostró que el día seleccionado quedaba fuera del viewport (`y30.58`, viewport desde `y62`). Una reproducción posterior detectó el encabezado anterior terminando en `y142`, más allá del límite usable `y132`. Tras la corrección, la API situaba la fecha en `y333.67`, por debajo del encabezado `y132–201.67`. Evidencias: `/tmp/nido-interaction-boundary-2026-10-18/cleanred/original505-cleanred.xcresult` y `header-usable-red/original505-header-usable-red.xcresult`.

Los checks enfocados pasaron: 2/2 UI y 3/3 API sobre base nueva, sin omisiones, en `declarative-position-guarded/focused-guarded.xcresult` y `api505-fresh.xcresult`. La validación histórica de UI solo comprueba bordes respecto a `app.frame`, no garantiza contención general en el viewport del calendario. La geometría visual citada sí evidencia la contención de ese caso.

El primer intento de este gate terminó incompleto: faltaba `Info.plist`; Main reportó 13 aserciones fallidas en 12 casos de 63; y fallaron dos casos de widgets. En la recuperación, ambos widgets pasaron con SpringBoard operativo. Una reproducción aislada del primer caso de toma también pasó (1/1), pero no explica el primer fallo ni permite atribuirle causa. Otro gate histórico ejecutó 186 pruebas: 185 aprobadas y una fallida; su cifra de 183 era la base histórica. El detalle por intento está en [calendar-follow-up.md](calendar-follow-up.md). Las causas históricas no demostradas siguen sin atribución.

## Revisión y reproducibilidad

La revisión independiente no encontró defectos accionables adicionales en el cambio. SHA congelados, con copia canónica y mirror coincidentes: `HistoryView.swift` `2f0142b40d32379a8a18d59333d38d7e0279831fb1788cb9fda61fce281a83eb`; `NidoUITests` `70a0867940cece60a5d8a4ed5d73f234702da89e4857f97ba30064192f26dbbd`; `HistoryFitnessUITests` `1c33256f18ad11abd4c465345f20609e5d6c1980d25b329c8d24e5f751f7c13e`. La unidad de rollback será el nuevo commit de calendario, pruebas y documentación sobre la base `ff1226b`; revertir esa unidad conservará la corrección de autenticación ya contenida en la base.

Este cambio documental no requiere TDD unitario. La comprobación proporcional consiste en parsear los JSON y comparar el diff, además de contrastar cifras, hashes y afirmaciones con los artefactos citados. El ledger reproducible está en `final-run-recovered/xcresult-selector-ledger.json`. La apariencia final volvió a claro y Reduce Motion a `0`; se apagó solo el simulador QA, conservando sus datos.
