# Nueva compilación de demostración — 16 de octubre de 2026

Estado: **Nido 0.1.0 (49) enviada a App Review; Apple muestra «Pendiente de revisión»**. No está aprobada ni publicada.

Envío confirmado el **16 de octubre de 2026 a las 09:51**, ID **`090d79c2-8c2c-454d-af24-94a59e3ab0af`**. La confirmación mostró «1 artículo enviado»; el [detalle de App Store Connect](https://appstoreconnect.apple.com/apps/6823152436/distribution/reviewsubmissions/details/090d79c2-8c2c-454d-af24-94a59e3ab0af) confirma versión 0.1.0 (49), fecha y estado «Pendiente de revisión».

El titular eligió precio gratuito en todos los países disponibles y una nueva compilación con demostración completa, sin compartir credenciales personales de Apple. La compilación objetivo es 0.1.0 (49).

## Metadatos ya comprobados

- App Store Connect conserva precio cero para 175 países o regiones. Tras navegar fuera y volver, el desglose actual muestra 0,00 USD, 0,00 EUR y 0,00 SAR en las regiones visibles; el calendario se configuró con la misma tarifa gratuita para todas las regiones.
- Disponibilidad guardada en los 175 países o regiones y los que Apple añada en el futuro. La página de disponibilidad muestra «Disponible al publicarse la app». Esto no publica la app.
- Los cuatro valores de compilación de app y extensión se cambiaron de 48 a 49; `plutil -lint` aprueba el proyecto. No aplica TDD unitario a estos metadatos; se sustituye por validación de configuración y comprobación posterior del binario firmado.

## TDD de la demostración

La fuente Swift canónica coincidía byte a byte con la fuente congelada de la compilación 48 antes de esta ampliación. No se trasladó a producción la variante DEBUG del recorrido Apple real.

- **Rojo UI observado antes de implementar**: el simulador iPhone 16 Pro alcanzó la pantalla de autenticación; falló la expectativa del botón `demo-start`, ausente. `xcodebuild` terminó con 65. El intento posterior de pulsar el botón inexistente también falló; se conservan ambos errores.
- Evidencia: `~/.codex/recoveries/nido-20261015/demo-release-20261016/ui-red.log` y `ui-red.xcresult`.
- **Rojo Core**: faltaban el transporte inyectable, el repositorio y los fixtures de demostración. El log también incluye un error de tiempo de comprobación de tipos dependiente de los símbolos ausentes; no se presenta como una aserción funcional ejecutada.
- **Verde Core inicial**: cuatro pruebas enfocadas y suite completa de 152 pruebas en 22 suites aprobadas. Logs `core-red.log`, `core-green-focused.log` y `core-suite.log` en el mismo directorio.
- **Corrección de aislamiento con TDD**: la revisión detectó DTO demo que, con el aislamiento `MainActor` del target iOS, no podían usarse desde el actor del repositorio. La compilación con esos ajustes reprodujo el error de conformidad `Encodable`; se marcaron los 13 DTO como `nonisolated`. El módulo productivo compila con los mismos ajustes. El target de pruebas del paquete con esa opción encuentra además un mock antiguo ajeno a la demo que no compila; se conserva ese límite en `core-mainactor-green-focused.log`, sin presentarlo como suite verde. Evidencias: `core-mainactor-red.log` y `core-mainactor-green-build.log`. La suite normal posterior vuelve a pasar 152/152.
- **Corrección de contrato con TDD**: una prueba roja reprodujo que el propietario demo podía aceptar una invitación pese a tener ya membresía y alteraba su estado. Se corrigió para devolver 409 y conservar la invitación, conforme al contrato real. Evidencia `core-join-red.log`; verde enfocado y suite completa posteriores aprobados.
- **Primeras ejecuciones UI**: entrada/salida, navegación entre pestañas e informe pasaron. Los intentos completos todavía fallaron por selectores del arnés: etiqueta exacta de «Pis», tipo de accesibilidad del campo multilínea, identificador numérico de una invitación y botón para cancelarla. Se corrigen los selectores siguiendo la interfaz existente, sin cambiar el producto para acomodar las pruebas ni quitar las aserciones sobre el resultado.
- **Invitación compartida, TDD**: `ui-review-red.log` reproduce la ausencia de aviso ficticio tras abrir la hoja de compartir. Se antepuso un aviso explícito al contenido compartido y la prueba reforzada con la frase completa pasó en `ui-green-attempt2.log` (23,576 s). No se seleccionó un destinatario ni se envió un mensaje.
- **Fixture de concurrencia descartado**: el primer escenario de autenticación pendiente mostraba un marcador, pero no activaba el `@State` real de la vista. Su fallo **no acredita un rojo válido del producto**. Se retiró el intento de corrección, se conectó el fixture DEBUG a los estados reales y se reinició el ciclo de pruebas para ambas direcciones de exclusión entre Apple y demo. Se preservan los intentos y su limitación; el nuevo resultado se registrará por separado.
- **Nuevo rojo de concurrencia válido**: `ui-auth-gates-red-valid.log` reproduce los dos botones indebidamente habilitados con los estados reales de la vista activos: Apple durante entrada demo (4,937 s) y demo durante finalización Apple (5,584 s). El desafío del fixture es sintético y no hubo acceso externo. Tras conservar ese resultado se aplicó la corrección definitiva de ambos controles; su verde consta en el siguiente punto.
- **Verde de concurrencia y compartir**: `ui-green-attempt3.log` aprueba las dos direcciones de exclusión (4,897 s y 5,434 s), la entrada/salida, el informe, las pestañas y los dos recorridos de invitación. Total del intento: siete pruebas aprobadas y dos fallidas. Estas dos últimas seguían usando el registro rápido como si fuera el formulario completo: pulsar «Pis» guardaba y cerraba la hoja antes de buscar la nota. Se corrigió el arnés para abrir «Añadir detalles» y conservar la selección; se ejecutan por separado creación/edición y reinicio antes de la suite completa.
- **Verde de creación, edición y reinicio**: `ui-edit-reset-green.log` y su xcresult aprueban los dos casos, con salida 0: creación/edición en 36,211 s y reinicio en 33,943 s. Con los siete aprobados del intento anterior quedan comprobados los nueve casos enfocados. La suite completa se está ejecutando en `full-suite.log`; todavía no se presenta como aprobada.

## Suite completa y rollback

`full-suite.log` termina con `TEST SUCCEEDED` y salida 0. La consulta independiente del resumen de `full-suite.xcresult` confirma **116 casos: 108 aprobados, 0 fallidos y 8 omitidos**, incluidos los nueve casos UI demo aprobados.

Las ocho omisiones son explícitas: una requiere activar Reduce Motion en el sistema; tres necesitan sesiones provisionadas contra un backend real; dos son auditorías generales de accesibilidad optativas con hallazgos históricos conservados; dos automatizan widgets en SpringBoard. La suite no acredita esos ocho escenarios.

Fuente de entrega en el repositorio local aislado `~/.codex/recoveries/nido-20261015/demo-release-20261016/native-git`, rama `codex/store-demo-49-20261016`: transporte `66d2678`, repositorio y pruebas `4991342`, integración UI con sus pruebas y metadatos 49 `533726b`. Cada unidad puede revertirse en orden inverso; volver al padre de `66d2678` retira toda la demo. No revierte el despliegue del backend ni los metadatos guardados en App Store Connect. No se ha publicado esta rama ni se ha modificado el historial del repositorio principal. Las dos últimas unidades superan el presupuesto orientativo de 400 líneas para conservar comportamiento y pruebas juntos.

## Archivo y firma

`archive-49.log` y `export-49.log` terminan respectivamente con `ARCHIVE SUCCEEDED` y `EXPORT SUCCEEDED`, salida 0. IPA exportada: `AppStoreExport/Nido.ipa`, 2.992.899 bytes, SHA-256 `874c02cf06a6f0f45c55a510c04680cf4fa4bf15c4871725ea88ceca52a399e7`.

La inspección independiente de la IPA y su extracción confirma versión 0.1.0 (49) e iOS mínimo 17.0 en app y Live Activity. Ambas pasan `codesign --verify --deep --strict` con salida 0; firma Apple Distribution de David Prados Mancilla, equipo `6VVEKN47Y3`. Los dos perfiles Store tienen `get-task-allow=false`, sin dispositivos provisionados ni distribución universal interna. El manifiesto incorporado coincide con el canónico de siete categorías, SHA-256 `6796a46761cee16620c8810008206acddc303feffaa88c150a5d497591080f23`.

La fuente de entrega está identificada por el commit y los hashes; el recurso opcional `BuildMetadata.plist` del archivo está vacío, por lo que no se atribuye al binario una revisión Git visible dentro de la app.

`upload-49.log` termina con salida 0, «Uploaded package is processing», «Upload succeeded», «Uploaded Nido» y `EXPORT SUCCEEDED` a las 09:45:53 del 16 de octubre de 2026 (hora local). Esto confirma recepción por Apple, no procesamiento terminado ni envío a revisión.

Posteriormente App Store Connect pidió información de exportación para la 49. Se respondió «Ninguno de los algoritmos mencionados anteriormente», conforme al uso de HTTPS, Keychain y SHA-256 del sistema, sin algoritmo propio añadido por la demo. Tras guardar, la 49 apareció «Lista para enviar». Se sustituyó la asociación de la 48 por la 49 sin eliminar la compilación anterior. Se guardaron las notas de `app-review-demo-notes-2026-10-16.txt` y se desmarcó «Es necesario iniciar sesión», coherente con el acceso demo Release comprobado. Tras recargar persistían la 49, la casilla en cero, el inicio de las notas y 2.883 caracteres restantes; «Guardar» desactivado. «Añadir a revisión» creó el borrador «Listo para revisión» con 0.1.0 (49). Después se pulsó «Enviar a revisión» y se verificaron la confirmación y el detalle del envío indicados al inicio.

## Recorrido Release

`release-simulator-build.log` termina en `BUILD SUCCEEDED`, salida 0, compilando la revisión limpia `533726b5e2c77085bb892670f3f28d6b2e7458cc`. Los 109 archivos nativos versionados coinciden byte a byte con la fuente canónica probada. Se instaló esta app Release sobre la instalación existente y se lanzó sin argumentos ni escenarios DEBUG. En el único iPhone 16 Pro autorizado se comprobó visualmente entrada sin Apple, banner persistente, inicio y fin de sueño, guardado de un cuidado, edición de una nota de sueño con confirmación «Registro actualizado», Historia con cinco registros tras las dos altas, Ajustes con familia ficticia, Ritmos, reinicio que restaura los 42 minutos iniciales y salida a la pantalla de autenticación. El informe y las invitaciones están cubiertos por las pruebas UI aprobadas; no se presentan como repetidos manualmente en Release. Los intentos de desplazamiento mediante la herramienta nativa no movieron la pantalla y no acreditan una comprobación manual adicional de esas zonas.

La demo usa un transporte en memoria y un grafo de estado independiente: no acepta credenciales reales ni cae a la red. Reutiliza las pantallas y formularios del producto con datos sintéticos. Aísla caché, preferencias, credenciales y estado de registros, y desactiva efectos sobre notificaciones, widgets y Live Activities reales. Permite entrar sin Apple, registrar y editar, consultar historial y ritmos, preparar informes, demostrar cuidados compartidos, reiniciar y salir.

La integración y sus nueve casos enfocados están aprobados. La revisión independiente comprobó el aislamiento y señaló los problemas de DTO, contrato de invitación, concurrencia y contenido compartido, corregidos con la evidencia descrita. El envío está confirmado; queda la decisión de Apple. La publicación automática tras aprobación permanece seleccionada, con precio gratuito en todas las regiones configuradas.

La documentación no tiene comportamiento ejecutable: no aplica TDD unitario. Se valida contrastando cada estado y resultado con sus logs y artefactos, sin convertir intentos fallidos en resultados aprobados.

La prueba [de borrado con Apple real](apple-real-deletion-result-2026-10-16.md) ya pasó en la cuenta local sin membresía y conserva sus límites. La demostración no simulará una revocación Apple real.
