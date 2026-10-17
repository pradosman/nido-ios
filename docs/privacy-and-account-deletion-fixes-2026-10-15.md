# Correcciones de privacidad y eliminación de cuentas de Nido

Fecha: 15 de octubre de 2026. Estado: correcciones verificadas en la cohorte local de esta tarea; integración final de publicación pendiente. No se ha publicado ni desplegado esta versión.

**Seguimiento posterior de sesión:** la conservación incondicional del aviso descrita más abajo pertenece a la primera cohorte de privacidad. Store la ha sustituido por un estado explícito de motivo de reautenticación: conserva la explicación al preparar Apple y la limpia cuando el acceso termina correctamente. Dos fallos adicionales se reprodujeron antes de esa corrección; los resultados enfocados posteriores son 4/4 y 7/7, sin omisiones. La evidencia y la validación conjunta están en [la auditoría actualizada](app-store-launch-audit-2026-10-15.md#seguimiento-coordinado-de-los-dos-avisos-de-sesión). No sustituir el Store integrado por la copia anterior de privacidad.

## Alcance

Se conserva la corrección previa del manifiesto de privacidad y el flujo previo de autorización y revocación Apple. Esta unidad añade acceso a privacidad y soporte desde Ajustes, páginas públicas preparadas para el servidor, retirada de la atribución personal al eliminar un integrante y conservación del aviso de cuenta durante la preparación de un nuevo inicio de sesión Apple.

El usuario confirmó como datos públicos del responsable/editor **David Prados Mancilla** y **pradosman@gmail.com**. No son credenciales de autenticación. Las claves privadas Apple siguen siendo exclusivamente configuración protegida del servidor.

## Evidencia rojo y verde

| Corrección | Rojo antes del cambio de producción | Verde enfocado |
|---|---|---|
| Enlaces en Ajustes | `PrivacyLinksUITests.testSettingsOffersReachablePrivacyAndSupportLinks` falló con «Falta el enlace Política de privacidad». Log `/tmp/nido-privacy-links-red-signed-20261015.log`, resultado `.xcresult` con el mismo prefijo. | 1/1, `/tmp/nido-privacy-links-green-20261015.{log,xcresult}`. Comprueba existencia, nombre, accesibilidad al pulsar y altura mínima de ambos enlaces; no afirma que las páginas estén desplegadas. |
| Aviso de cuenta | La prueba `testPreparingAppleSignInPreservesAccountRevocationNotice`, recuperada de una copia de trabajo anterior e incorporada al canónico antes de la corrección, falló: `notice` era `nil` en lugar del aviso. Evidencia ejecutada en `/tmp/nido-privacy-full-ui-20261015.log`; esa primera suite se interrumpió tras reproducir el fallo. | Eliminando únicamente el borrado del aviso al obtener un nuevo desafío, pasan los cuatro casos de `AccountDeletionSessionFenceTests` y el caso de enlaces: 5/5, `/tmp/nido-privacy-notice-green-20261015.{log,xcresult}`. |
| Atribución del integrante eliminado | Se ejecutaron los seis contratos con la ruta sin modificar: cuatro aprobaron y los dos nuevos fallaron, porque `entry_authors` conservaba una fila cuando se esperaba cero. El rojo está conservado en la salida capturada de la ejecución, no en un archivo independiente. Ruta previa SHA-256 `f432baa88b70e12c0607248852c45546322f84f1371a81e714c34247befc162a`. | 6/6 en `/tmp/nido-member-attribution-green.log`: incluye membresía activa y retirada, conserva las actividades y los autores ajenos. El caso de borrado del propietario amplía la cobertura de cascadas como prueba de regresión, no como TDD nuevo. |
| POST que terminaba después del borrado | El contrato con cuerpo demorado recibió 201 en vez de 401 y observó que el nombre e identificador eliminados reaparecían en `entry_authors`. Salida roja capturada antes de modificar producción. | El contrato pasa 1/1 y los seis contratos de borrado siguen verdes; también pasan en la suite final de 77. POST y la rama de integrante de DELETE bloquean la misma fila de usuario dentro de sus transacciones antes de escribir o limpiar. Si la cuenta ya no existe, POST responde 401 y no escribe. |
| Páginas legales | Antes de crear las rutas, el contrato recibió 404 en vez de 503/200. Un segundo rojo mostró que el enlace de correo de la política no codificaba `+`, `?` y `&`. | 5/5. Evidencia persistida en `privacy-pages-contract-red.log`, `privacy-pages-mailto-red.log` y `privacy-pages-contract-green.log`, en este directorio. |
| Contactos en Compose | La prueba de configuración detectó que los valores predeterminados no eran los datos públicos aprobados. | 2/2: contactos transmitidos solo al servicio `nido`, valores predeterminados aprobados y overrides sintéticos. No crea servicios ni imprime claves. |

El primer intento de interfaz sin firma falló al abrir la app, antes de llegar al requisito. Ese intento no se utiliza como rojo del comportamiento. Se repitió con firma ad hoc del simulador y se obtuvo el fallo correcto por ausencia del enlace.

## Comportamiento de las páginas

- `/api/nido/legal/privacy`: política en español con responsable y contacto, inventario básico de datos, Apple, acceso familiar, exportación y alcance del borrado.
- `/api/nido/legal/support`: contacto de soporte y enlace a privacidad.
- Ambas rutas son públicas, devuelven HTML UTF-8 y `Cache-Control: no-store`. Si un proceso se inicia sin configuración válida, devuelven 503 en lugar de publicar un responsable ficticio.
- Compose aporta los dos datos públicos aprobados como valores predeterminados; `.env.example` los documenta. No se añadieron valores de claves privadas.
- Con el servidor standalone generado se comprobaron por HTTP ambas rutas, con 200 y el nombre y correo públicos aprobados. Fue una ejecución local, con el servidor detenido después; no se envió ningún correo.

El texto no fija una retención de respaldos ni una lista de encargados que aún no se han verificado. La revisión operativa de esos puntos y la ficha App Privacy siguen pendientes. Disponer de HTML no equivale a haber cerrado todas las obligaciones de privacidad.

## Suites y compilación

- Swift: 148/148 pruebas en 20 suites, `/tmp/nido-privacy-swift-20261015.log`.
- Backend final: **77/77, cero fallos y cero omisiones**, `/tmp/nido-privacy-backend-full-final-20261015.log`. Incluye cinco contratos con PostgreSQL 17.10 propio y efímero; los restantes emplean los adaptadores definidos por cada prueba, incluido PGlite. Incluye la prueba de concurrencia y los dos contratos de Compose.
- `npm run build`: completado después de la corrección de concurrencia en `/tmp/nido-privacy-backend-build-final-20261015.log`; genera el servidor standalone y el ejecutor de migraciones.
- ESLint de las diez unidades backend modificadas o nuevas: salida 0, sin diagnósticos, `/tmp/nido-privacy-eslint-20261015.log`.
- Esquema iOS completo de esta cohorte: **101 casos, 93 aprobados, cero fallos y ocho omitidos**, salida 0 y resultado `Passed` confirmado con `xcresulttool`: `/tmp/nido-privacy-full-green-20261015.{log,xcresult}`. Incluye 27 casos del target de pruebas alojadas/snapshots (26 aprobados y uno omitido) y 74 de UI (67 aprobados y siete omitidos), en el iPhone 16 Pro simulado autorizado. La compilación Debug y la ejecución de la app se completaron en ese escenario.

Las omisiones no se consideran aprobadas:

| Caso | Motivo |
|---|---|
| `CircularTimelineSnapshotTests.testSelectedEntrySettlesImmediatelyWithReduceMotion` | Requiere activar Reducir movimiento en el simulador. |
| `NidoUITests.testFreshInstallationCreatesAnIndependentHouseholdAndOnlySeesItsOwnBaby` | Falta la sesión provisionada `NIDO_UI_TEST_OWNER_A_TOKEN`. |
| `NidoUITests.testRealBackendCaregiverPermissionsAndRevocation` | Falta `NIDO_UI_TEST_PERMISSIONS_OWNER_TOKEN`. |
| `NidoUITests.testRealBackendHistoryLoadsAndDisplaysAnEntryBeyondTheFirstFiveHundred` | Falta `NIDO_UI_TEST_HISTORY_TOKEN`. |
| `NidoUITests.testTodayUnfilteredAccessibilityAuditDiagnosticInDarkAppearance` | Diagnóstico de activación explícita con `NIDO_RUN_NATIVE_ACCESSIBILITY_AUDIT=1`; no se ejecutó en esta ventana. |
| `NidoUITests.testTodayUnfilteredAccessibilityAuditDiagnosticInLightAppearance` | Mismo requisito de activación explícita; no se ejecutó. |
| `NidoWidgetUITests.testSpringBoardGalleryAddsSmallNidoWidget` | Requiere la opción de automatización de galería `NIDO_WIDGET_GALLERY_TEST`. |
| `NidoWidgetUITests.testSpringBoardSmallNidoWidgetTintedAndClearAppearances` | Requiere `TEST_RUNNER_NIDO_WIDGET_APPEARANCE_TEST=1`. |

El turno del simulador se liberó al terminar esta ejecución, sin iniciar otra prueba o compilación. Los otros chats coordinan los escenarios pendientes y la unión final; este resultado no se extrapola a fuentes modificadas después.

## Fuentes usadas para las comprobaciones

Los cambios se aplican al repositorio canónico. La comprobación nativa usa `/tmp/nido-privacy-fixes-20261015` para evitar lecturas bloqueadas por iCloud; se compararon los Swift y metadatos legibles al preparar la cohorte. `NidoRegistrationIntents.swift` sigue sin poder leerse en el original y se conserva de la copia recuperada. Otros chats tienen después una cohorte más reciente para avisos de sesión y reautenticación: no debe sustituirse su `Store`, sus pruebas UI o su harness por los de esta copia. Se integran únicamente los cuatro enlaces/identificadores de Ajustes y el nuevo caso de interfaz, preservando la unión semántica de las correcciones de sesión.

Huellas de la cohorte nativa ejecutada:

| Archivo relativo a la copia iOS | SHA-256 |
|---|---|
| `Nido/Features/Settings/SettingsView.swift` | `1898dc93898ebe799b870d24b026f11fb12e576c78d9955c446324f02d7d291d` |
| `NidoUITests/PrivacyLinksUITests.swift` | `369e7eeb6be9948e54c687a616e5be4eac44f4c29a8801c04a810ab3f0451866` |
| `Nido/App/NidoStore.swift` | `5726d403eca38c61e02130f0ef7dc9a0206508410116f1ad0efcc3544c6fd391` |
| `NidoSnapshotTests/AccountDeletionSessionFenceTests.swift` | `2361b7f5448daa02ea92964541b865954b25bd6114f5975d752bd9f592f9836d` |

La comprobación backend usa `/tmp/nido-privacy-backend-final-20261015`. Conserva las rutas y pruebas modificadas con contenido idéntico al canónico y restaura dependencias no descargadas de copias anteriores. El esquema y el diario recuperados incluyen la migración de sueño activo que exige el código actual. El esquema recuperado con sueño activo y ese diario no coinciden con los blobs de HEAD `b96e17a`; no se afirma que la prueba certifique un checkout limpio ni se sobrescriben los archivos inaccesibles del usuario. Una cohorte final publicable debe reconciliar también esas dependencias y repetir su validación.

Huellas SHA-256 de esas dependencias recuperadas:

| Archivo relativo a la copia backend | SHA-256 |
|---|---|
| `db/schema.ts` | `e85e08ee7b0728c03721d8fb334a792c170ba671666531fc67b90b947ca7d86b` |
| `drizzle-pg/meta/_journal.json` | `707964ca6acdf60b5c03bb8e0a5161c8522c3508554beef4d8a96f5f94bed0c2` |
| `drizzle-pg/0002_massive_barracuda.sql` | `c9dd86db0ccdc3c920f6ff03285d6a7f03a4645cc87130c1019cf5c9b47f218e` |
| `drizzle-pg/meta/0002_snapshot.json` | `8986a24d1c7526eea9af466ea4c793e19390d8ce3dfd75489b44b45dda35a461` |

No se modificaron bases o servicios de producción. PostgreSQL y el servidor HTTP usados en estas comprobaciones pertenecen exclusivamente a esta tarea.

El contenedor efímero `nido-privacy-tdd-20261015` se detuvo y se eliminó al finalizar; los siete servicios Supabase ajenos se conservaron. Los servidores HTTP propios también se detuvieron. Los registros de `/tmp` son evidencia local temporal; este documento conserva resultados, alcance y huellas para la integración.

## Límite de reversión y pendientes

No se creó un commit propio: existen cambios previos compartidos en los mismos archivos y la integración final se está coordinando. No debe revertirse el archivo completo para deshacer una de estas correcciones.

Las unidades reversibles son:

1. Las cuatro líneas de enlaces en `SettingsView.swift` y `PrivacyLinksUITests.swift`.
2. La retirada de `notice = nil` en `prepareAppleSignIn` y la prueba incorporada a `AccountDeletionSessionFenceTests.swift`; conservar el resto de los cambios de sesión previos.
3. La limpieza de `entry_authors` y el bloqueo de usuario en la rama de integrante de `auth/account/route.ts`, el bloqueo de usuario antes del POST de `entries/route.ts`, los contratos de atribución y `account-deletion-race.contract.test.mjs`. Revertir estos bloques como una unidad para no reintroducir la carrera.
4. El servicio y las rutas `app/api/nido/legal`, sus pruebas y ayudante, los dos contactos de `.env.example`, los dos forwards de Compose y sus contratos/documentación.

Una revisión independiente del alcance no encontró problemas accionables. Comprobó la serialización entre creación y borrado, el escape de HTML/correo y la transmisión de los contactos al servicio correcto; no sustituye los resultados de las pruebas ni la revisión operativa pendiente.

Para los cambios de metadatos y documentación no aplica TDD unitario: lo sustituyen validación del plist, de la configuración Compose y revisión reproducible de enlaces y evidencia. Para los cambios de comportamiento se conserva el rojo previo y el verde correspondiente.

Siguen pendientes el despliegue y la comprobación de URLs públicas, la revocación con Apple real y sus secretos de equipo, la cohorte final común de los cuatro chats y las comprobaciones de publicación en App Store Connect. Este informe no declara Nido lista para enviar.
