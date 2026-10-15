# Revocación Apple al borrar una cuenta

El backend exige una autorización Apple reciente antes de borrar datos. El cliente envía `DELETE /api/nido/auth/account`, su bearer Nido vigente y JSON con `challengeID`, `identityToken` y `authorizationCode`. La prueba procede de una autorización nativa nueva con el nonce del endpoint de desafío existente; no se debe completar el inicio de sesión Nido ni sustituir la sesión durante esta confirmación.

Se valida la firma, audiencia, antigüedad y nonce del identity token; su subject debe pertenecer al usuario de la sesión. El desafío se consume una sola vez en PostgreSQL, también frente a repetición de un desafío usado para iniciar sesión. El servidor canjea el código y verifica el identity token devuelto por Apple con el mismo nonce/subject antes de revocar el refresh token (o access token cuando no hay refresh token). Solo después de HTTP 200 de Apple ejecuta el borrado ya existente de cuenta, familia y sesiones según el rol. La autorización Apple revocada pertenece exclusivamente al usuario que solicita el borrado.

Las cuentas anteriores no tienen un token Apple revocable guardado. La autorización reciente permite obtenerlo sin almacenar refresh tokens de forma permanente. Un identity token, el identificador Apple y el bearer Nido no son sustitutos válidos.

## Configuración y despliegue

El servidor necesita `NIDO_APPLE_AUDIENCE` (App ID nativo), `NIDO_AUTH_BUCKET_SECRET` y estos secretos del equipo propietario:

- `NIDO_APPLE_TEAM_ID`.
- `NIDO_APPLE_KEY_ID`, de una clave habilitada para Sign in with Apple y la app correspondiente.
- `NIDO_APPLE_PRIVATE_KEY`, contenido PKCS#8 de la clave `.p8`, únicamente en el gestor de secretos del servidor.

El client secret se firma con ES256 y dura cinco minutos. Ni claves, códigos, tokens ni respuestas privadas de Apple se propagan a errores públicos. Las solicitudes externas tienen un límite de diez segundos y no siguen redirecciones. No se incorpora ninguna credencial al repositorio o al binario iOS.

`compose.vps.yml` exige las tres variables nuevas con `${VAR:?}` y solo las transmite al servicio `nido`; faltas o vacías impiden resolver la configuración antes de crear servicios. No se reutiliza la clave para PostgreSQL ni para migraciones. Se mantiene `NIDO_APPLE_AUDIENCE` como único App ID/client ID. `.env.example` contiene exclusivamente campos vacíos: sirve de inventario, no de configuración ejecutable.

Introducir el contenido PKCS#8 completo, incluidas cabecera, pie y saltos de línea, en la variable protegida de Dokploy. Si una interfaz obliga a utilizar un archivo `.env` local, encerrar el PEM multilinea completo en comillas simples conforme a la sintaxis dotenv de Compose y excluir ese archivo de Git. No ejecutar ni compartir `docker compose config` sin filtrar, porque imprime los secretos resueltos. La comprobación segura `node tests/support/validate-apple-compose.mjs` usa una clave efímera sintética, captura la salida en memoria y solo informa del resultado.

Los clientes antiguos que no envían la prueba ya no pueden completar el borrado: reciben 400 si el servidor está configurado. Debe coordinarse la publicación con el flujo nativo actualizado y la configuración del servidor. La falta de configuración devuelve 503 y nunca se interpreta como borrado completado.

## Errores y reintentos

| Resultado | Respuesta | Estado local |
| --- | --- | --- |
| Bearer inválido o prueba/desafío inválido, caducado o usado | 401 | Sin borrado |
| Falta algún campo de prueba | 400 | Sin borrado |
| Subject diferente al usuario autenticado | 403 | Sin revocación ni borrado |
| Faltan secretos del servidor | 503 | Sin revocación ni borrado |
| Apple falla, agota tiempo o devuelve token inválido | 502 | Sin borrado; obtener prueba nueva para reintentar |
| Apple revoca pero falla el borrado en BD | 500 | Cuenta y sesión Nido conservadas por rollback; revocación Apple ya efectuada; obtener autorización nueva y reintentar |
| Revocación y borrado completados | 200, `{ "deleted": true }` | El cliente puede limpiar credenciales locales |

No existe una cola de revocación ni una afirmación de atomicidad entre Apple y PostgreSQL. No se mantiene una transacción de BD abierta durante las llamadas a Apple. Si falla la BD tras revocar, el error conserva una vía explícita de reintento con nueva autorización; el contrato no responde con éxito parcial ni con un estado pendiente ficticio. La repetición concurrente del mismo desafío solo realiza una llamada al proveedor.

## Verificación

Los contratos HTTP nuevos se escribieron antes del código de producción. La ejecución roja `/tmp/nido-revocation-http-red-20261015.log` registró cinco fallos porque todavía no existía la fábrica `createAccountDeletionHandler`; el servicio de tokens también tuvo rojo por módulo ausente en `/tmp/nido-revocation-token-red-20261015.log`. No se presentan como una reproducción previa de un fallo ya existente del token endpoint.

La primera ejecución verde enfocada válida es `/tmp/nido-revocation-focused-green2-20261015.log`: 19 casos aprobados, incluidos los contratos previos de borrado sin cambiar sus expectativas. Sus fixtures ahora aportan una prueba válida y un proveedor Apple simulado explícito. La primera tentativa de verde tuvo un fallo de preparación SQL (dos órdenes en un prepared statement); se corrigió separando la función y el trigger.

Los dos casos adicionales de desafío caducado/consumido y concurrencia se añadieron después de implementar: son pruebas de regresión. `/tmp/nido-revocation-retry-regression-20261015.log` verifica los siete contratos HTTP. Las pruebas del servicio generan una clave ES256 efímera y verifican firma, claims y formularios reales del client secret contra un transporte simulado.

La compilación `npm test` terminó correctamente (`/tmp/nido-revocation-full-20261015.log`). La suite completa posterior, con PostgreSQL 17.10 efímero propio y sus migraciones, aprobó **65/65**, sin omisiones ni fallos (`/tmp/nido-revocation-full-pg-20261015.log`). De forma adicional se ejecutaron los once contratos de borrado mediante `postgres-js` real: **11/11**, sin omisiones (`/tmp/nido-revocation-delete-real-pg2-20261015.log`). Para este último escenario se sustituyó temporalmente solo el adaptador de pruebas de la copia aislada y se restauró después; las fechas de los parámetros SQL del fixture se codificaron como ISO tras un intento inicial fallido del adaptador. Ese adaptador no forma parte del cambio. El contenedor propio se eliminó al finalizar.

La validación local con proveedor simulado no demuestra aceptación por Apple. El cierre real requiere secretos del equipo, App ID correcto, autorización Apple nativa firmada y una cuenta de pruebas; no se ha realizado una revocación real ni un despliegue. El límite de rollback es el servicio, la integración DELETE y sus contratos/fixtures en una unidad; al revertir debe revisarse también el contrato del cliente nativo.

El forward obligatorio de credenciales tuvo rojo separado antes de editar Compose: `/tmp/nido-revocation-compose-red-20261015.log` (dos contratos fallidos: forward ausente y ejemplo inexistente) y `/tmp/nido-revocation-compose-config-red-20261015.log` (Compose resolvía con TEAM_ID ausente). Verde enfocado: `/tmp/nido-revocation-compose-green-20261015.log`, ocho casos. El escenario `/tmp/nido-revocation-compose-config-green-20261015.log` confirma seis guardas de variables ausentes/vacías y configuración válida con PKCS#8 multilinea exacto, sin mostrar secretos ni crear servicios. En documentación y plantilla no aplica TDD unitario; sustituyen esa validación el análisis de configuración y la revisión de que los valores de ejemplo están vacíos. El rollback de esta configuración comprende únicamente los tres forwards, la plantilla, su excepción Git, contratos y documentación; no modifica valores del servidor.

Tras el cambio de configuración, `npm test` volvió a compilar y ejecutó 67 casos: 62 aprobados, cero fallos y cinco pruebas de PostgreSQL externo omitidas al no levantar servicios en esta tarea (`/tmp/nido-revocation-compose-full-20261015.log`). Esas cinco pruebas ya habían pasado en la suite de 65/65 con PostgreSQL real anterior; no se presenta la nueva ejecución como 67/67 ni como una segunda comprobación del servidor.

La ejecución final posterior volvió a compilar y ejecutó **67/67, cero fallos y cero omisiones** con un PostgreSQL 17.10 efímero propio, recién migrado: `/tmp/nido-revocation-compose-full-pg-final-20261015.log`. Incluye los contratos nuevos de configuración y los cinco de PostgreSQL real. El contenedor propio se eliminó al terminar; los servicios ajenos se conservaron. No hubo cambios de código después de esta ejecución, únicamente esta evidencia documental.

## Fuentes oficiales

- [Revocar tokens y autorizaciones](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens): requiere access/refresh token; HTTP 200 vacío también corresponde a un token ya invalidado.
- [Canjear y validar tokens](https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens): código de un solo uso, válido cinco minutos.
- [Eliminación de cuentas](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion): permite confirmar la identidad y exige revocar la autorización Apple.
- [Crear un client secret](https://developer.apple.com/documentation/accountorganizationaldatasharing/creating-a-client-secret): claims y firma del JWT; el endpoint de Sign in with Apple remite a esta documentación.
