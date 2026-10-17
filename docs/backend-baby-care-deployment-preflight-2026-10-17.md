# Preflight backend: cuidado y crecimiento, 17 de octubre de 2026

Informe de preparación; no acredita por sí solo un despliegue. Root conserva la responsabilidad única sobre VPS, respaldo, migración y activación. Este agente solo inspeccionó fuentes y ejecutó validación local aislada autorizada. No hubo commits ni push.

## Producción y fuente de comparación

El informe de borrado del 16 de octubre documenta `root@148.230.108.174`, checkout `/etc/dokploy/compose/nido-nido-wuwhrr/code`, proyecto Compose `nido-nido-wuwhrr`, servicio `nido`. Root revalidó VPS 943574, HEAD remoto `a0433fe90e742dfa81c535eb00fee6137cfd1270`, imagen API `sha256:0c015c53ae385d14f1408017f8c561416d2c67c201c21ab02fa6dc734ace7a87`, Compose personalizado y los otros 17 contenedores. Este agente no ejecutó SSH.

La copia durable `~/.codex/recoveries/nido-20261015/account-git-release-20261016/` tiene el mismo HEAD `a0433fe`. Se comparó por SHA-256 su fuente con el árbol actual. Las rutas de account/entries, auth, Dockerfile, entrypoint, configuración de compilación y locks coinciden. No se debe desplegar el árbol dirty completo ni copiar su Compose encima del remoto.

Delta exacto final de producto, incluida la corrección concurrente en las dos rutas nuevas:

- `app/api/nido/baby-care/route.ts`
- `app/api/nido/sleep/route.ts`
- `app/api/nido/route.ts`
- `app/api/nido/legal/legal-pages.ts`
- `db/schema.ts`
- `drizzle-pg/0002_massive_barracuda.sql`
- `drizzle-pg/0003_baby_care_states.sql`
- `drizzle-pg/meta/0002_snapshot.json`
- `drizzle-pg/meta/0003_snapshot.json`
- `drizzle-pg/meta/_journal.json`

El artefacto final es `/tmp/nido-babycare-pg-preflight-20261017/final/payload.tar`, con estos diez archivos relativos a raíz y SHA-256 `e7bed01cd826e09a9505e4825923df98c565e33d126ab8f9a77cb877d423baee`. El manifiesto `payload-manifest.json` contiene hashes anteriores (o ausencia) y posteriores por archivo y baseline `a0433fe`; SHA-256 `cf6afa740bb26450f5dea1c83afe4cea2cd21cb30b140c19e37ce165ecce3caa`. `candidate-source-manifest.json` acredita igualdad de los 59 archivos de entrada de compilación entre árbol actual y copia temporal; no se encontraron eliminaciones respecto al baseline y los cuatro archivos public/worker coinciden. `review-tests.tar` contiene 42 pruebas/fixtures de revisión, con ejemplos públicos y sin `.env` reales. Los manifiestos están copiados a la evidencia durable final. Comprobar sus hashes después de transferir. Mantener pruebas/evidencia en un paquete de revisión separado; no incluir iOS, vistas, recursos, node_modules, dist ni archivos `.env`/secretos. Root eligió conservar el candidato completo y añadir al entorno remoto los dos contactos públicos previamente publicados, con forwards explícitos en el Compose personalizado y respaldo de configuración de permisos 0600. Esto preserva los contratos correctos del árbol actual; no se modifican expectativas para conservar defaults antiguos.

## Esquema y compatibilidad

`0002` añade `households.active_sleep_started_at`, nullable, con CHECK de intervalo 2000–2100. `0003` crea `baby_care_states`: PK/FK `household_id`, borrado en cascada desde hogares, revisión entera positiva, zona horaria, arrays JSONB de metas y mediciones, fechas de creación/actualización. No elimina columnas ni transforma registros existentes.

La API anterior puede seguir operando tras estas adiciones. La API nueva necesita ambas migraciones: el GET raíz consulta la columna de sueño. El nuevo campo `activeSleepStartedAt` amplía el JSON; los clientes que ignoran claves desconocidas conservan compatibilidad. El estado de cuidado se obtiene mediante ruta nueva y no cambia las respuestas existentes. Antes de activar, verificar el decodificador del cliente distribuido y los conteos/journal de producción.

No ejecutar SQL suelto ni solo `0003` sin verificar `0002`. Usar el migrador del candidato con `drizzle-pg` completo: `db/migrate.ts` usa conexión única y advisory lock `731020260901`, y Drizzle registra el journal. Comparar timestamps/hashes del journal remoto, tablas y columna esperadas; abortar si hay migraciones desconocidas o esquema incoherente. Añadir columna/CHECK toma bloqueos sobre hogares; ejecutar con límites de lock/statement razonables y observar disponibilidad. Una nueva tabla vacía evita backfill de datos reales.

## Condiciones antes de activar

1. Guardar imagen anterior con etiqueta de rollback, Compose personalizado, fuente anterior y manifiesto sin secretos; conservar respaldo cifrado nuevo y verificar que PostgreSQL 17 reconoce el archivo con `pg_restore --list`, sin restaurar datos reales.
2. Preservar `.env` y Compose remotos. Comprobar solo presencia, no imprimir valores, de las variables Apple, bucket y PostgreSQL. La versión local de legal elimina defaults: necesita `NIDO_PRIVACY_CONTROLLER` y `NIDO_SUPPORT_EMAIL` efectivos o devuelve 503. Confirmar forwards en el Compose personalizado.
3. Validar candidato exacto con PostgreSQL desechable, migración dos veces, suite serial sin omisiones y HTTP real autenticado sobre base sintética. La corrección concurrente cerró su rojo/verde antes de congelar los hashes y ejecutar la validación final.
4. Transferir y aplicar solo el artefacto bajo precondiciones de hashes; construir la imagen de `nido` conservando el Compose remoto. El migrador debe usar exactamente esa imagen y ejecutarse una sola vez, sin recrear PostgreSQL. Fijar un tag único de candidato en un override temporal para ambos servicios (`nido` y `migrate`), construir solo `nido` y registrar el image ID. Ejecutar `compose run --rm --no-deps --pull never migrate` sin `--build`; verificar que el contenedor usa el image ID registrado. `compose run` no dispone de `--no-build`. Conservar el override como parte de la entrega. Para acotar DDL, pasar solo al proceso migrador parámetros startup `options=-c lock_timeout=5s -c statement_timeout=30s` en la URL construida en memoria; verificar esta ruta en PostgreSQL aislado antes del uso real. No alterar permanentemente la configuración del servidor o rol.
5. Activar únicamente `nido` con `--no-deps --no-build --pull never`. No `compose down`, no `down -v`, no recrear base ni otros servicios. Verificar salud y HTTPS, rutas nuevas sin credenciales (401), legales (200), hashes de fuente/config y las identidades de los otros contenedores. Un `/status` 200 no prueba Apple ni el flujo de cuidado autenticado.

## Concurrencia y datos

Baby-care emplea inserción `ON CONFLICT DO NOTHING` y actualización condicionada a revisión. Rechaza conflictos con 409 y devuelve estado actual; no combina silenciosamente documentos JSON. Es necesario que el cliente vuelva a obtener el estado y reaplique su cambio conservando metas ajenas. Cuidadores pueden cambiar mediciones; metas y zona quedan reservadas al propietario una vez existe el estado. El primer cuidador puede inicializar estado vacío de metas con su zona.

Hallazgo previo a activación: la versión inicial autorizaba antes de escribir sin mantener bloqueo de sesión/membresía. Una petición ya autorizada podía quedar pausada mientras se eliminaba el cuidador de un hogar que sobrevive y después escribir. CAS no resuelve esa revocación. La reproducción TDD confirmó el fallo en ambas rutas: baby-care y sueño devolvieron **200 en lugar de 403** tras retirar la membresía mientras la petición estaba pausada. Rojo durable: `docs/simulator-closeout-2026-10-17/api-race-red.log`. La corrección revalida y bloquea la fila activa del cuidador con `FOR UPDATE` dentro de la transacción que escribe los datos, y usa el rol actual. Verde enfocado **2/2**, contratos de ambas rutas **6/6**; `api-race-green.log` y `api-race-contracts.log` en el mismo directorio. La suite final y HTTP real también pasan. El alcance demostrado es revocación/eliminación de membresía: no prueba cancelar una petición ya autorizada cuando solo se revoca su sesión mediante logout.

El borrado de hogar elimina la tabla nueva por FK; una eliminación individual conserva el estado compartido del hogar. JSONB no registra autorías por medida. Los límites HTTP son 4 MB, 500 versiones de metas y 5.000 mediciones, con valores e IDs validados en API; no constituyen restricciones de estructura JSON en SQL.

## Pruebas PostgreSQL aisladas

La variable correcta es `NIDO_REAL_POSTGRES_URL`. Los cinco casos de `tests/postgres-real.contract.test.mjs` truncarán usuarios, hogares y tablas relacionadas con `CASCADE`, incluida la nueva tabla. Nunca apuntar esta variable a producción. Usar proceso/entorno separado y URL sintética solo en memoria; no cargar `.env`.

Prueba autorizada en contenedor propio `postgres:17.10-bookworm`, `--pull=never`, bind aleatorio `127.0.0.1`, tmpfs de 256 MiB, memoria 256 MiB y una CPU, con nonce/label exclusivo. Antes/después se inventarían solo IDs, nombres y estado de contenedores; limpieza condicionada a CID y label. Se usó la copia temporal calentada documentada en backend-validation, completada con quince fixtures de despliegue/iOS necesarios para la suite; no se ejecutó Xcode.

Comandos de proceso, con URL sintética transmitida mediante entorno:

```sh
node --experimental-strip-types db/migrate.ts
node --experimental-strip-types --test --test-concurrency=1 tests/*.test.mjs
```

Baseline anterior a la corrección concurrente: migrador salida 0, cuatro migraciones registradas y suite **80/80**, cero fallos/omisiones, 55,24 segundos. Smoke HTTP del standalone: **12/12** comprobaciones, incluidos CAS simultáneo 200/409, aislamiento entre hogares, roles, escritura compartida, persistencia al reiniciar, sueño, legales configuradas 200, sesión de integrante borrado 401 y cascade. Ambos contenedores propios eliminados, con IDs/estado de los siete preexistentes intactos. Evidencia durable: `docs/goal-rings-checkpoint-2026-10-17/backend-pg-baseline/`. Resultado final tras la corrección: **82/82**, cero fallos/cancelaciones/omisiones, 63,27 segundos; `npm run build` y `tsc --noEmit` salidas **0**; **12/12** comprobaciones HTTP reales del standalone. Se ejecutó el migrador compilado dos veces con salida **0**, manteniendo cuatro filas de journal. Un probe PostgreSQL con la misma URL de startup verificó `current_setting(lock_timeout)=5s` y `current_setting(statement_timeout)=30s` antes de importar el bundle migrador; la conexión del migrador vuelve a usar esa URL. No se instrumentó el bundle de producción. PostgreSQL propio eliminado y siete contenedores preexistentes con IDs/estado intactos. Evidencia y scripts reproducibles: `docs/goal-rings-checkpoint-2026-10-17/backend-pg-final/`. Registros operativos y tar de entrega: `/tmp/nido-babycare-pg-preflight-20261017/final/`.

## Rollback y método

El rollback operativo restaura únicamente imagen API/fuente/configuración previas; mantener las adiciones de esquema es más seguro y compatible. No borrar tabla/columna ni rebobinar journal para volver a la imagen anterior: destruiría nuevas mediciones/metas/sueño. El respaldo permite recuperación de desastre, pero restaurarlo sobre producción perdería escrituras posteriores y requiere una decisión separada. Volver atrás tampoco recupera cuentas eliminadas ni grants Apple revocados.

No aplica TDD unitario a este informe ni al inventario de artefactos. Lo sustituyen comparación reproducible de hashes, lectura de esquema/contratos y validación de configuración sin secretos. La repetición de la suite existente es verificación; la corrección de autorización mantiene su ciclo rojo → verde acreditado por separado. Sin commit nuevo, el límite reversible se define por el artefacto y la imagen retenida, no por HEAD dirty.

El servidor y base de estas pruebas fueron eliminados al terminar. El probador de iOS recibió después la copia temporal congelada y asume sus propios recursos aislados para los tres escenarios de interfaz. Esas sesiones sintéticas de Nido no acreditan un recorrido Apple SIWA real. Este informe no acredita todavía compilación Docker o activación en VPS; Root conserva esa validación sobre el mismo manifiesto.
