# Entrega de Evolución — 21 de octubre de 2026

El usuario autoriza expresamente crear commits, subirlos a `main` y publicar en App Store. Esta instrucción sustituye el límite anterior de no hacer commits ni publicaciones. No se han solicitado instalaciones en dispositivos físicos.

La fuente funcional validada conserva 248 pruebas Core, 32 pruebas del inventario y 245 ejecuciones de la app sin fallos ni omisiones; compilación Release correcta. La evidencia y el rollback funcional están en `evolution-health-plan-2026-10-20/sleep-hour-axis-2026-10-21.md`.

Se preparan dos unidades funcionales (dominio con sus pruebas; integración de las cinco métricas, fijados y navegación con sus pruebas y el inventario completo). La integración y el arnés comparten el contrato de selectores; separarlos dejaría el gate incompleto. Exceden el tamaño orientativo de revisión para conservar cada unidad utilizable. La petición de integración directa en `main` prevalece sobre abrir una cadena de PRs.

Los archivos locales de exploración, skills, capturas y logs voluminosos ajenos al código de la entrega se conservan sin incorporarlos en bloque a Git. Se incluye el fixture PNG necesario para las pruebas del menú.

## Candidato de distribución

Versión 0.1.0, compilación 50, tanto en la app como en Live Activity. Se conserva el bundle ID `com.momentumia.nido` y el equipo existente. La consulta pública española no devuelve una app publicada; el último envío documentado es 0.1.0 (49). La ficha autenticada deberá confirmar estado y disponibilidad del número antes de finalizar el envío.

Este cambio solo ajusta metadatos; no aplica TDD unitario. Validación sustitutiva: sintaxis del proyecto, coherencia de versión app/extensión, archive Release, firma, exportación y recepción/procesamiento por Apple. Los resultados de simulador anteriores no se presentan como validación física ni como aceptación de Apple.

Estado inicial de distribución: App Store Connect solicita inicio de sesión; se ha pedido al usuario completarlo mientras se prepara el archivo. La subida, el envío a revisión y la disponibilidad pública se documentarán por separado según la evidencia real.

Rollback: revertir el commit de metadatos devuelve el número base; el archivo firmado es un artefacto aparte. La reversión de Git no retira una compilación ya recibida por Apple ni revierte metadatos externos. La integración en `main` será un avance directo, sin reescribir historial remoto.
