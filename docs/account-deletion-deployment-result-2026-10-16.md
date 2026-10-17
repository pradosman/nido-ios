# Despliegue del borrado de cuentas — 16 de octubre de 2026

**Backend actualizado y saludable. Autenticación, borrado y revocación con Apple real aprobados para la cuenta local sin membresía. Nido 0.1.0 (49), con demo completa, está enviada a Apple y «Pendiente de revisión».**

El candidato basado en producción se activó solo en la API de Nido. Cambia el borrado para aceptar sesiones sin hogar, exigir autorización Apple reciente, revocar su acceso y evitar que una escritura concurrente recree atribuciones del usuario eliminado. El cliente firmado 0.1.0 (48) coincide con este contrato.

## Pruebas y estado efectivo

- TDD del candidato: tres fallos correctos dentro de siete casos —dos de atribución y uno por POST demorado con 201 en lugar de 401—; después 7/7, compilación correcta y suite completa **67/67** con PostgreSQL real, sin omisiones. Evidencia preservada antes de desplegar; no se ejecutaron pruebas que truncan tablas contra producción.
- Fuente desplegada: tres archivos de ejecución y sus nueve archivos de prueba, con hashes comprobados. Las migraciones 0000/0001 no cambian; no se añadió una migración.
- Se conservaron el Compose personalizado y los valores existentes de audiencia y autenticación. Se añadieron los tres forwards de revocación. Las **cinco variables requeridas** se validaron en la configuración resuelta y en el contenedor activo, incluidos formato de clave, equipo y audiencia esperados, sin imprimir valores privados.
- Imagen activa: `sha256:0c015c53ae385d14f1408017f8c561416d2c67c201c21ab02fa6dc734ace7a87`, saludable. Los **17 contenedores restantes**, incluido PostgreSQL, conservan exactamente su identidad.
- Comprobación pública HTTPS: estado y páginas legales 200, API protegida sin credenciales 401, raíz 404. El desafío Apple anónimo devuelve 201 y los campos esperados; no se guardaron nonce ni identificador de desafío. Esto no demuestra identidad ni revocación real de Apple.

## Git y reversión

Commit **`a0433fe90e742dfa81c535eb00fee6137cfd1270`**, hijo del legal `f56c9ddbd1f1a03c4318d7d83fc8e9ccee9527fd`, en `codex/apple-account-deletion-release-20261016`. Incluye comportamiento, pruebas, ejemplos y documentación: 17 archivos, 718 líneas añadidas y 16 eliminadas. Supera el presupuesto orientativo de revisión de 400 líneas; se conserva la unidad y sus pruebas completas. No se ha publicado una PR nueva ni se ha actualizado `main`.

El commit contiene los forwards genéricos de Compose. El Compose específico del servidor permanece fuera del índice, con sus ajustes preservados. La clave privada y `.env` no entran en Git. La copia Git local durable está en `~/.codex/recoveries/nido-20261015/account-git-release-20261016/`.

Antes de activar se creó una copia cifrada nueva de PostgreSQL, de permisos 0600. Se descifró por una tubería y PostgreSQL 17 reconoció el archivo y sus 24 entradas de tabla; **no se restauraron datos reales**. El cliente local antiguo de `pg_restore` no reconocía el formato 1.16: se utilizó el cliente de PostgreSQL 17 del contenedor propio.

La reversión conserva:

- Imagen legal anterior `de5193fc…`, etiquetada `nido-rollback:pre-account-20261016-48`.
- Parche inverso completo de 16 archivos de fuente, pruebas y metadatos, y copias anteriores del Compose personalizado y `.env`.
- Script que distingue fuente original, fuente desplegada exacta y estado mixto. En un estado mixto informa del fallo y conserva los archivos para inspección, mientras restaura imagen y configuración.

El fallo inicial del script de reversión se detectó en revisión independiente y se corrigió antes de ejecutarlo. Sus cuatro comprobaciones automatizadas se añadieron después de la corrección: son **pruebas de regresión, no TDD**. Pasan las cuatro, incluidas inyección de fallo del parche inverso y fuente mezclada. La segunda revisión aprobó el script corregido. Esta limitación de metodología corresponde a la automatización del despliegue; el candidato del producto conserva su evidencia TDD anterior.

Volver a una imagen anterior no recupera cuentas eliminadas ni deshace una autorización Apple revocada. No se ejecutó un borrado sobre la cuenta personal de producción.

## Apple real y envío

La prueba usa una copia DEBUG aislada, base PostgreSQL efímera vacía y API exclusivamente en loopback. La instrumentación tiene rojo válido, ocho comprobaciones enfocadas verdes, **149 pruebas Swift aprobadas** y **una prueba de interfaz aprobada** en iPhone 16 Pro. El binario enviado a Apple no incorpora esta instrumentación.

Tras confirmar visualmente la sesión de Ajustes, el usuario completó directamente la contraseña del diálogo Apple. El servidor local devolvió **201** al crear la sesión. Había un usuario y una sesión, sin cuidadores ni hogares. El usuario confirmó expresamente el borrado irreversible y la revocación de Nido, y completó la segunda autorización Apple reciente. El DELETE devolvió **200**, la app volvió al acceso y los siete conteos de datos quedaron a cero. No se tocaron los datos del hogar de producción ni el Apple ID. [Resultado completo y límites](apple-real-deletion-result-2026-10-16.md).

Apple procesó las compilaciones 48 y 49. La 49 sustituyó a la 48 en la asociación de la versión y conserva firma y manifiesto correctos. La privacidad está publicada, el contacto guardado y la clasificación calculada es 4+. El intento inicial exigió precio válido y usuario/contraseña. El titular eligió precio gratuito mundial, guardado en 175 regiones, y demo completa. La demo 49 supera las pruebas y un recorrido Release sin Apple; sus instrucciones y acceso sin credenciales persistieron tras recargar. El envío se completó el 16 de octubre de 2026 a las 09:51, ID `090d79c2-8c2c-454d-af24-94a59e3ab0af`, y el detalle confirma 0.1.0 (49) «Pendiente de revisión». No está aprobada ni publicada. [Estado y evidencia de la demo](demo-release-validation-2026-10-16.md). No se inventaron credenciales ni se compartió su contraseña personal.

La revisión independiente confirma que el manejador real exige intercambio Apple 200, verificación de sujeto/nonce y revocación 200 antes de devolver DELETE 200. Es una inferencia por el control de flujo comprobado y los hashes de la fuente, sin captura HTTP independiente de Apple. La rama real probada es la cuenta sin membresía; no demuestra las ramas de propietario o cuidador con registros.

## Evidencia durable

- VPS: `/root/nido-releases/account-20261016-48/`. `env.before` contiene secretos y no debe mostrarse ni copiarse al repositorio.
- Local: `~/.codex/recoveries/nido-20261015/apple-live-e2e-20261016/`, incluidos `deployment/`, `git-unit/`, los resultados de pruebas y scripts de preparación/reversión.
- Copia cifrada: `~/.codex/recoveries/nido-20261015/production-backup/nido-pre-account-deploy-20261016.dump.age`.

No aplica TDD unitario al informe ni a los metadatos de entrega: se validan por contraste de hashes, configuración, firma, resultados nativos, HTTPS y revisión independiente. El recorrido Apple real se mantiene separado de las pruebas de producción y del envío a App Review ya confirmado.
