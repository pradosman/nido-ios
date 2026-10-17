# Ficha de App Store — borrador para revisión

**Estado final vigente, 16 de octubre de 2026:** Nido 0.1.0 (49) **enviada a App Review y pendiente de revisión**, según comprobación directa de Store en el detalle de la solicitud. Fecha mostrada: 16 de octubre, 9:51. Identificador `090d79c2-8c2c-454d-af24-94a59e3ab0af`; [detalle en App Store Connect](https://appstoreconnect.apple.com/apps/6823152436/distribution/reviewsubmissions/details/090d79c2-8c2c-454d-af24-94a59e3ab0af). Store verificó tras recargar la asociación de 49, notas del demo guardadas y acceso requerido desmarcado porque el demo permite revisar sin Apple; confirmó «1 artículo enviado» y luego «Pendiente de revisión». **No está aprobada ni publicada.** Precio gratuito y disponibilidad 175 regiones/futuras guardados. Evidencia conservada: Core 152/152; suite nativa 116 casos, 108 aprobados, cero fallidos y ocho omitidos; nueve UI demo aprobadas; backend 67/67 con TDD previo. Las ocho omisiones y los hallazgos AX históricos siguen documentados. Apple real aprobado solo para cuenta aislada sin membresía, con revocación acreditada por el proveedor estricto y DELETE 200, sin captura HTTP Apple directa, nuevo acceso posterior ni dos cuidadores reales. Rollback: commits demo `533726b` → `4991342` → `66d2678` en orden inverso; backend conserva su imagen/parche/configuración de reversión. Ninguno recupera datos borrados ni restaura el grant Apple; tampoco retira automáticamente el envío o revierte ASC. Actualización documental sin cambio ejecutable: no aplica TDD unitario; se valida contra artefactos revisados y el estado ASC comunicado por Store. Los bloqueos y esperas siguientes son el historial previo a este resultado.

**Distribución 49 vigente, comprobación independiente:** logs con `ARCHIVE SUCCEEDED`, `EXPORT SUCCEEDED`, `Upload succeeded`, `Uploaded Nido` y `Uploaded package is processing`. IPA 0.1.0 (49), app/extensión mínimo iOS 17, 2 992 899 bytes, SHA-256 `874c02cf06a6f0f45c55a510c04680cf4fa4bf15c4871725ea88ceca52a399e7`. Manifiesto incrustado coincide con el canónico de siete tipos (`6796a467…080f23`). Store acredita firma Apple Distribution/equipo correcto y perfiles Store sin dispositivos ni depuración. Release de simulador ejecutado sin argumentos DEBUG: entrada demo, sueño/cuidados/edición/historial/ritmos/reinicio/salida comprobados; informe e invitaciones no se repitieron manualmente en Release, aunque pasan sus UI automatizadas. La revisión de fuente `533726b` se acredita por hashes de 109 archivos según Store, no por metadatos Git visibles en el binario. **Apple recibió 49 en procesamiento; todavía no se acredita procesado, seleccionado/asociado o enviado a revisión.**

**Resultado vigente de suite completa del demo 49:** log comprobado con `TEST SUCCEEDED`; resumen `xcresult`: 116 casos, 108 aprobados, cero fallidos y ocho omitidos. Los nueve casos UI demo pasan. Omisiones: una de Reduce Motion del sistema, tres de sesiones/backend provisionado, dos auditorías AX generales optativas y dos widgets en SpringBoard; no se acreditan por esta suite y se conservan los hallazgos AX históricos. Entrega local aislada: commits `66d2678` → `4991342` → `533726b`, sin push a main; rollback inverso de esas unidades retira demo, sin revertir backend ni ASC. Release para simulador sigue en verificación; aún no archivo/firma/subida/procesamiento/asociación de 49 ni envío. Notas de revisión demo redactadas localmente, todavía sin copiar a ASC.

**Último resultado enfocado del demo 49, según Store:** nueve casos aprobados mediante dos ejecuciones: siete en `ui-green-attempt3` y los dos de edición/reinicio en `ui-edit-reset-green`, tras corregir el arnés para abrir «Añadir detalles» y seleccionar de forma idempotente. Los dos fallos previos eran del arnés, sin cambio de producto para acomodarlos. Exclusión Apple/demo con estados reales y aviso completo de datos ficticios aprobados. La suite completa del esquema sigue ejecutándose; no se declara verde global. Aún no hay archivo 49 ni envío a revisión.

**Demo 49 en validación:** [checkpoint](demo-release-validation-2026-10-16.md) con Core 152/152 y compilación iOS correctos. Suite UI final en ejecución, aún sin verde definitivo, Release verificado, archivo ni carga/asociación de 49. Sin envío a revisión. Precio gratuito y disponibilidad 175 regiones/futuros países ya verificados por Store.

**Configuración comprobada por Store:** Gratis guardado y persistente; 175 regiones con precio 0 y disponibilidad «Disponible al publicarse», incluidos futuros países. No es publicación. Demo 49 en implementación con rojo UI válido por entrada ausente; metadatos app/extensión 49 validados en cuatro configuraciones. Sin archivo 49 ni envío a revisión todavía.

**Decisión vigente:** usuario eligió distribución gratuita en todos los países y nueva compilación con modo demo completo. Store prepara 49 mediante TDD y gestiona ASC. Configuración de precio/disponibilidad y demo Release operativo pendientes de verificación; todavía sin envío a revisión. No se aportan credenciales personales ni se presenta 48 como accesible sin autenticación.

**Estado de envío vigente, 16 de octubre:** el intento de «Añadir a revisión» está bloqueado por ASC: franja de precios válida, usuario y contraseña obligatorios. Notas SIWA en inglés guardadas y acceso requerido marcado; no hay credenciales ficticias ni envío. Store ya solicitó al usuario precio/disponibilidad y acceso mediante cuenta Apple dedicada de revisión o nuevo build con demostración completa. La prueba real de borrado está aprobada dentro de su alcance aislado sin membresía.

No publicada. Ficha **Nido · Sueño y lactancia** creada en [App Store Connect](https://appstoreconnect.apple.com/apps/6823152436/distribution/ios/version/inflight), identificador Apple `6823152436`, bundle `com.momentumia.nido`, versión `0.1.0`. Nombre elegido expresamente por el usuario. Texto promocional, descripción, palabras clave y subtítulo guardados; categoría principal «Estilo de vida», estado «En preparación para el envío». No enviada a revisión.

## Texto propuesto

**Subtítulo:** Sueño, tomas y cuidados

**Texto promocional:** Un lugar tranquilo para registrar el día a día de tu bebé y compartir los cuidados con las personas que lo acompañan.

**Descripción:**

Cada día con tu bebé tiene su propio ritmo. Nido te ayuda a reunir sus registros para consultar lo que ha pasado y continuar con sus cuidados.

- Registra el sueño, las tomas, los pañales y otros cuidados.
- Consulta el día en una cronología circular de 24 horas.
- Revisa días anteriores y edita los registros cuando lo necesites.
- Comparte el hogar con otros cuidadores mediante una invitación.
- Usa tamaños de texto accesibles y la preferencia del sistema para reducir el movimiento.

**Palabras clave:** bebé,sueño,lactancia,tomas,pañales,cuidados,familia,registro

**Novedades de la primera versión:** Primera versión de Nido para acompañar el registro diario de los cuidados del bebé.

## Plan de capturas y resultado del 16 de octubre

Solo se utilizará el simulador iPhone 16 Pro solicitado por el usuario. Las imágenes de tienda deben mostrar datos de demostración y el estado real de la versión que se vaya a distribuir.

1. Vista Hoy con el reloj y registros de ejemplo.
2. Registro de una toma.
3. Sueño en curso.
4. Historial de días anteriores.
5. Invitación a otro cuidador.

Store comunica las cinco escenas terminadas y aprobadas individualmente, con PNG originales 1206 × 2622 del iPhone 16 Pro y datos sintéticos. Ya están subidas a la ficha española y persisten como 5/10 tras recargar, en la ranura «iPhone con Dynamic Island (pantalla mediana)». Orden recibido: Toma, Cuidados compartidos, Historial, Sueño, Hoy; revisar el orden editorial antes del envío. No se han enviado a revisión. Véase [el estado de publicación](release-progress-2026-10-16.md).

Actualización posterior confirmada por Store: el orden ya quedó **Hoy, Toma, Sueño, Historial, Cuidados compartidos** y persiste tras recargar. El orden recibido anterior se conserva como histórico; no está pendiente volver a ordenarlas.

## Datos pendientes antes de enviar

- Clasificación por edades y declaraciones de la ficha general.
- URL pública y operativa de soporte.
- URL pública de la política de privacidad y declaración de datos contrastada con el servicio desplegado.
- Clasificación por edades, derechos de contenido y condición de comerciante confirmados por el titular.
- Cuenta de demostración e instrucciones de revisión que permitan a Apple probar la app.
- Firma de distribución y compilación subida con los flujos de API real verificados.

Actualización: Store confirma URLs de política y soporte públicas operativas y guardadas en ASC, y copyright guardado. Las siete categorías de privacidad están configuradas como borrador, sin publicar. Esos enlaces ya no están pendientes; sí la revisión final de declaraciones, contacto de App Review, acceso de prueba y distribución.

Actualización posterior del 16 de octubre: Store publicó App Privacy después de la confirmación del usuario y verificó su estado «Publicada» en ASC, con siete tipos y URL legal correcta. Supera el estado de borrador anterior. Esta publicación no es una subida binaria ni un envío a revisión de la app; distribución, contacto y recorrido real siguen pendientes.

Seguimiento del mismo día: el contacto App Review ya está completado y verificado tras recarga; no se copia el teléfono del titular a este documento. Siguen pendientes las dos cuentas Apple dedicadas y la distribución: el nuevo intento tras el aviso de cuenta añadida continúa con `No Accounts`/perfiles ausentes, sin IPA ni subida.

Estado posterior: **IPA de distribución exportado correctamente**, Nido 0.1.0 (48), con app y extensión firmadas y manifiesto de siete tipos verificado. Los fallos de cuenta/perfiles anteriores son históricos. La subida está iniciada por Store, sin recepción/procesamiento en ASC acreditados aún; no hay envío a revisión. El backend de borrado y su prueba real siguen pendientes.

Resultado posterior: **carga completada con código 0**, paquete 0.1.0 (48) recibido y en procesamiento de Apple. No se declara listo para testers, aprobado o enviado a revisión. La producción aún necesita el backend de borrado compatible y su recorrido real, aunque el cliente 48 ya sea compatible con el candidato validado.

Estado posterior vigente: la compilación 48 figura «Lista para enviar» y asociada a la versión. El [backend de borrado está desplegado](account-deletion-deployment-result-2026-10-16.md). Apple real en base aislada sin hogar: sesión 201, desafío reciente 201 y DELETE 200 comprobados en log; Store confirma pantalla de acceso y DB sin usuario ni sesión. La revocación se acredita por el proveedor real estricto revisado, que exige respuesta Apple 200 antes del éxito; sin captura HTTP directa. Hogares compartidos con dos identidades y nuevo acceso tras revocación no probados en este recorrido. Store prepara el envío; aún no se confirma su realización.

No se han respondido declaraciones legales ni de privacidad en nombre del titular. No se ha creado una cuenta de demostración en producción.

## Validación

Es contenido de tienda, por lo que no aplica TDD unitario. Se valida el límite de caracteres del subtítulo, texto promocional y palabras clave, la correspondencia con las funciones existentes y la ausencia de promesas de resultados médicos. El nombre ya fue elegido por el usuario; la publicación sigue pendiente.
