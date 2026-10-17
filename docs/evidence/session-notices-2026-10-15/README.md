# Evidencia de los avisos de sesión

Comprobada el 15 de octubre de 2026 mediante `xcrun xcresulttool get test-results summary --path <bundle> --format json`.

| Bundle | Resultado | Total | Aprobadas | Fallidas | Omitidas |
|---|---|---:|---:|---:|---:|
| `/tmp/nido-auth-notice-semantic-green-20261015.xcresult` | Passed | 4 | 4 | 0 | 0 |
| `/tmp/nido-auth-notice-semantic-all7-20261015.xcresult` | Passed | 7 | 7 | 0 | 0 |
| `/tmp/nido-final-integrated-api-three-20261015.xcresult` | Passed | 3 | 3 | 0 | 0 |
| `~/.codex/recoveries/nido-20261015/final-integrated-16pro-20261015/final-16pro-suite.xcresult` | Passed | 104 | 97 | 0 | 7 |

Los cuatro casos enfocados están incluidos en los siete; no deben sumarse. Los tres casos API comprueban aislamiento familiar, permisos/revocación e historial con el servidor local provisionado; no prueban Apple real.

El log rojo se conserva junto a este archivo: `nido-auth-notice-semantic-red-20261015.log`. Fallos correctos antes de modificar producción: el acceso correcto conserva el aviso de revocación y la preparación de Apple pierde la explicación de credencial revocada. Resultado: 4 casos, 2 fallos. La copia coordinada reprodujo ambos en su suite de siete casos.

La cohorte integrada es `/tmp/nido-final-integrated-16pro-20261015`. Su manifiesto duradero está en `~/.codex/recoveries/nido-20261015/final-integrated-16pro-20261015/native-source-manifest.json`: 83 archivos inventariados, ninguna diferencia con los originales legibles y un original de iCloud inaccesible (`Nido/App/NidoRegistrationIntents.swift`). Esto no certifica un checkout limpio.

SHA-256 verificados de la cohorte y el canónico:

- Store: `da3a3baef2e3ddf98ae5e7082672cee4f067be22a7f63fc166df58e9516a1100`.
- AccountDeletionSessionFenceTests: `4e7ba487e1ea7bbf991ea4ba75f3ff45b9b5cff584dbddb556d0f0ba09f6c304`.
- SettingsView: `1898dc93898ebe799b870d24b026f11fb12e576c78d9955c446324f02d7d291d`.
- PrivacyLinksUITests: `369e7eeb6be9948e54c687a616e5be4eac44f4c29a8801c04a810ab3f0451866`.

La suite completa fue verificada directamente con `xcresulttool`, además del JSON del runner; el runner terminó con código 0. Reducir movimiento y los enlaces de privacidad pasan. Omisiones: API 3 (aprobadas por separado con credenciales), accesibilidad nativa optativa 2 y widgets de SpringBoard optativos 2. Las incidencias previas de accesibilidad siguen abiertas. El log es `final-16pro-xcodebuild.log` junto al bundle.

La repetición completa del servidor dio 77 aprobadas, cero fallos y cero omisiones, con PostgreSQL real activado. `backend-runner.log` y `backend-contracts.log` se conservan en ese mismo directorio duradero; el runner terminó con código 0 tras compilar, migrar y probar.

La lógica Swift se repitió desde la cohorte integrada con `swift test --package-path /tmp/nido-final-integrated-16pro-20261015 --scratch-path /tmp/nido-audit-core-derived-20261015`: 148 pruebas en 20 grupos aprobadas, código 0, compilación completada en 13,90 segundos. Evidencia: `core-audit.log` en el directorio duradero anterior. No utilizó el simulador ni el directorio de compilación de Store.

La auditoría mantiene los pendientes de distribución y las limitaciones de las fuentes recuperadas. No se ha desplegado ni enviado ninguna versión.
