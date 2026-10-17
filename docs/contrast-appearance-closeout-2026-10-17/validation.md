# Cierre de contraste y apariencia — 17 de octubre de 2026

El gate de apariencia terminó con **167 ejecuciones aprobadas, cero fallos y cero omisiones**, usando simuladores configurados antes de iniciar cada proceso XCTest. El recheck posterior de auditoría `.all` también pasó en claro y oscuro. Las nueve imágenes nuevas de la galería son exportaciones PNG intactas de las ejecuciones finales. Este informe amplía el cierre previo y conserva el historial de los hallazgos que se resolvieron después. Los resúmenes JSON de los siete bundles están en `logs/xcresult-summaries.json`; la salida original del contrato rojo está en `logs/appearance-harness-red.log`, conservando sus espacios como evidencia.

## Resultado del gate

| Fase | Casos | Resultado | Bundle |
| --- | ---: | --- | --- |
| UI clara, shard 1 | 37 | 37 aprobados | `/tmp/nido-appearance-full-final-2026-10-17/light-1.xcresult` |
| UI clara, shard 2 | 37 | 37 aprobados | `/tmp/nido-appearance-full-final-2026-10-17/light-2.xcresult` |
| UI clara, shard 3 | 37 | 37 aprobados | `/tmp/nido-appearance-full-final-2026-10-17/light-3.xcresult` |
| Integración HTTP local con sesiones sintéticas | 3 | 3 aprobados | `/tmp/nido-appearance-full-final-2026-10-17/local-api-qa.xcresult` |
| Snapshot con firma ad hoc | 43 | 43 aprobados | `/tmp/nido-appearance-full-final-2026-10-17/snapshots.xcresult` |
| UI oscura | 10 | 10 aprobados | `/tmp/nido-appearance-full-final-2026-10-17/dark-ui.xcresult` |
| **Total** | **167** | **167 aprobados, 0 fallos, 0 omisiones** | |

El ledger de IDs originales está en `ios/Nido/Scripts/appearance-test-baseline.json`. De sus 164 IDs, tres pruebas de captura de apariencia se separaron en variantes clara y oscura: `BabyCareUITests/testNativeVisualCheckpointsLightAndDark`, `NidoUITests/testPremiumTodayVisualReviewCaptures` y `GoalDesignPreviewUITests/testOverGoalKeepsTheRealQuantity`. El ledger conserva la relación entre esos IDs y las variantes; las fases ejecutaron 167 métodos distintos en total. Los 43 Snapshot y los tres flujos API están incluidos una sola vez. Cada bundle final se comprobó contra su cantidad esperada; el validador de resultados no encontró omisiones, fallos ni skips.

La fase oscura incluyó las siete pruebas oscuras previas y las tres variantes oscuras recién separadas. La fase de snapshots se ejecutó con Reducir movimiento activado en el simulador QA. Los opt-ins de accesibilidad y widgets estaban activos; no se filtraron issues de auditoría ni se marcaron fallos como esperados. El target Snapshot se ejecutó firmado ad hoc para simulador, pues la ejecución sin firma había fallado al escribir en Keychain con `errSecMissingEntitlement` (`-34018`). La evidencia diagnóstica y la reconciliación previa están en [el cierre anterior de simuladores](../simulator-closeout-2026-10-17/validation.md).

Los contratos del driver, el plan de fases y el comprobador `.xcresult` pasaron **20/20** según la comprobación independiente del cierre. La prueba roja previa del contrato de restauración está conservada en `/tmp/nido-appearance-red.txt`: al fallar una fase, el runner propagaba el error de Xcode pero no informaba que no pudo restaurar la apariencia original. El arreglo hace que restauración fallida produzca error; el driver también bloquea una fase si el preset no coincide y exige que el resumen indique `result: Passed` con el recuento exacto y cero skips. Los tests viven en `ios/Nido/Scripts/appearance-phase-plan.test.mjs` y `appearance-result-validation.test.mjs`.

## Contraste y texto «Ver todo»

La auditoría nativa `.all` quedó **resuelta en la verificación posterior al cambio tipográfico**, en claro y oscuro: `/tmp/nido-contrast-ab-body-2026-10-17.xcresult` pasó 2/2, con cero fallos, skips o expected failures. El caso rojo previo está en `/tmp/nido-accessibility-tint-recheck-2026-10-17.xcresult`; el bundle posterior corresponde al texto body semibold. La ejecución completa final también incluyó las auditorías claras y oscuras sin registrar issues (`NIDO_AUDIT_ISSUE` no aparece en sus logs). El cierre previo documenta correctamente que las ejecuciones anteriores seguían reportando el botón; esa evidencia histórica se conserva en [contrast-measurement.md](../simulator-closeout-2026-10-17/contrast-measurement.md).

La etiqueta visible de «Ver todo» se aumentó de subheadline a body semibold, manteniendo su color, espacio de toque de 44 puntos y el degradado de Nido. El cambio conserva la jerarquía visual en las capturas clara y oscura y hace el texto más legible. Los intentos focalizados anteriores de alinear tint/foreground y de cambiar el estilo del botón no resolvieron el hallazgo; se descartaron antes de elegir el tamaño body. El recheck `.all` posterior pasa sin ocultar issues: el handler continúa registrando fallos y devuelve `false`. La medición de contraste de los recortes sigue siendo evidencia complementaria, limitada a los píxeles de glifo y esquinas de esas dos capturas; no es una certificación WCAG de toda la aplicación.

## Apariencia oscura

La suite no cambia el modo del sistema mientras XCTest está ejecutándose. Las capturas de diagnóstico mostraron que solicitar el modo oscuro durante una sesión ya iniciada podía dejar la ventana de la app en modo claro; al iniciar cada proceso con la apariencia del simulador preconfigurada, las aserciones estrictas y las capturas quedaron alineadas. El resultado demuestra que la preconfiguración externa es reproducible; no determina si la propagación tardía se origina en XCTest/iOS o en la aplicación. No se añadió un override de tema en producción ni se debilitó la comprobación por píxeles.

La comprobación oscura fue roja cuando el fondo observado era claro: `/tmp/nido-dark-assert-red-2026-10-17.xcresult` registró brillo 225, por encima del límite oscuro `<100`. Con el simulador ya configurado en oscuro, la comprobación pasó y registró brillo 45: `/tmp/nido-dark-assert-green-2026-10-17.xcresult`. La galería oscura final se exportó del bundle `dark-ui.xcresult`; el gate completo mantuvo el chequeo, sin skips.

## Capturas finales

Las nueve imágenes de `../goal-rings-checkpoint-2026-10-17/screenshots/` tienen los mismos SHA-1 que sus adjuntos fuente en `/tmp/nido-appearance-full-final-2026-10-17/gallery-light/` y `gallery-dark/`; no se editaron píxeles.

| Pantalla | Claro | Oscuro |
| --- | --- | --- |
| Hoy | [captura](../goal-rings-checkpoint-2026-10-17/screenshots/implemented-light-today.png) | [captura](../goal-rings-checkpoint-2026-10-17/screenshots/implemented-dark-today.png) |
| Historia | [captura](../goal-rings-checkpoint-2026-10-17/screenshots/implemented-light-history.png) | [captura](../goal-rings-checkpoint-2026-10-17/screenshots/implemented-dark-history.png) |
| Crecimiento | [captura](../goal-rings-checkpoint-2026-10-17/screenshots/implemented-light-growth.png) | [captura](../goal-rings-checkpoint-2026-10-17/screenshots/implemented-dark-growth.png) |
| Peso | [captura](../goal-rings-checkpoint-2026-10-17/screenshots/implemented-light-weight.png) | [captura](../goal-rings-checkpoint-2026-10-17/screenshots/implemented-dark-weight.png) |

Crecimiento con tamaño de accesibilidad máximo: [captura clara](../goal-rings-checkpoint-2026-10-17/screenshots/implemented-accessibility-growth.png). Los píxeles de las capturas sirven para revisar la presentación de esos estados; no sustituyen VoiceOver en un dispositivo físico.

## Integración HTTP y repetición

Las tres pruebas UI de API usan un servidor HTTP local y PostgreSQL desechable con sesiones de Nido sintéticas. No son sesiones de Apple ni verifican Sign in with Apple real. El helper guarda credenciales de prueba en un archivo temporal con permisos privados; los valores de tokens no se incluyeron en documentación ni logs publicados. Las evidencias de servidor están bajo `/tmp/nido-appearance-full-final-2026-10-17/local-api-qa-evidence/`.

Una ejecución previa en el iPhone 16 Pro pasó 2/3 y expiró esperando la hoja «Registrar pañal · Pis» en `testFreshInstallationCreatesAnIndependentHouseholdAndOnlySeesItsOwnBaby` (`/tmp/nido-appearance-full-final-2026-10-17/local-api-ui.xcresult`). El mismo caso pasó en la repetición con fixture nuevo, y las tres pruebas pasaron juntas tanto en QA (`local-api-qa.xcresult`) como en una repetición con fixture nuevo en el 16 Pro (`local-api-16-retry.xcresult`). No se determinó la causa del fallo puntual y se conserva el bundle original. La captura de la hoja visible en la repetición está en `api16-fresh-install-live.png`.

## Reproducción

El proyecto comparte un plan y un scheme de validación sin credenciales: `ios/Nido/Nido.xcodeproj/NidoAppearanceValidation.xctestplan` y `ios/Nido/Nido.xcodeproj/xcshareddata/xcschemes/NidoAppearanceValidation.xcscheme`. El build `build-for-testing` firmado ad hoc y la inspección de que el scheme lo reconoce pasaron en la copia sincronizada `/tmp/nido-native-validation`; evidencia del build: `/tmp/nido-appearance-canonical-build.log`. El comando base usado fue:

```sh
xcodebuild build-for-testing \
  -project Nido.xcodeproj \
  -scheme NidoAppearanceValidation \
  -destination "platform=iOS Simulator,id=$QA_UDID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath /tmp/nido-premium-derived/SourcePackages \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
```

El plan estándar no cambia el modo de apariencia. Antes de cada fase se preconfigura el simulador; antes de Snapshot también se activa Reducir movimiento. El scheme normal `Nido` no se modificó.

El driver repetible es `ios/Nido/Scripts/run-appearance-phased-ui-tests.mjs`; valida apariencia antes de cada fase, ejecuta las fases en orden y restaura el modo inicial al salir. Contratos del runner y el comprobador de resultados: `ios/Nido/Scripts/appearance-result-validation.mjs`. La interfaz del driver es:

```sh
node ios/Nido/Scripts/run-appearance-phased-ui-tests.mjs \
  --device-id <SIMULATOR_UDID> \
  --xctestrun <SIGNED_XCTESTRUN> \
  --derived-data-path <DERIVED_DATA> \
  --results-dir <NEW_RESULTS_DIRECTORY> \
  --cloned-source-packages-dir <SPM_CACHE> \
  --api-root <LOCAL_API_ROOT>
```

Usar `xcodebuild build-for-testing` para producir el `.xctestrun` de `NidoAppearanceValidation`, con `-clonedSourcePackagesDirPath`, `-disableAutomaticPackageResolution` y `-skipPackageUpdates`. Para Snapshot se usó `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`; no se emplearon certificados ni credenciales Apple. El plan opt-in activa auditoría/widget tests y no incluye secretos. La integración API requiere fixture efímero propio y las variables `DATABASE_URL`, `NIDO_UI_TEST_API_BASE_URL`, `NIDO_UI_TEST_RUN_ID` y `NIDO_LOCAL_API_UI_ENV_FILE`; el harness genera tokens sintéticos localmente y los limpia al concluir. No guardar valores reales de esas variables en el repositorio.

El gate final fue particionado: tres shards Light de 37 pruebas, fase API de tres pruebas, Snapshot 43 y Dark 10. Se usaron bundles separados y una apariencia externa por proceso. Por eso se informa el inventario completo de 167 ejecuciones y sus resultados por bundle en vez de presentar una única invocación Xcode que nunca ocurrió.

## Cambios y rollback

El cierre conserva los cambios nativos de este trabajo y sus regresiones: el calendario de Historia amplió la región táctil visible con `contentShape(Rectangle())` tras una reproducción roja de tap/selección; el texto de actividad de Hoy quedó alineado con su etiqueta visible; el botón «Ver todo» usa tipo body para legibilidad; y el avatar M deja de dibujarse cuando el encabezado sale del viewport. Las capturas de desplazamiento de Hoy que muestran despejada la barra de estado están en el cierre previo. La suite API de permisos tuvo su contrato rojo/verde y el backend desplegado tiene su propio plan de rollback en la documentación de despliegue enlazada desde ese cierre.

El worktree estaba dirty y compartido; no se debe restaurar entero. El rollback nativo corresponde a revertir el commit `dd6a9d2` como unidad atómica (cliente y pruebas asociados), preservando cualquier cambio posterior o ajeno. Este cierre de documentación y capturas se entrega por separado. La reversión del backend corresponde a su documentación de despliegue.

Al cerrar se eliminaron los tres simuladores QA creados para este gate y el contenedor detenido del harness; se retiraron los archivos temporales de entorno que podían contener tokens sintéticos. No queda un servidor API, contenedor ni fixture desechable activo. Se preservaron los dos simuladores designados como dispositivos de usuario: iPhone 17 Pro `C7C07516-C199-47F5-BD62-6B6E5BA5CCB9` e iPhone 16 Pro `516B4FA1-D8C4-4389-9836-79095056D5CB`. El iPhone 17 Pro Max `88E24D77-B7D5-4472-86F6-BF0A78001C5B` también quedó intacto en estado Shutdown. Los `.xcresult` completos permanecen bajo `/tmp` para mantener la evidencia sin introducir bundles voluminosos al repositorio.
