# Cierre de validación en simulador — 17 de octubre de 2026

## Resultado

La reconciliación de los resultados cubre **164 pruebas únicas: 162 aprobadas, 2 fallidas y 0 omitidas**. Las 43 pruebas Snapshot pasan cuando se ejecuta el host con firma ad hoc de simulador. Tres flujos de integración contra HTTP local y PostgreSQL aislado pasan con sesiones sintéticas de Nido. Siguen fallando las dos auditorías nativas `.all` de contraste en Hoy (apariencia clara y oscura); ambas señalan un nodo de contraste asociado a «Ver todo». No se ocultaron ni filtraron hallazgos.

Este cierre combina shards congelados y repeticiones focalizadas; no se presenta como una ejecución monolítica nueva. La primera corrida de 164 casos sigue registrada en `docs/goal-rings-checkpoint-2026-10-17/implementation-validation.md` con sus 152 aprobados, 3 fallidos y 9 omitidos. El detalle nuevo aquí reconcilia esas omisiones y los fallos observados.

| Grupo único | Casos | Aprobados | Fallidos | Omitidos |
| --- | ---: | ---: | ---: | ---: |
| XCUITest UI, incluidos 3 flujos HTTP sintéticos | 121 | 119 | 2 | 0 |
| Snapshot | 43 | 43 | 0 | 0 |
| **Total** | **164** | **162** | **2** | **0** |

Las repeticiones no aumentan el total único. Los casos oscuros que se omitieron en QA-B se completaron en el iPhone 16 Pro; la galería que devolvió una imagen clara en QA-B pasó en 16 Pro. Los dos únicos fallos que quedan son las auditorías `.all` clara y oscura.

## Evidencia y hallazgos

- El gate UI de los shards 1–3 ejecutó 118 IDs únicos: 113 aprobados, 3 fallidos y 2 omitidos. El shard 0 de esa planificación no llegó a ejecutar pruebas porque el `.xctestplan` temporal no incluía el target Snapshot. Se corrigió el plan temporal; Xcode siguió generando un `xctestrun` con solo el target UI, por lo que Snapshot se ejecutó con `xcodebuild test -only-testing:NidoSnapshotTests`.
- La primera ejecución Snapshot sin firma pasó 38/43. Cinco pruebas de `AccountDeletionSessionFenceTests` fallaron al guardar la sesión sintética. Un diagnóstico XCTest temporal, después retirado de la copia de trabajo, registró `SecItemUpdate = -34018` y `SecItemAdd = -34018` (`errSecMissingEntitlement`). El binario sin firma era ad-hoc solo en el linker (`CODE_SIGNING_ALLOWED=NO`). Al ejecutar con `CODE_SIGN_IDENTITY=-` y firma ad hoc de simulador, las cinco regresiones pasaron; el target Snapshot completo pasó **43/43**, sin modificar producción. Resultado: `/tmp/nido-snapshot-signed-all-2026-10-17.xcresult`. Diagnóstico inicial: `/tmp/nido-snapshot-retry-2026-10-17.xcresult`; verificación de las siete pruebas de la clase: `/tmp/nido-snapshot-keychain-signed-recheck-2026-10-17.xcresult`.
- Las tres pruebas `testFreshInstallationCreatesAnIndependentHouseholdAndOnlySeesItsOwnBaby`, `testRealBackendCaregiverPermissionsAndRevocation` y `testRealBackendHistoryLoadsAndDisplaysAnEntryBeyondTheFirstFiveHundred` pasaron contra un API HTTP de loopback y un PostgreSQL desechable: `/tmp/nido-fullgate-shard-0-api-retry-2026-10-17.xcresult`. El seeder creó cinco sesiones Nido sintéticas con tokens aleatorios en memoria/archivo temporal privado; validó aislamiento de permisos y limpieza. Esto **no** simula ni afirma una autenticación real de Sign in with Apple. No se dispuso de tokens Apple reales.
- Las dos pruebas oscuras que QA-B había omitido (`testTodayDarkScrolledHeadingAtAccessibilityXXXL` y `testTodayVisibleHitRegionsPassInDarkAppearance`) pasaron en el 16 Pro, 2/2: `/tmp/nido-darkcases-16pro-2026-10-17.xcresult`. La captura de texto grande tras desplazar muestra el área de estado despejada y sin el avatar M superpuesto: `screenshots/today-dark-xxxl-scrolled-no-avatar.png`.
- La prueba de galería pasó en el 16 Pro: `/tmp/nido-native-visual-16pro-recheck-2026-10-17.xcresult`. En QA-B, el caso oscuro produjo una imagen de apariencia clara y omitió las comprobaciones oscuras; no se ha determinado si su origen es el entorno o la aplicación. Se conserva esa imagen de evidencia en `screenshots/qa-b-dark-request-rendered-light.png`. No se atribuye ese fallo al producto.
- Las dos auditorías nativas se repitieron después de habilitar firma y confirmar la apariencia en el 16 Pro. Ambas siguen fallando sin filtrar issues ni añadir expected failures: `/tmp/nido-final-audit-signed-2026-10-17.xcresult`. El inspector asigna `Contrast failed` a un nodo SwiftUI y la captura identifica el botón «Ver todo». Un análisis de píxeles del recorte nativo de ese botón midió contraste alto en los dos temas (18,01:1 oscuro y 11,40:1 claro), pero esa medición no invalida el finding del auditor ni se usa para declararlo falso positivo. Capturas: `screenshots/audit-dark-failure.png` y `screenshots/audit-light-failure.png`.
- Los casos intermitentes `AccountDeletionAuthorizationUITests/testAccessibilitySizeKeepsAuthorizationCopyAndActionsReachable` y `HistoryFitnessUITests/testCalendarMonthHeadingStaysPinnedWhileScrollingAcrossMonths` se repitieron dos veces cada uno, secuencialmente en el mismo simulador/binario; las cuatro repeticiones pasaron. Resultados: `/tmp/nido-intermittent-repeat-{1,2}-2026-10-17.xcresult`.
- Los widgets opt-in se ejecutaron en SpringBoard y pasaron; los logs contienen avisos `kAXErrorServerNotFound` pese al resultado verde. Reducir movimiento se activó en el 16 Pro para las pruebas correspondientes. La prueba `testSelectedEntrySettlesImmediatelyWithReduceMotion` pasó dentro del target Snapshot.

Los logs de shards y la evidencia de capturas, sanitizados para retirar valores de entorno, están en `logs/`. No se guardan tokens, contraseñas ni URLs con credenciales. Los resultados `.xcresult` permanecen en `/tmp` para evitar copiar bundles grandes al repositorio.

## Reproducción

La copia sincronizada del proyecto utilizada fue `/tmp/nido-native-validation`; DerivedData `/tmp/nido-baby-care-regression-derived`; paquetes Swift `/tmp/nido-premium-derived/SourcePackages`. Para builds y ejecuciones se mantuvieron `-clonedSourcePackagesDirPath /tmp/nido-premium-derived/SourcePackages -disableAutomaticPackageResolution -skipPackageUpdates`. Se usó firma ad hoc solo para simulador en el cierre Snapshot (`CODE_SIGN_IDENTITY=-`); no se usaron credenciales Apple ni se cambió la firma de producción.

La activación opt-in del plan temporal usó estas variables sin valores secretos:

- `NIDO_RUN_NATIVE_ACCESSIBILITY_AUDIT=1`
- `NIDO_AUDIT_SCROLL_ACTIVITY_CAPTION=1`
- `NIDO_WIDGET_GALLERY_TEST=1`
- `TEST_RUNNER_NIDO_WIDGET_GALLERY_TEST=1`
- `TEST_RUNNER_NIDO_WIDGET_APPEARANCE_TEST=1`

La integración HTTP requiere `DATABASE_URL`, `NIDO_UI_TEST_API_BASE_URL`, `NIDO_UI_TEST_RUN_ID` y `NIDO_LOCAL_API_UI_ENV_FILE`. El helper genera los valores de sesión para `NIDO_UI_TEST_OWNER_A_TOKEN`, `NIDO_UI_TEST_OWNER_B_TOKEN`, `NIDO_UI_TEST_PERMISSIONS_OWNER_TOKEN`, `NIDO_UI_TEST_PERMISSIONS_CAREGIVER_TOKEN` y `NIDO_UI_TEST_HISTORY_TOKEN`; los guarda con permisos privados y el harness los elimina al cerrar. El archivo del plan de opt-in es `opt-in.xctestplan`.

Se preservaron los dos simuladores de usuario existentes. Los dos simuladores QA creados para el gate ya se eliminaron. En el 16 Pro se restauraron Reducir movimiento desactivado y apariencia clara; el API local y PostgreSQL desechable también quedaron cerrados.


## Cambios de interfaz y contratos relacionados

- **Historia / calendario (TDD):** la reproducción roja conservada en `logs/history-calendar-red.log` mostraba que el toque automatizado del día no cerraba «Elegir día» ni dejaba seleccionado el día esperado. Se añadió un selector accesible con fecha ISO y la aserción de cierre/selección; el `contentShape(Rectangle())` de la celda amplió su región de toque. El test enfocado pasó 1/1 en `/tmp/nido-history-after-content-shape-2026-10-17.xcresult`; luego los tres flujos HTTP sintéticos pasaron 3/3. No se relajaron expectativas de paginación.
- **Hoy / textos y avatar:** el título accesible y visible de la actividad diaria ahora coincide («Actividad del día»); la captura/árbol anterior está en el log opt-in original de accesibilidad, y los rechecks mantuvieron la captura sin fallar por texto recortado. La prueba visual antes/después del avatar conserva `screenshots/avatar-m-over-status-before-fix.png`, `screenshots/today-light-scrolled-no-avatar.png` y `screenshots/today-dark-xxxl-scrolled-no-avatar.png`. Al salir el encabezado del viewport, el avatar ya no se pinta encima de los símbolos de estado.
- **API / carrera de permisos:** los contratos HTTP tuvieron rojo y verde con respuesta de autorización y revocación; evidencia en `api-race-red.log`, `api-race-green.log` y `api-race-contracts.log`. La validación de despliegue y el rollback backend están en `docs/backend-baby-care-deployment-2026-10-17/` y `docs/backend-baby-care-deployment-preflight-2026-10-17.md`.
- **Contraste «Ver todo»:** el cálculo desde los recortes sRGB y sus límites están documentados en [contrast-measurement.md](contrast-measurement.md), con los PNG nativos asociados. El cálculo no resuelve el fallo persistente de la inspección automática `.all`.

No se creó ningún commit. El checkout compartido ya estaba sucio y varios agentes trabajaron en él. El límite de rollback para los cambios de interfaz de este turno es revertir únicamente sus hunks específicos junto con las pruebas asociadas, conservando los demás cambios y assets existentes; no se debe restaurar el checkout completo. Los pasos de reversión del backend desplegado están en los documentos enlazados arriba.
