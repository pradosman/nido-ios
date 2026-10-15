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

## Fuentes oficiales

- [Revocar tokens y autorizaciones](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens): requiere access/refresh token; HTTP 200 vacío también corresponde a un token ya invalidado.
- [Canjear y validar tokens](https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens): código de un solo uso, válido cinco minutos.
- [Eliminación de cuentas](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion): permite confirmar la identidad y exige revocar la autorización Apple.
- [Crear un client secret](https://developer.apple.com/documentation/accountorganizationaldatasharing/creating-a-client-secret): claims y firma del JWT; el endpoint de Sign in with Apple remite a esta documentación.
