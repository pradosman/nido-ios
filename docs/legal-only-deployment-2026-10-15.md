# Preparación de publicación de las páginas legales

Estado actualizado: **publicado y verificado por HTTPS** después de la autorización posterior del usuario. Véase el [resultado del despliegue](legal-deployment-result-2026-10-15.md). Este documento conserva la preparación y su secuencia de aprobación original. Suite serial del candidato: **48 seleccionadas, 48 correctas, 0 fallos, 0 canceladas y 0 omitidas**.

## Alcance revisable

Base exacta de producción: `b6a8f58bfcf99c0029e5698652e2dc25f29cf1c7`.

El paquete añade únicamente:

- `app/api/nido/legal/legal-pages.ts`.
- `app/api/nido/legal/privacy/route.ts`.
- `app/api/nido/legal/support/route.ts`.
- `tests/legal-only-http.contract.test.mjs`.

Los contactos públicos aprobados se compilan como valores predeterminados: **David Prados Mancilla**, **pradosman@gmail.com**. Se mantienen los overrides opcionales, su validación y el escape de HTML. Una configuración explícita inválida sigue devolviendo `503`. El texto informa que los registros compartidos **y sus datos de autoría pueden permanecer en el hogar** cuando una persona integrante elimina su cuenta; no promete anonimización.

El contrato cambia expresamente: la ausencia de overrides ya no deja la página en `503`; usa los contactos aprobados y devuelve `200`. Esto evita modificar `.env` o el Compose remoto. Las rutas no importan autenticación, base de datos ni eliminación de cuenta. No se incorpora el código nuevo de revocación Apple, sus claves, migraciones o cambios nativos.

La comparación de los **146 archivos originales** extraídos de la revisión remota no encontró modificaciones. El candidato únicamente contiene los cuatro archivos añadidos y salidas locales de verificación. La semántica de conservación y eliminación descrita se ha contrastado con la ruta de eliminación de cuenta y el esquema de esta revisión de producción, que se conservan intactos. En concreto, `entry_authors` conserva `caregiver_id` y `caregiver_name` sin una clave foránea al cuidador; la eliminación de una cuenta integrante borra `users` y no elimina esos datos de autoría. La copia inicial heredada del backend más reciente afirmaba incorrectamente «sin atribuirse a esa persona» y se corrigió con una nueva prueba roja antes de cambiar el texto.

**Pendiente ajeno al paquete:** la base de producción mantiene el defecto de borrado de autoría que ya corrige el backend completo preparado por separado. Estas páginas describen fielmente el comportamiento existente; **no corrigen ese defecto ni cierran el pendiente de eliminación de cuenta para la publicación en App Store**. El código de borrado/revocación y su validación deben entregarse en otra unidad, sin ampliar este paquete legal.

## Paquete y evidencia

Directorio local: `/Users/pradosman/.codex/recoveries/nido-20261015/legal-only-preparation-20261015/`.

| Archivo | Función |
| --- | --- |
| `candidate/` | Fuente aislada de producción más el cambio legal; dependencias mediante enlace local existente. |
| `legal-only.patch` | Parche de cuatro adiciones, sin cambios de configuración. |
| `payload.tar` | Los mismos cuatro archivos, sin dependencias ni secretos. |
| `payload-manifest.json` | SHA-256 y tamaño por archivo; revisión y Compose esperados. |
| `baseline-equivalence.json` | Comparación de los 146 archivos base. |
| `legal-http-red.log` | Cuatro contratos HTTP fallan antes de implementar las rutas: `404` en vez de `200`/`503`. |
| `legal-http-green.log` | Cuatro contratos HTTP correctos después de implementar: contacto predeterminado, acceso público, override inválido y escape. |
| `legal-authorship-red.log` | Nuevo contrato HTTP: 4 correctas y 1 fallo porque el texto omitía la autoría conservada y prometía falta de atribución. |
| `legal-authorship-green.log` | Los 5 contratos HTTP correctos después de corregir únicamente ese párrafo. |
| `before-authorship-correction/` | Parche, payload, manifiestos, fuente afectada y documento anteriores conservados como evidencia histórica; no son el candidato vigente. |
| `legal-suite-build.log` | Build standalone y ejecutor de migraciones correctos; suite interrumpida después por el guard de disco. |
| `legal-suite-serial.log` | Reejecución serial completa: 42 correctas, 5 omisiones explícitas de PostgreSQL externo, sin fallos ni cancelaciones. |
| `legal-authorship-build.log` | Reconstrucción del candidato corregido: standalone y ejecutor de migraciones correctos. |
| `legal-authorship-suite-serial.log` | Suite intermedia tras corregir la copia: 43 correctas y 5 omisiones de PostgreSQL externo, sin fallos ni cancelaciones. |
| `legal-real-pg-suite-serial.log` | Suite final del mismo candidato con PostgreSQL real habilitado: 48 correctas, sin fallos, cancelaciones ni omisiones. |
| `legal-real-pg-run-summary.json` | Migración y suite con salida `0`; contenedor temporal eliminado; IDs y estado de ejecución de los 7 contenedores previos intactos. |
| `pg-existing-before.json`, `pg-existing-after.json` | Inventario limitado a identidad y estado de ejecución, antes y después de la prueba aislada. |
| `standalone-http-green.json` | Servidor compilado real: privacidad `200`, soporte `200`, API protegida `401`, raíz `404`. |
| `standalone-authorship-http-green.json` | Smoke vigente del servidor reconstruido: los mismos 4 escenarios correctos, incluida la declaración de autoría conservada y ausencia de la promesa de anonimización. |
| `patch-roundtrip-green.json` | Aplicación y reversión local completas; archivos base intactos. |

SHA-256 del parche: `35a8b6aa1edfe23803c2f3822b9c8af700e68742ca5ea0c56432257beecb7323`.

### Validación y límites

El primer ciclo rojo → verde se realizó antes de añadir producción al candidato: **4 fallos esperados → 4 correctas**, sin omisiones. La corrección factual posterior empezó con un nuevo contrato HTTP: **4 correctas y 1 fallo por omitir la autoría conservada → 5 correctas**, antes y después de cambiar únicamente el párrafo. El harness sirve por HTTP las respuestas de los handlers; después se verificaron también las rutas del servidor standalone reconstruido real, incluida la copia corregida, sin variables de contacto, claves Apple ni base de datos configuradas.

La compilación `vinext build` completó sus cinco fases y `build:migrate` finalizó correctamente. La primera suite utilizó el script heredado `npm test`, que ejecuta los archivos de pruebas en paralelo. El guard propio detuvo su grupo al caer el espacio disponible por debajo de 2 GiB. Resultado incompleto: **21 correctas, 0 fallos de expectativas, 4 canceladas y 5 omitidas de PostgreSQL externo**. No es una suite verde.

La reejecución serial posterior inicial completó 47 casos; después de la corrección factual se reconstruyó el candidato y una suite serial intermedia completó los **48 casos**, con **43 correctos, 0 fallos, 0 cancelaciones y 5 omisiones de PostgreSQL externo**, en 10,54 segundos y con código de salida `0`. Comando reproducible, sin reconstruir mientras no cambie la fuente:

```sh
node --test --test-concurrency=1 tests/*.test.mjs
```

Finalmente se habilitaron los cinco contratos PostgreSQL sobre un contenedor local desechable propio, con la imagen ya disponible `postgres:17.10-bookworm` (`--pull=never`), puerto aleatorio únicamente en localhost, datos en tmpfs de 256 MB, memoria limitada a 256 MB y una CPU. Se ejecutó la migración del candidato y la suite serial completa: **48/48 correctas, 0 fallos, 0 cancelaciones y 0 omisiones**, en 31,25 segundos; ambos procesos terminaron con código `0`. La variable correcta es `NIDO_REAL_POSTGRES_URL`. La URL y contraseña sintéticas se transmitieron únicamente en el entorno de los procesos, sin imprimirlas ni guardarlas.

Antes de detener y eliminar el contenedor temporal se verificaron su CID, nombre, imagen y etiquetas con nonce exclusivo. Los **7 contenedores locales existentes** conservaron exactamente sus IDs y estados de ejecución; no se reinició Docker ni se modificaron sus datos. No se usó la base de datos de Supabase ni ninguna base remota. Se conservan los resultados previos con omisiones como historial, pero el resultado vigente ya no omite esos casos. Las pruebas completas del backend más reciente no sustituyen a las de este candidato, que parte de otra revisión.

Esta documentación no cambia comportamiento ejecutable: no aplica TDD unitario. Se valida contra los manifiestos, logs, parche y escenario HTTP indicados. No se ha añadido un aplicador automático sin pruebas.

## Preflight para una futura autorización de publicación

VPS verificado por SSH existente: `root@148.230.108.174`. Checkout: `/etc/dokploy/compose/nido-nido-wuwhrr/code`. Proyecto Compose confirmado por las etiquetas del contenedor: `nido-nido-wuwhrr`; servicio: `nido`.

Comprobar inmediatamente antes de cualquier escritura:

1. `HEAD` sigue en la revisión base indicada. Si cambia, volver a preparar y validar el candidato.
2. El único cambio tracked remoto sigue siendo `compose.vps.yml`; nunca restaurarlo, reemplazarlo ni copiar encima el Compose base del candidato.
3. SHA-256 del Compose remoto sigue siendo `f1eb005f1ced4916425053bde12a3ff8475f1aaa4ad78a1bfb36042fb72cd8b3`.
4. Ninguna de las cuatro rutas del parche existe ya como archivo tracked o untracked. Comprobar `git apply --check` contra el checkout real y verificar los hashes del payload antes de aplicarlo.
5. La imagen actualmente ejecutada sigue disponible para rollback. Identidad observada: `sha256:89f44244667ef7c1e89b519cdb288d3e335d209b69d0ab0cbc5e570a70e4b755`; contenedor `nido-nido-wuwhrr-nido-1`, saludable. Revalidarla y retenerla con una etiqueta de rollback antes de construir.
6. Hay espacio suficiente, copia cifrada recuperable ya verificada y una ventana de recreación únicamente de la API. No imprimir `.env`, `docker inspect` completo ni configuración resuelta con secretos.
7. La suite serial y el smoke HTTP del candidato están completos; una persona revisó el texto público y el alcance del parche.

## Secuencia futura propuesta, todavía no ejecutada

Tras aprobación concreta del candidato, transferir solo el parche/manifiesto al área de preparación del VPS; conservar la imagen anterior; comprobar y aplicar el parche. Construir únicamente `nido` usando el Compose remoto existente y el mismo proyecto. Reemplazar únicamente ese servicio con `--no-deps --no-build --pull never`; no recrear PostgreSQL ni ejecutar el servicio de migración. El parche no modifica esquema ni migraciones.

Verificar por HTTPS público `/api/nido/legal/privacy` y `/api/nido/legal/support`: `200`, HTML español, contacto aprobado, enlaces correctos y `Cache-Control: no-store`. Comprobar también salud pública, API privada sin credenciales `401` y raíz `404`. Preservar las evidencias. No considerar que una página pública funciona solo porque el contenedor está saludable.

No usar un redeploy que haga `git pull`, `reset` o `clean` automáticamente: podría eliminar el parche preparado o el Compose local existente. La posterior integración permanente de estas cuatro adiciones en Git debe conservar la misma revisión de base y unidad revisable; no incluir el árbol actual completo de desarrollo.

## Rollback concreto

El límite reversible son las **cuatro adiciones del parche y la imagen de la API**. No hay reversión de datos porque este paquete no cambia la base de datos.

- Fuente: `git apply --reverse --check legal-only.patch` y después la reversión, únicamente si sus cuatro archivos mantienen los hashes aprobados. Si alguien los ha editado, detenerse y revisar; no borrarlos a ciegas. La reversión local comprobada elimina esas cuatro adiciones y mantiene intactos todos los archivos base.
- Servicio: volver a etiquetar la imagen retenida anterior como la imagen del servicio `nido` y recrear solamente ese servicio, con el Compose remoto intacto y sin dependencias/build/pull. No ejecutar `down`, `down -v`, restauraciones de datos ni reinicios de otros servicios.
- Confirmación: las rutas legales vuelven al comportamiento previo, la API está saludable y la autenticación conserva su comportamiento. El SHA-256 de Compose y los recursos PostgreSQL permanecen idénticos.

La imagen anterior y sus etiquetas no deben podarse hasta validar la publicación. El rollback de código puede volver a dejar las páginas legales en `404`; ese es el comportamiento previo, no una recuperación funcional de esas páginas.
