# Backend de objetivos y crecimiento: despliegue del 17 de octubre de 2026

El backend de Nido y las migraciones de sueño activo y cuidado están desplegados y saludables. Se sustituyó únicamente la API de Nido en el VPS verificado 943574. Los otros 17 contenedores, incluido PostgreSQL, conservan sus identidades. No se modificó el envío de App Store.

## Candidato y validación

El payload revisado contiene diez archivos sobre la fuente de producción `a0433fe`: las rutas nuevas de cuidado y sueño, respuesta raíz, esquema, dos migraciones, sus snapshots/journal y la actualización legal ya presente en el candidato validado. El SHA-256 del tar es `e7bed01cd826e09a9505e4825923df98c565e33d126ab8f9a77cb877d423baee`. Las precondiciones de cada archivo anterior y los hashes posteriores coincidieron; también se verificaron los 59 archivos de compilación frente al candidato exacto. No se copió el árbol dirty completo, iOS ni el Compose genérico.

Antes de activar pasaron compilación, TypeScript, **82/82 pruebas con PostgreSQL real, sin omisiones**, y **12/12 comprobaciones HTTP standalone** sobre una base sintética aislada. Incluyen permisos, separación entre hogares, CAS simultáneo 200/409, persistencia después de reiniciar, rechazo tras retirar sesiones y cascada. Los contenedores locales de pruebas se eliminaron sin modificar los siete preexistentes. [Preflight y evidencia](backend-baby-care-deployment-preflight-2026-10-17.md).

La revisión independiente aprobó el artefacto concreto y el procedimiento. Las pruebas nuevas reprodujeron primero que dos PUT pausados podían guardar después de retirar la membresía: recibían 200 en vez de 403. Se corrigieron cuidado y sueño mediante una transacción que vuelve a comprobar y bloquea al cuidador activo durante la escritura; ambos rojos pasan, y los seis contratos enfocados también. La comprobación de revisión sigue precediendo al control del rol. Los logs rojo/verde están en `simulator-closeout-2026-10-17/api-race-*.log`. No se afirma cancelar una petición previamente autorizada solo porque se cierre su sesión mientras está en curso.

## Migración y activación

Se creó una copia cifrada nueva de PostgreSQL fuera del VPS, con permisos privados, y PostgreSQL 17 reconoció el archivo mediante `pg_restore --list`. No se restauró sobre la base publicada. Se retuvieron imagen anterior, fuente original y configuración privada.

Después se ensayó la **restauración real** de ese archivo en un contenedor PostgreSQL 17 independiente, sin red ni puertos publicados, con almacenamiento de base exclusivamente en memoria. `pg_restore --exit-on-error` terminó con código 0; se verificaron once tablas públicas, once claves foráneas y las dos entradas del journal anteriores al despliegue. Las consultas sobre usuarios, hogares y registros restaurados funcionaron sin exportar valores personales ni conteos. El contenedor propio se eliminó. La base de producción no se restauró ni modificó en este ensayo.

El migrador compilado y la API usan exactamente la imagen `sha256:de15db54204960edc1791efeb30168faac9a68dcbd18b48c31363235c2fb9a94`, etiqueta `nido-babycare:20261017-goals`. El migrador terminó con código 0 y límites de sesión de bloqueo de 5 segundos y sentencia de 30 segundos. El journal pasó de dos a cuatro entradas, manteniendo las anteriores. Se verificaron la columna bigint `active_sleep_started_at` y la tabla `baby_care_states`; antes de activar estaban vacías de objetivos, medidas o sueño inventados.

Se conservó el Compose específico del servidor y se añadieron solo los dos forwards de contacto legal con los valores ya publicados: responsable y correo de soporte. La fuente nueva exige configuración explícita y, sin ella, la página devolvería 503. El archivo `.env` no cambió, y los valores efectivos de Apple y PostgreSQL coinciden con los anteriores sin imprimirlos. Un override conservado en el directorio de entrega fija la misma imagen para `nido` y `migrate`.

Se activó `nido` con `--no-deps --no-build --pull never`, esperando su salud. Se comprobaron la identidad de imagen y ocho respuestas HTTPS: estado y páginas legales 200; cuidado, sueño, raíz de API y registros sin sesión 401; raíz del dominio 404. Este smoke publicado no acredita una autorización Apple real ni una escritura autenticada sobre datos familiares reales; los recorridos autenticados usan el stack real en aislamiento.

Para una recreación manual de este despliegue se deben conservar **ambos archivos Compose**, incluido `/root/nido-releases/baby-care-20261017-goals/candidate-image.yml`, que fija la imagen aprobada. Ejecutar solo el Compose base puede seleccionar la etiqueta de compilación anterior. Un despliegue posterior desde Git/Dokploy debe incorporar el payload validado y su configuración; no se ha cambiado ni publicado la rama fuente automática.

## Reversión y evidencia

La imagen anterior se conserva como `nido-rollback:pre-babycare-20261017` (`0c015c53…7a87`). La reversión operativa consiste en restaurar imagen, los cuatro archivos anteriores modificados, retirar los seis archivos nuevos del payload solo tras comprobar sus hashes, y restaurar el Compose previo. La copia de fuente está en `source-before.tar`; los manifiestos distinguen archivos anteriores y nuevos. No revertir cambios concurrentes ni utilizar reset/clean sobre todo el checkout.

**Conservar ambas adiciones de esquema y los datos nuevos al revertir la API.** La versión anterior tolera estas adiciones. No borrar tabla, columna ni journal; restaurar una copia de base sobre producción perdería escrituras posteriores y no forma parte de este rollback. La reversión tampoco recupera cuentas borradas ni autorizaciones Apple revocadas.

Los archivos privados están en `/root/nido-releases/baby-care-20261017-goals/` y `~/.codex/recoveries/nido-baby-care-20261017/`. No copiar `env.before` ni el inspect privado al repositorio. La evidencia pública y [resultado estructurado](backend-baby-care-deployment-2026-10-17/result.json) se conservan en `backend-baby-care-deployment-2026-10-17/`.

No se creó commit ni push. El límite reversible es este payload y su imagen retenida, no todo el árbol de la rama. No aplica TDD unitario al informe ni a metadatos/configuración de despliegue: los sustituyen hashes, validación Compose, migración real, identidad de imagen, salud y smoke HTTPS. Los cambios ejecutables de las rutas sí conservan sus rojos anteriores y verdes posteriores.
