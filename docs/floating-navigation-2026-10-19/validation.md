# Navegación flotante: evidencia de validación

**Estado: validación integral pendiente.** V7b usa un margen inferior físico de 8 pt en SE y cápsula alineada de 62 pt; V6d queda como iteración histórica rechazada por estar demasiado arriba. Hay resultados enfocados aprobados, pero el full gate solo completó Light y dejó sin ejecutar API, Snapshot y Dark. La revisión estática no cubre QA físico con teclado ni orientación horizontal.

## Ajuste de posición

La primera prueba causal, `floating-margin-v7-red.xcresult`, falló 1 vez: el margen medido era 34 pt frente al máximo permitido de 24 pt. El primer intento llamado `floating-margin-v7-green.xcresult` también falló con 34 pt; el nombre del archivo no representa un resultado verde. La causa fue que el contenedor predeterminado de `UIHostingController` añadía un inset interno duplicado de 14 pt. Al configurar `safeAreaRegions = [.keyboard]`, se excluyó ese inset y se conservó el ajuste para el teclado.

La prueba `floating-margin-v7b-green.xcresult` pasó 1/1. En una ventana de `402 × 874`:

| Medición | Resultado |
|---|---:|
| Cápsula | `(20, 792, 298, 62)`; borde inferior `854`, margen físico `20` pt |
| CTA del menú | `(328, 796, 54, 54)`; centro `y=823` |
| Última fila | borde inferior `779.67`; separación respecto al dock `12.33` pt |

Raíz inspeccionó y aprobó la posición en las capturas Light de mitad y final del scroll: [mitad del scroll](screenshots/today-mid-scroll-light-v7b.png) · [final del scroll](screenshots/today-end-scroll-light-v7b.png). Las capturas anteriores de V6d siguen rechazadas por posición.

## Regresiones V7b verificadas

- `v7b-light-focused-10.xcresult`: Light, 10/10.
- `v7b-dark-geometry-notice.xcresult`: geometría Dark y Notice accesible a XXXXL, 2/2. Raíz aprobó ambas capturas: [Today Dark](screenshots/today-dark-v7b.png) · [Notice XXXXL Dark](screenshots/notice-accessibility-xxxl-dark-v7b.png).
- `v7b-compactSE-regressions.xcresult`: iPhone SE (3.ª generación), iOS 26.5, geometría compacta y cuatro finales de navegación, 2/2. En pantalla `375 × 667`, la cápsula mide `(20, 597, 271, 62)`, termina en `659` y deja margen físico de 8 pt; el CTA ocupa `x=601–655` y los objetivos de pestaña mantienen 44 pt. Finales de Hoy (`584.5`), Historia (`585`), Ritmos (`501`) y Ajustes (`585`) quedan antes de la barra en `597`; Hoy conserva 12.5 pt de despeje. QA compacto con Light restaurado y reducción de transparencia apagada. Raíz aprobó visualmente la captura [compacta a mitad del scroll](screenshots/today-mid-scroll-compact-v7b.png).
- `appearance-scripts-full-v7b.log`: fase combinada de plan y validación de resultados, 20/20 sin fallos ni omisiones.

Verificación adicional de la adaptación: `default-v4-focused.xcresult` pasó 1/1 y la auditoría del dock no atribuyó hallazgos. El selector existente de caption XXXL pasó 1/1 en Light; raíz revisó la captura `99CEF...` y confirmó los cuatro títulos completos, sin solapamiento y con el material visible. El mismo selector pasó 1/1 en Dark; raíz revisó `EFE574F1...` y confirmó los cuatro títulos completos y el cristal saludable. El intento XXXL del host permaneció en el default de 62 pt y queda excluido como evidencia. `default-v4-se-focused.xcresult` pasó 1/1 a `375 × 667`: cápsula `(20, 597, 271, 62)`, borde inferior 659 (8 pt de margen) y CTA `(301, 601, 54, 54)`; raíz aprobó la captura `2183...`.

## Evidencia anterior conservada

V6d reprodujo el defecto con `focused-final-red.xcresult`: el máximo de scroll era `768`, frente al borde de CTA en `827`; la barra nativa quedaba en `851.67` en una ventana de `874`. `focused-v6d-geometry.xcresult` validó entonces geometría y filas bajo el material, pero no aprobó la posición final.

V6d también tuvo `focused-v6d-light-10.xcresult` (10/10, sin fallos ni omisiones), geometría Dark 1/1 (`focused-v6d-dark-geometry-system.xcresult`), Notice XXXL explícito 1/1 (`focused-v6d-dark-notice-xxxl-explicit.xcresult`) y Primary Navigation 1/1 (`primary-nav-four-scrollowners-v2.xcresult`, 55.4 s; finales Hoy, Historia, Ritmos y Ajustes accesibles y al menos a 12 pt del dock). Son evidencias de regresión de V6d; deben repetirse en V7b antes de cerrar.

La prueba de plan de fases pasó 20/20 (`phase-plan-green.log`). Doce archivos usan el helper de identificador público estable porque SwiftUI expone la barra como rasgo `Other` en XCTest; no se debilitaron aserciones de corrección. La cobertura de cuatro finales de scroll fue añadida después de la implementación, así que constituye regresión y no TDD de un caso nuevo.

## Gate y siguientes comprobaciones

El gate previo de 198 selectores se detuvo con 73 pruebas Light aprobadas y 0 fallidas; ninguna fase terminó, así que ese resultado sigue siendo parcial y no aprobado. El primer full gate V7b se interrumpió con 84 aprobados y 1 fallo en `NidoUITests.testRegistrationMenuShowsTheDiaperActionForVisualGlyphReview` (línea 78): OCR devolvió `panal=nil`. El proceso terminó por SIGTERM mientras el bundle estaba incompleto; no se aprobaron el gate ni fases API. Los blobs originales de PNG y accesibilidad se recuperaron en `/tmp/nido-floating-navigation-2026-10-19/recovered-light-failure-attachments/`. Raíz verificó visualmente que el icono y “Pañal” eran correctos; macOS Vision 26.6.2 leyó “• Pañal” con confianza 0.5 en el mismo PNG. Se distinguió ese resultado de OCR estático en macOS de la lectura de fixture iOS 26.5 antes del arranque de la app.

La prueba `ocr-static-red-v1.xcresult` reprodujo el fallo con el helper OCR ROI original. La corrección acota el OCR al texto a la derecha del icono y conserva la comprobación de que el texto esté dentro de la fila. El PNG de fixture está versionado en `ios/Nido/NidoUITests/registration-menu-ocr-fixture.png`; la región de interés, el umbral y el control negativo de canvas mantienen bytes idénticos a HEAD. `ocr-static-green-v4-rowbounded.xcresult` pasó 1/1 en 13.93 s; las variantes v2 y v3 también pasaron 1/1. La revisión de raíz y el hash del test actual confirmaron el cambio. Es una corrección de fixture/helper de prueba; la app de producción V7b no cambió.

El ledger actual de scripts contiene 28 pruebas Node aprobadas y revisión independiente aprobada: 196 selectores ordinarios más 2 de auditoría raw, con el selector exacto ejecutado una sola vez. El modo estricto normal termina con 0 Passed / 65 Failed. `diagnostic-ledger-red-exitkind.log` y `red-identity.log` conservan la evidencia roja; `green-exitkind.log`, `full-exitkind.log` y `full-identity.log` conservan la verde. Se comprueban identidad exacta del árbol y conteos de resultados/skips; salida inesperada, señal, resultado nulo, bundle incompleto o bundle obsoleto provocan aborto. Una auditoría raw fallida conserva hallazgos, devuelve código 2 y nunca declara 198 verdes.

`full-198-v7b-ocr-fixed` completó únicamente Light: 120 pruebas, 119 aprobadas y 1 fallo de auditoría raw. Hay 10 hallazgos: 4 de Dynamic Type (incluido el defecto real de etiqueta fija, ya corregido) y 6 de contraste. Las seis mediciones Light están entre 7.06 y 11.81; JSON y captura están guardados. API, Snapshot y Dark no se ejecutaron. El gate de 198 no está aprobado.

El full run fresco `full-196-plus2-final` usa el freeze `148` sin discrepancias y la fuente Light activa. Terminó Light con 72 aprobadas y 1 fallo: `HistoryFitness.testAccessibilityTextSizeKeepsSelectedDateAndTotalsAvailable` (558). El runner debe finalizar el bundle y no iniciar otra fase tras un fallo ordinario. El diagnóstico de raíz atribuye el fallo al gesto de prueba: viewport raw `(0, 292, 402, 548)` y comienzo del gesto en `y=648.2`, dentro del dock AX (aprox. `605–854`); 40 gestos ineficaces no demuestran un defecto de scroll de producción. Tras capturar el fallo, el tester aprobó un ajuste solo de pruebas para usar endpoints despejados en ambos helpers; `bringChartPlotCenterIntoView` también usa el rect solo para comprobar visibilidad antes del gesto raw. Se conservan el límite de 40 intentos y `isHittable`. Requiere prueba enfocada afectada y full run fresco; no está completado.

Actualización: el primer full run terminó Light con 119 pruebas: 118 aprobadas, 1 fallida y 0 omitidas (2.232,7 s); las demás fases no se ejecutaron. La corrección solo de pruebas para el gesto de History está en el archivo identificado por SHA `ed940f95` (no es un commit). Pasó la prueba enfocada y otras cinco relacionadas; revisión aprobada. Se conservaron las aserciones de 40/20 intentos.

El full run actual `full-196-plus2-history-helper-v1` parte del freeze `148` sin discrepancias. Su fase Light activa lleva 108 aprobadas, 0 fallidas y cubre las pruebas del widget; las fases restantes siguen pendientes. No equivale a un gate completo.


La matriz API se verificó en el workspace temporal `/tmp/nido-api-root-copy-2026-10-19`: los 49 archivos comparados coincidieron con el hash esperado y raíz confirmó cero discrepancias; se usó `npm ci` fijado. Los dos intentos en el workspace canónico se atascaron antes de conectar con la base de datos, durante lecturas ESM del filesystem y la carga de migraciones Drizzle sin datos. No se modificaron migraciones de producción ni timeouts. El resultado `api-from-temp-root-v1/local-api-ui.xcresult` fue verificado independientemente por raíz: 3/3 aprobadas, 0 fallidas y 0 omitidas.

Balance combinado: 196 ejecuciones ordinarias aprobadas y 2 selectores raw fallidos con hallazgos de contraste; sin omisiones. No se declara verde el gate de 198. El reviewer completó el triage: las diez muestras del JSON raw tienen mínimo 7.060159; raíz aprobó visualmente las capturas actuales. El resultado sigue limitado a esas capturas y esos dos selectores conservan su estado fallido.

El JSON durable `rendered-contrast-dark-v8.json` y tres capturas v8 muestran ratios Dark reales: modal 8.034–8.748 y normal 8.148–9.029 en XXXL. La validación de raíz confirmó JSON y hashes. El alcance cubre solo las capturas listadas; no representa todos los materiales de cristal.

La suite Swift completa pasó: 209 pruebas en 31 suites, según `/tmp/nido-floating-navigation-2026-10-19/swift-unit-full-v1.log`, cuyo resumen verificó raíz. La compilación optimizada Release de simulador también pasó (`simulator-release-build-v1.log`); solo emitió un warning de `try` no usado.

Build 51 compiló en Debug y Release genérico y firmó la app y Live Activity `0.1.0/51` para arm64 con el equipo `6VVEKN47Y3` y `codesign` 0. Se resolvió el bloqueo de mirror del proyecto. Raíz instaló y abrió la app normal en el teléfono, sin argumentos de fixtures ni llamadas globales de apariencia. Tras respaldar Support y preferencias, creó el directorio privado vacío requerido e instaló Debug 51 sin desinstalar; las comparaciones antes/después y tras 22 fixtures confirmaron Support y preferencias byte a byte idénticos. La evidencia física `physical-build51-22-v1.xcresult` terminó 22 pruebas: 21 aprobadas, 1 fallida y 0 omitidas. El único fallo, `PhysicalReviewRegression.testEmptyGoalSetupIsDiscoverableAndAddsTheFirstRings`, obtuvo `.value == nil` frente a `Sin objetivo`. El vídeo final `physical-goal-failure-last-frame.png` fue revisado por raíz y reviewer: los tres placeholders eran visibles y correctos; no se ha demostrado un fallo de la app.

El usuario confirmó explícitamente la posición, alineación y contenido bajo el dock de Release 51 tras abrirla con datos reales y uso normal. Esta aprobación visual cubre el dock; no sustituye la validación física automatizada pendiente ni la aceptación global.

El harness estricto de placeholders pasó su clase y la corrección final del gesto de cierre preserva las aserciones originales. La suite física v3 (21/22) más la clase física enfocada (1/1) valida 22 selectores físicos distintos; no constituye una única suite 22/22. Antes de instalar se creó un respaldo nuevo. Las comparaciones anteriores y posteriores a las pruebas y a la reinstalación Release 51 confirmaron igualdad semántica de los dos JSON y preferencias idénticas byte a byte. La Release 51 firmada y optimizada se restauró y `com.momentumia.nido` abrió sin argumentos. No se llamó a OS Automatic. Raíz revisó las capturas finales físicas con datos de fixture: [mitad del scroll](screenshots/iphone51-floating-mid-scroll-final.png) y [final del scroll](screenshots/iphone51-floating-end-scroll-final.png). La captura con fixture [no representa datos reales](screenshots/iphone51-today-light-with-fixture.png).

En SE, `compact-xxxl-caption-v1` quedó en Large con cero gestos porque el harness terminaba al evaluar `!isHittable`; el vídeo muestra el texto bajo el viewport. La progresión fue: v2 descubría el caption, pero los ocho gestos interceptaban el dock; v3 usó movimientos rápidos arriba/abajo y no probó despeje; v4 con gesto lento y sostenido pasó; v5 `compact-xxxl-caption-v5-visible-clamp.xcresult` pasó 1/1 con endpoints totalmente acotados (8/8/12). Raíz y reviewer aprobaron la captura, con el caption completo sobre el dock 2×2: [SE XXXL Light](screenshots/navigation-accessibility-xxxl-compact-light-v9.png). No se ha probado un fallo de layout de producto en este caso.

La prueba final usa un máximo de seis movimientos verticales medidos, suelo de 25 pt y espera de 0,2 s, preservando las aserciones originales. La clase física enfocada pasó 1/1, verificada independientemente en `/tmp/nido-floating-navigation-2026-10-19/physical-build51-floating-closed-loop-v1.xcresult`; la clase de simulador pasó 1/1 en `floating-navigation-class-closed-loop-v2.xcresult`. El hash de la prueba final es `f43b…907`.

La suite física v2 se abortó antes de iniciar casos: la comparación byte a byte detectó una diferencia de serialización JSON con semántica idéntica. Antes de instalar se creó un respaldo nuevo; la comparación anterior/posterior a las pruebas y la reinstalación de Release 51 confirmaron iguales contenidos semánticos de ambos JSON y preferencias idénticas byte a byte. Tras restaurar la Release 51 firmada y optimizada, el lanzamiento normal de `com.momentumia.nido` sin argumentos tuvo éxito. No se llamó a OS Automatic.

En la suite física v3, `FloatingNavGeometry` falló con el caso one-shot (finger 25, content 7.333): el máximo de la primera fila, 797.333, superó el CTA (796) y la cápsula (792); raíz revisó la captura. El setup corregido ya pasó en la clase física enfocada y su clase de simulador; no se modificó la app.

La suite Swift pasó 209 pruebas en 31 suites; Release optimizada de simulador pasó; full UI combinado ejecutó 196 selectores ordinarios aprobados sin omisiones; SE XXXL v5, clases física/simulador de cierre y lanzamiento normal de Release 51 pasaron.

- Raíz confirmó sin diferencias los 73 archivos de producción frente al freeze del full 198 con `source-test-script-resource-hashes.json` (espejo). El hash de la prueba final es `f43b…907`.
- No quedan comprobaciones pendientes salvo los dos selectores raw, que conservan estado fallido pese al triage y la medición visual favorable. No se afirma 198/198 verde ni cobertura de todos los fondos.
- No se creó commit; HEAD permanece en `3416aa1` y los cambios siguen sin commit. No hay límite de rollback de commit que reportar. El usuario puede dejar de mantener el dispositivo despierto.

La UI de posición se valida mediante resultado geométrico y capturas renderizadas; el material visual no tiene una unidad lógica aislable. Para este documento, que no cambia comportamiento ejecutable, no aplica TDD unitario; la comprobación proporcional consiste en verificar rutas y estados de evidencia al cerrar los pendientes. La causa y la corrección de margen sí tienen evidencia causal roja y verde. El resultado geométrico V7b es 1/1; no equivale al full gate ni a QA físico.

La medición reproducible de las dos capturas exactas del diagnóstico raw actual se conserva en [current-raw-rendered-contrast.json](current-raw-rendered-contrast.json): las diez etiquetas atribuidas superan 4,5:1 en esas imágenes (mínimo modal 7,06:1), sin fallo de contraste renderizado observado; los dos diagnósticos XCTest siguen fallidos y la medición no se extiende a otros fondos del vidrio.
