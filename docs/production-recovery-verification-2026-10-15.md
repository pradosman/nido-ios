# Copia y recuperación de producción — 15 de octubre de 2026

Validación operativa realizada por SSH, autorizada por el usuario. **Sin cambios en la base de producción ni despliegue nuevo.** No aplica TDD unitario: se sustituye por cifrado, restauración real y comprobaciones HTTP en un entorno aislado.

## Copia protegida

`pg_dump` de PostgreSQL 17.10 se transmitió directamente desde el contenedor de Nido por SSH a `age` en el Mac. No se creó un archivo de base en texto claro. Se utilizó la identidad de servidor ya conocida con `StrictHostKeyChecking=yes` y acceso no interactivo.

La copia cifrada y su identidad de descifrado están fuera del repositorio y del VPS, en la carpeta privada `/Users/pradosman/.codex/recoveries/nido-20261015/production-backup/`. Ambos archivos tienen permisos `0600`; la identidad no debe publicarse ni incorporarse a Git. No se han mostrado secretos ni registros personales en la entrega.

## Restauración comprobada

Primera comprobación: descifrado canalizado a `pg_restore --exit-on-error` en un PostgreSQL 17.10 temporal sin red y con almacenamiento temporal. Restauración correcta, tablas necesarias presentes y ninguna clave foránea sin validar. El contenedor se eliminó al terminar.

Segunda comprobación: restauración en otro PostgreSQL aislado, conexión limitada a loopback con credencial temporal, migraciones y API de la copia `/tmp/nido-account-suite-20261015`, anterior a la integración de revocación Apple:

- `GET /api/nido/status`: **200**, estructura de respuesta esperada.
- `GET /api/nido` sin credenciales: **401**.
- Después de migrar: 11 tablas públicas y 11 claves foráneas.
- Proceso API detenido, contenedor y volumen propios eliminados, archivo de contraseña temporal eliminado.
- Los siete contenedores Supabase previos permanecen en marcha.

Evidencia: `/tmp/nido-production-backup-verify-20261015.log` y `/tmp/nido-production-backup-api-check-20261015.log`. El segundo registro está protegido con `0600` y no contiene filas ni secretos.

## Límites

La restauración acredita esta copia y su compatibilidad con las migraciones/API comprobadas. No acredita recuperación de datos mediante un usuario autenticado, todos los flujos de la app, Apple Sign In real ni despliegue. No se ha configurado una política periódica de retención, almacenamiento adicional o alertas. La ausencia de tareas Nido en el crontab de root no descarta otros mecanismos de copia del proveedor.

El entorno de verificación es desechable: su rollback consiste en eliminar únicamente los recursos identificados como propios, ya realizado. No hay un commit de comportamiento ni una reversión de producción asociada a esta operación.
