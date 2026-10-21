# Entrega de Evolución — 21 de octubre de 2026

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

El paso pendiente exige autenticación de App Store Connect: la pestaña sigue mostrando el formulario de inicio de sesión de Apple. Se solicitó al usuario completarlo y se conserva la pestaña para continuar. No se ha retirado el envío anterior, asociado la 50, enviado una revisión nueva ni publicado la app. Cuando haya acceso, comprobar el estado real de la versión y la compilación, conservar los datos vigentes de revisión y completar el envío autorizado con publicación automática si sigue siendo la modalidad configurada.

Los artefactos de firma y los logs de distribución se conservan también en `~/.codex/recoveries/nido-20261021/store-50-20261021/`, fuera de Git. Ninguna clave privada se incorpora al repositorio. El commit documental posterior a `786d2b4` solo registra estos resultados y no cambia el binario recibido por Apple.

Rollback: revertir el commit de metadatos devuelve el número base; el archivo firmado es un artefacto aparte. La reversión de Git no retira una compilación ya recibida por Apple ni revierte metadatos externos. La integración en `main` será un avance directo, sin reescribir historial remoto.
