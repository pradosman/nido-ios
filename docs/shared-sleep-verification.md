# Sueño en curso compartido entre familiares

El inicio del sueño se guardaba únicamente en el iPhone que lo iniciaba. El servidor recibía el intervalo al terminar. La corrección guarda también el estado activo por hogar y lo consulta cada cinco segundos mientras la aplicación está activa.

## Contrato y funcionamiento

- `GET /api/nido/sleep` devuelve `{activeSleepStartedAt: number | null}` en milisegundos Unix.
- `PUT /api/nido/sleep` recibe `startedAt` y `expectedStartedAt`, ambos obligatorios y anulables. Solo modifica el estado esperado; un conflicto devuelve el estado actual para reconciliarlo.
- La carga familiar de `/api/nido` incluye `activeSleepStartedAt`.
- El inicio, las correcciones y el final pendientes se conservan localmente para reintentarlos. El cierre compartido espera a que el intervalo terminado se haya subido.
- Las respuestas antiguas deben respetar los cambios locales y el cierre de sesión.

## Evidencia

| Comprobación | Resultado |
| --- | --- |
| Rojo del cliente HTTP | Las pruebas no compilan porque `NidoAPI` todavía no tiene `loadSleep` ni `syncSleep`. |
| Verde del cliente HTTP | Dos pruebas pasan: milisegundos, campos nulos explícitos y reconciliación del conflicto 409. |
| Rojo de las correcciones posteriores del servicio | Se reprodujeron fallos de expectativa CAS tras corregir offline, lectura obsoleta tras limpiar la sesión o iniciar otro sueño, e inicio HTTP suspendido seguido de final que resucitaba el sueño. |
| Verde del servicio y suite Swift completa | 33 pruebas enfocadas pasan; 136 pruebas en 16 suites pasan en la copia final. Se comprobaron coincidencias entre las fuentes cambiadas y la copia ejecutada. |
| Rojo HTTP del servidor | La carga devuelve `undefined` en `activeSleepStartedAt`; el contrato espera `null`. |
| Verde del servidor | Dos pruebas pasan: contrato HTTP sobre PGlite y metadatos Drizzle. Incluyen dos familiares, otro hogar, autenticación, inicio/corrección/final, idempotencia y cierre obsoleto. |
| Compilación del servidor afectado | Pasan esbuild para las dos rutas, ESLint para los archivos afectados y `npm run build:migrate`. |
| Suite global del servidor en clon limpio | `npm test` pasa, incluido build Vinext y migración: 39 pruebas aprobadas, cero fallos y 5 omitidas por requerir PostgreSQL real. |
| Rojo de interfaz | La aplicación compila, pero el sueño remoto no aparece tras 12 segundos con la pantalla abierta. |
| Verde de interfaz enfocado | `testRemoteFamilySleepBecomesVisibleWhileTodayRemainsOpen` pasa en iPhone 17 Pro: aparece el inicio remoto y desaparece al terminar, sin refresco manual. |
| Primera suite completa de interfaz | 59 casos: 50 pasan, 7 omitidos y 2 fallan. El polling añadía reintentos POST de entradas pendientes (3 intentos frente a 2 esperados). Se retiró esa subida del polling del sueño antes de repetir las pruebas; las expectativas permanecen intactas. |
| Verde enfocado tras corregir el polling | Pasan los tres casos: sueño remoto, registro pendiente al reconectar y registro aceptado antes de un fallo de carga posterior. Cero fallos u omisiones. |
| Suite completa final de interfaz | iPhone 17 Pro, iOS 26.5: 59 casos, 52 aprobados, 7 omitidos y cero fallos. La aplicación compila y ejecuta el escenario real con HTTP contra el servidor de pruebas. |

La repetición enfocada también detectó que el servidor de pruebas devolvía éxito para la nueva ruta de sueño aunque simulase estar sin conexión. Se corrigió esa ruta del fixture. Además, el éxito de la consulta ligera ya no borra el indicador de error de sincronización del historial; ese indicador solo se limpia tras una carga familiar completa correcta.

Resultado final de Xcode: `/Users/pradosman/Library/Developer/Xcode/DerivedData/Nido-hgacgflpnraxswecivfmehpywjon/Logs/Test/Test-Nido-2026.10.15_01-47-50-+0200.xcresult`. La nota Markdown se revisó contrastando resultados, comandos y rutas; no aplica TDD unitario a este documento.

Las primeras pruebas nuevas de `RegistrationMutationService` se añadieron después de implementar esa parte: son **pruebas de regresión**, no evidencia de TDD. Las reproducciones rojas posteriores de la revisión se indican arriba. No se presenta este trabajo como cumplimiento íntegro del ciclo TDD obligatorio.

Comandos para repetir las verificaciones cuando el proyecto esté descargado:

```sh
swift test --package-path ios/Nido --filter RegistrationMutationServiceTests
swift test --package-path ios/Nido
node --experimental-strip-types --test tests/sleep.contract.test.mjs tests/drizzle-metadata.test.mjs
npm test
xcodebuild test -project ios/Nido/Nido.xcodeproj -scheme Nido \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NidoUITests CODE_SIGNING_ALLOWED=NO
```

## Entorno y entrega

Hay archivos de trabajo, dependencias y objetos Git marcados `dataless` por iCloud que bloquean las lecturas. Las comprobaciones usan copias temporales locales; las dependencias del servidor se instalaron de nuevo fuera del directorio de iCloud. Esto no sustituye una verificación de despliegue.

El intento inicial de build global en una copia incompleta falló cargando la configuración de Vinext (`config must export or return an object`); otra selección encontró archivos ausentes. Esos intentos no prueban una regresión del repositorio ni cuentan como verificaciones verdes.

Después se clonó el remoto en `/tmp/nido-clean-backend-check` y se superpusieron únicamente los ocho archivos de esta corrección del servidor. Allí `npm test` pasó completo. El commit remoto es `b6a8f58bfcf99c0029e5698652e2dc25f29cf1c7` y el local `97c6efc92a63543ddb1f6412b12ed344662847f2`: no es una copia exacta de todo el checkout local. Se verificó que la base indexada de `app`, `db`, `tests`, `drizzle-pg`, paquetes y configuración Vite coincide entre ambos. Eso no permite descartar modificaciones locales previas sin indexar en archivos que iCloud no deja leer.

La entrega requiere desplegar primero `drizzle-pg/0002_massive_barracuda.sql` y el servidor, y después la aplicación iOS. La migración, el journal y el snapshot se revisaron conjuntamente. La corrección no se ha publicado en producción.

## Límite de reversión

Una única unidad de comportamiento comprende el estado activo del hogar, su migración, la ruta HTTP, el cliente y servicio Swift, la consulta periódica, y sus pruebas. No se ha creado un commit: Git no permite comprobar el estado de trabajo en este entorno. Al revertir, retirar conjuntamente esa unidad; conservar las entradas de sueño ya terminadas y evitar borrar cambios ajenos. La columna anulable añadida puede permanecer durante una reversión del código.

Los archivos de esa unidad son:

- Servidor: `db/schema.ts`, `app/api/nido/route.ts` y `app/api/nido/sleep/route.ts`.
- Migración: `drizzle-pg/0002_massive_barracuda.sql`, `drizzle-pg/meta/0002_snapshot.json` y la entrada 0002 de `drizzle-pg/meta/_journal.json`.
- Cliente: `ios/Nido/Nido/Core/NidoAPI.swift`, `ios/Nido/Nido/Core/RegistrationMutationService.swift`, y `Nido/App/NidoStore.swift`, `NidoApp.swift` y `NidoRegistrationIntents.swift` dentro de `ios/Nido`.
- Pruebas: `tests/sleep.contract.test.mjs`, la ruta añadida a `tests/support/nido-route-harness.mjs`, y las ampliaciones de `NidoAPICharacterizationTests.swift`, `RegistrationMutationServiceTests.swift`, `NidoUITests.swift` y `OfflineSyncFixtureServer.swift`.
