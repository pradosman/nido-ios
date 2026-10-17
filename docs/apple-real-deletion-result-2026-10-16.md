# Borrado con Apple real — 16 de octubre de 2026

**Resultado: aprobado para una cuenta sin membresía en el entorno local aislado.** No se borraron datos del hogar de producción ni el Apple ID. Este resultado no equivale al envío o aprobación de App Review.

## Escenario y autorización

Se usó exclusivamente el simulador autorizado «Nido Motion iPhone 16 Pro», iOS 26.5, con la copia DEBUG aislada de Nido. El backend candidato escuchaba en `127.0.0.1:43127` y PostgreSQL efímero en loopback, puerto `51793`. Antes de consultar la base se comprobó la etiqueta de propiedad del contenedor; no se consultó la base de producción.

El usuario inició sesión en Ajustes y completó directamente los dos diálogos de contraseña de Apple: acceso inicial y autorización reciente para borrar. También confirmó expresamente, en el momento del borrado, la eliminación de la cuenta local y la revocación del acceso de Nido en Apple. No se le pidió compartir contraseñas ni códigos en el chat.

## Evidencia observada

1. Antes del acceso: cero usuarios, sesiones, cuidadores, hogares, perfiles, registros y atribuciones.
2. `POST /api/nido/auth/apple/challenge` → **201**.
3. Autenticación nativa real, sin proveedor simulado: `POST /api/nido/auth/apple/session` → **201**. La app mostró el alta de hogar. La base contenía un usuario y una sesión; cero cuidadores y hogares.
4. «Cuenta → Eliminar cuenta → Eliminar definitivamente» abrió la hoja de identidad reciente. Se obtuvo otro desafío **201** y se completó otra autorización nativa de Apple.
5. `DELETE /api/nido/auth/account` → **200**, en 2,5 segundos.
6. La app volvió a «El cuidado familiar, en privado» y «Continuar con Apple».
7. Después del borrado: cero usuarios, sesiones, cuidadores, hogares, perfiles, registros y atribuciones.

El registro local conserva métodos, rutas, estados y tiempos. No se guardaron tokens, códigos Apple ni valores de los desafíos en este informe.

## Alcance de la revocación

El manejador real espera la revocación antes de eliminar el usuario y devolver éxito. El revocador exige HTTP 200 del intercambio de código de Apple, verifica el `id_token` devuelto con sujeto y nonce, y exige HTTP 200 de `/auth/revoke`. No se inyectó un proveedor ni un `fetch` simulado en este recorrido. Por tanto, el DELETE 200 acredita que el código estricto aceptó esas respuestas de Apple. **No se realizó una captura HTTP independiente de las respuestas de Apple**, para evitar registrar códigos o tokens.

Los tres archivos comprobados coinciden byte a byte con el commit de despliegue `a0433fe90e742dfa81c535eb00fee6137cfd1270`:

| Archivo | SHA-256 |
| --- | --- |
| `app/api/nido/auth/account/route.ts` | `cf19144f15eb61abea18ec0e03aeeba65b887447fee225524a64da1a40072097` |
| `app/api/nido/apple-token-revocation.ts` | `04bb77f2e833fe10d65046381a35698a961c484bfcad545225b8a11b0d16f06e` |
| `app/api/nido/apple-verifier.ts` | `0fcf131fa02a140176adf51803fad8be83e603ba146a254755ce59563e5a5da6` |

## Límites y metodología

- Se probó con Apple real la rama sin membresía. Las ramas de propietario y cuidador con registros, compartir entre dos Apple ID y volver a autorizar tras la revocación no se ejecutaron en este recorrido.
- La sesión anterior desapareció de la base y el cliente cerró el acceso. No se conservó su Bearer en bruto para repetir una petición HTTP con él.
- La prueba usa una copia DEBUG aislada y el mismo contrato de servidor; no es ejecución del IPA Store contra datos personales de producción.
- No hubo cambios de comportamiento durante esta comprobación, por lo que no aplica un nuevo ciclo TDD unitario. El candidato conserva el rojo → verde anterior, siete casos enfocados y 67/67 pruebas sobre PostgreSQL real. La instrumentación conserva su rojo, matriz verde, 149 pruebas Swift y una prueba UI aprobada.
- El rollback del servidor no recupera esta cuenta eliminada ni restaura la autorización Apple. [Despliegue y reversión](account-deletion-deployment-result-2026-10-16.md).

Evidencia local: `~/.codex/recoveries/nido-20261015/apple-live-e2e-20261016/server-ipv4-resume.log`. La configuración privada permanece fuera de Git.

Tras preservar la evidencia se cerró el proceso Node identificado por su ruta de prueba y se eliminó únicamente PostgreSQL efímero mediante el helper que valida su propiedad. El puerto 43127 ya no escucha. No se detuvieron otros contenedores ni servicios de producción.
