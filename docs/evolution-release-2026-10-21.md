# Entrega de Evolución — 21 de octubre de 2026

**Estado vigente: Nido 0.1.0 (50) enviada a App Review y pendiente de revisión.** Se mantiene publicación automática tras aprobación. Envío del 21 de octubre de 2026 a las 18:28, ID `bd998e30-b969-4c70-87ef-3c5d20ad5ea9`. Aún no está aprobada ni disponible públicamente.

El usuario autoriza expresamente crear commits, subirlos a `main` y publicar en App Store. Esta instrucción sustituye el límite anterior de no hacer commits ni publicaciones. No se han solicitado instalaciones en dispositivos físicos.

La fuente funcional validada conserva 248 pruebas Core, 32 pruebas del inventario y 245 ejecuciones de la app sin fallos ni omisiones; compilación Release correcta. La evidencia y el rollback funcional están en `evolution-health-plan-2026-10-20/sleep-hour-axis-2026-10-21.md`.

Se preparan dos unidades funcionales (dominio con sus pruebas; integración de las cinco métricas, fijados y navegación con sus pruebas y el inventario completo). La integración y el arnés comparten el contrato de selectores; separarlos dejaría el gate incompleto. Exceden el tamaño orientativo de revisión para conservar cada unidad utilizable. La petición de integración directa en `main` prevalece sobre abrir una cadena de PRs.

Los archivos locales de exploración, skills, capturas y logs voluminosos ajenos al código de la entrega se conservan sin incorporarlos en bloque a Git. Se incluye el fixture PNG necesario para las pruebas del menú.

## Candidato de distribución

Versión 0.1.0, compilación 50, tanto en la app como en Live Activity. Se conserva el bundle ID `com.momentumia.nido` y el equipo existente. La consulta pública española no devuelve una app publicada; el último envío documentado es 0.1.0 (49). La ficha autenticada deberá confirmar estado y disponibilidad del número antes de finalizar el envío.

Este cambio solo ajusta metadatos; no aplica TDD unitario. Validación sustitutiva: sintaxis del proyecto, coherencia de versión app/extensión, archive Release, firma, exportación y recepción/procesamiento por Apple. Los resultados de simulador anteriores no se presentan como validación física ni como aceptación de Apple.

Estado inicial de distribución: App Store Connect solicita inicio de sesión; se ha pedido al usuario completarlo mientras se prepara el archivo. La subida, el envío a revisión y la disponibilidad pública se documentarán por separado según la evidencia real.

## Resultado verificado

- Commits creados: `6d1dc33` (dominio y pruebas), `2b80188` (integración, navegación y gate completo), `786d2b4` (metadatos 50). `main` avanzó directamente desde `b6a8f58` hasta `786d2b4` y el push a `origin/main` terminó correctamente. Los 37 commits previos de la rama de diseño también forman parte de ese avance, sin reescritura de historial.
- La fuente de distribución es un clon limpio de `origin/main` en `/tmp/nido-appstore-release-20261021`, revisión completa `786d2b4b93092bd73f16987f3fc1e8471a0bf634`. El `BuildMetadata.plist` incorporado indica `GitRevision=786d2b4` y `GitDirty=false`.
- Archivo: `ARCHIVE SUCCEEDED` en `/tmp/nido-appstore-50-archive.log`. Exportación: `EXPORT SUCCEEDED` en `/tmp/nido-appstore-50-export.log`. Tanto app como Live Activity contienen 0.1.0 (50), equipo `6VVEKN47Y3`, perfiles sin lista de dispositivos y `get-task-allow=false`. Ambas verificaciones `codesign --verify --deep --strict` terminaron con salida 0. El manifiesto de la app incorpora siete categorías de privacidad.
- IPA exportada: `/tmp/nido-appstore-50-artifacts-20261021/AppStoreExport/Nido.ipa`, SHA-256 `0328b9f85074ede47b6953cec97956ef24544c8b86ec94c51d495a45f8432fb2`.
- Apple recibió la subida el 21 de octubre a las 17:56:41 (hora local del log). `/tmp/nido-appstore-50-upload.log` confirma «Uploaded package is processing», «Upload succeeded», «Uploaded Nido» y `EXPORT SUCCEEDED`, salida 0. Esto acredita recepción del binario, no finalización del procesamiento, asociación a la versión ni envío a revisión.
- El servicio público de producción respondió HTTP 200 a `/api/nido/status` después del push. Esta comprobación no identifica por sí sola el commit desplegado ni acredita todos sus endpoints.

Tras la subida, la asociación y el envío quedaron inicialmente pendientes de que el usuario iniciase sesión en App Store Connect. El usuario completó ese acceso y se continuó con la autorización de publicación existente; el resultado final se documenta a continuación.

Los artefactos de firma y los logs de distribución se conservan también en `~/.codex/recoveries/nido-20261021/store-50-20261021/`, fuera de Git. Ninguna clave privada se incorpora al repositorio. El commit documental posterior a `786d2b4` solo registra estos resultados y no cambia el binario recibido por Apple.

## Envío a revisión completado

- La 50 ya estaba procesada. Se respondió su información de exportación con «Ninguno de los algoritmos mencionados anteriormente», coherente con el uso exclusivo de criptografía del sistema de Apple documentado en el análisis previo. TestFlight confirmó «Lista para enviar» para la compilación `1ec40463-b7a5-4bdf-923a-aba4a54e6ec1`.
- Se canceló el envío anterior de la 49 (`090d79c2-8c2c-454d-af24-94a59e3ab0af`). La versión quedó editable como «Rechazado por el desarrollador»; el listado histórico pasó a «Eliminado». No se borraron las compilaciones anteriores de TestFlight.
- Se seleccionó y guardó 0.1.0 (50). Las notas de revisión ahora indican la 50 y el nombre Evolución; se conserva el acceso mediante «Explorar demostración», sin exigir credenciales, y los datos de contacto ya existentes. Se verificó Guardar desactivado tras persistir los cambios, la casilla de inicio de sesión desmarcada y la publicación automática seleccionada.
- «Añadir a revisión» creó el borrador con 0.1.0 (50); «Enviar a revisión» produjo la confirmación «1 artículo enviado». El detalle del envío muestra «Pendiente de revisión», la 50 y la fecha 21 de octubre de 2026 a las 18:28.
- Confirmación: <https://appstoreconnect.apple.com/apps/6823152436/distribution/reviewsubmissions/details/bd998e30-b969-4c70-87ef-3c5d20ad5ea9>. Captura: `~/.codex/recoveries/nido-20261021/store-50-20261021/app-review-50-pending-20261021.jpg`.

La finalización pública depende de la aprobación de Apple; no se equipara el envío con publicación. No se ha creado un monitor ni una automatización de seguimiento. Esta actualización es evidencia de configuración externa y documentación: no aplica TDD unitario, y la comprobación sustitutiva es la selección guardada, la confirmación del envío, su detalle y la captura. No cambia código ni firma del binario 50.

Rollback: revertir el commit de metadatos devuelve el número base; el archivo firmado es un artefacto aparte. La reversión de Git no retira una compilación ya recibida por Apple ni revierte metadatos externos. La integración en `main` será un avance directo, sin reescribir historial remoto.
