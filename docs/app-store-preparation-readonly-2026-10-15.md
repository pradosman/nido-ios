# Preparación de App Store: revisión de solo lectura

15 de octubre de 2026. Revisión coordinada con Store tras la autorización humana de continuar los cuatro pasos. No se han cambiado fuentes, cuentas, certificados, perfiles ni claves; no se han ejecutado compilaciones, simulador, cargas ni publicación.

## Firma comprobada localmente

- `security find-identity -v -p codesigning` devuelve una identidad válida: Apple Development de David Prados Mancilla. No devuelve una identidad Apple Distribution válida en los llaveros consultados. Esto no demuestra que no exista un certificado de distribución en la cuenta Apple o gestionado remotamente por Xcode.
- El proyecto configura firma automática, equipo `6VVEKN47Y3`, bundle principal `com.momentumia.nido` y extensión `.liveactivity`, versión `0.1.0`, build `48` en ambos productos.
- El archivo conservado en `~/.codex/recoveries/nido-20261015/final-accessibility-16pro-20261015/Nido-unsigned.xcarchive` sigue sin firma: `codesign -dv` indica «code object is not signed at all» y la app no contiene `embedded.mobileprovision`. Es el archivo Release comprobado previamente; no se ha reconstruido para esta revisión.
- No se ha registrado una clave, emitido un certificado, instalado un perfil ni activado capacidades. El estado remoto de las claves no queda verificado.

## Ficha y sesión Apple

El documento existente [Ficha de App Store](app-store-es.md) registra una ficha creada para **Nido · Sueño y lactancia**, Apple ID `6823152436`, bundle `com.momentumia.nido`, versión `0.1.0`, textos guardados y estado de preparación. El nombre ya está aprobado por el usuario; no requiere una nueva elección.

La visita inicial de este chat redirigió al formulario de inicio de sesión, con `authResult=FAILED`. **Ese bloqueo ya está superado:** Store comunica que ha recuperado la sesión con una llave de acceso existente y ha comprobado la ficha 6823152436, el nombre aprobado, la versión 0.1.0 en preparación y el texto promocional, descripción y palabras clave guardados. No se ha registrado una clave nueva para recuperar el acceso.

En la primera lectura de Store estaban vacíos soporte, copyright, contacto y revisión, sin build asociado. **Actualización posterior comunicada por Store:** URL de soporte y política guardadas con las rutas legales de Nido, y copyright `2026 David Prados Mancilla` guardado y verificado. El cuestionario App Privacy sigue en «Comenzar», sin rellenar. Contacto, revisión, build y capturas no tienen una nueva confirmación de completado. Safari queda reservado a Store; este chat incorpora su comprobación comunicada sin UI paralela. Una URL guardada no demuestra por sí sola la respuesta HTTPS pública.

El borrador local contiene subtítulo de 23 caracteres, texto promocional de 117 y palabras clave de 60. Son recuentos reproducibles del archivo; no sustituyen el formulario remoto. Se ha corregido únicamente la frase local que dejaba pendiente la aprobación del nombre, porque contradecía la elección humana ya registrada; no se ha cambiado el nombre ni la ficha remota.

## Capturas y material

El plan local sigue pendiente de cinco escenas con datos de demostración: Hoy, toma, sueño en curso, historial e invitación. Se mantiene la restricción del usuario de utilizar únicamente iPhone 16 Pro.

Una búsqueda con `rg --files --hidden` de PNG/JPEG en `docs/`, `ios/` y `~/.codex/recoveries/nido-20261015/`, filtrando nombres de App Store, screenshots o capturas, no localizó un conjunto de imágenes de tienda identificado. No prueba que no existan imágenes con otros nombres, adjuntos de `.xcresult` o capturas remotas; las capturas de diagnóstico tampoco se consideran material final de tienda. No se han generado ni subido imágenes, porque el simulador está reservado por Store.

Plan concreto para preparar después de fijar la candidata y recibir el turno:

| Archivo previsto | Escena real que debe mostrar | Preparación y revisión |
|---|---|---|
| `01-hoy.png` | Hoy con el dial y varios registros legibles | Hogar y bebé sintéticos; combinar sueño, toma y pañal. Comprobar que los datos y las horas coinciden entre dial y lista. |
| `02-toma.png` | Formulario de registro de una toma | Datos de demostración, tipo y detalle coherentes; botones y campos completos, sin teclado tapando la acción principal. |
| `03-sueno.png` | Sueño en curso | Un único sueño sintético activo y duración coherente; mostrar el estado de la versión real, sin fabricar funciones ni mediciones. |
| `04-historial.png` | Consulta de un día anterior con registros | Fecha anterior al día de captura, datos del mismo hogar sintético y texto legible. |
| `05-cuidados-compartidos.png` | Flujo real de invitación a un cuidador | Usar un hogar de demostración y evitar exponer una invitación funcional, contactos reales o credenciales. Elegir la pantalla real disponible al revisar el flujo. |

Condiciones comunes: solo iPhone 16 Pro, español, apariencia coherente, versión/build identificados y datos sintéticos. Antes de exportar se comprobarán dimensiones y ranuras admitidas por App Store Connect; no se afirma que las cinco imágenes o el tamaño nativo del dispositivo basten por sí solos para todas las ranuras. Este plan no incluye capturas generadas ni subidas.

## Datos de revisión pendientes

| Campo o material | Estado y dato que falta |
|---|---|
| URL de soporte | Store confirma guardada `https://nido.momentumia.com/api/nido/legal/support`. Comprobación HTTPS y contenido del despliegue a cargo de Store; no se ha rellenado desde este chat. |
| Política de privacidad | Store confirma guardada `https://nido.momentumia.com/api/nido/legal/privacy`. El cuestionario de datos sigue en «Comenzar»; su mapa de preparación no constituye respuestas guardadas. |
| Copyright | Store confirma guardado `2026 David Prados Mancilla`. No es ya un campo pendiente de texto. |
| Contacto de revisión | Actualización de Store: los cuatro campos ya están guardados y verificados tras recarga, incluido el teléfono facilitado por el usuario. No se copia el número a este documento ni a Git. Se conserva solo el estado completado. |
| Acceso para revisión | Falta un procedimiento ejecutable compatible con el Apple Sign In de Release: cómo iniciar sesión, crear o acceder al hogar sintético y repetir las funciones sin depender del modo DEBUG. No se entrega una cuenta personal ni se inventan credenciales. |
| Notas de revisión | Preparar pasos reales: acceso, alta del hogar/bebé, registrar/editar/borrar, historial, invitación y eliminación de cuenta. Deben corresponder al backend efectivamente desplegado; el borrado/revocación todavía lo valida Store en su unidad propia. |
| Build | No hay uno asociado según Store. Firma de distribución, carga y procesamiento siguen pendientes; no se ha subido ni seleccionado ninguno desde este chat. |
| Declaraciones generales | Estado remoto aún no confirmado: edades, privacidad, derechos de contenido, comerciante y cifrado. Requieren respuestas fieles del titular; no se completan por suposición. |

## Qué falta comprobar

1. Mantener la sesión recuperada de Store y contrastar los campos aún no confirmados, material y declaraciones; el acceso ya no es un bloqueo actual.
2. Resolver la firma de distribución y los perfiles de app/extensión con el equipo correcto; el archivo sin firma no sirve como evidencia de carga aceptada.
3. Preparar y revisar las cinco escenas de tienda cuando Store libere el turno y la versión candidata esté fijada, usando datos sintéticos y dimensiones admitidas verificadas antes de exportar.
4. Completar las declaraciones de privacidad, edades, contenido, comerciante y cifrado con el titular, y el acceso e instrucciones de revisión.
5. Incorporar los resultados del despliegue legal y del backend de borrado, de los que Store conserva la responsabilidad. Esta revisión no los despliega ni presume completados.

## Resultado legal posterior a la revisión inicial

Store documenta el [despliegue legal completado](legal-deployment-result-2026-10-15.md): política y soporte HTTPS 200 con `no-store`; salud 200, API privada 401, raíz 404. Se recreó solo la API, preservando los IDs de los otros 17 contenedores remotos y sin migraciones. Esto supera el pendiente de disponibilidad de las páginas, conservando como históricos los pasos de preparación anteriores.

Las URLs de soporte y privacidad y el copyright ya están guardados en ASC según Store. El cuestionario App Privacy permanece sin rellenar; su mapa requiere revisión de categorías y tratamiento de soporte/logs. Ni las páginas publicadas ni esa ficha parcial cierran la corrección y despliegue del borrado/revocación Apple, la firma de distribución, el material de tienda o la revisión. Falta integrar el parche legal permanentemente en Git. No se han ejecutado estas acciones desde este chat.

## Recurso de privacidad actualizado por Store

El manifiesto canónico ya contiene siete tipos tras aplicar Store el parche validado. Lectura independiente: SHA-256 `6796a46761cee16620c8810008206acddc303feffaa88c150a5d497591080f23`, idéntico al candidato; cuatro declaraciones originales conservadas y tres nuevas, Other Data Types, Product Interaction y Contacts. Mapa, recurso, parche y validación están preservados en `~/.codex/recoveries/nido-20261015/privacy-seven-metadata-20261015/`.

**Actualización del 16 de octubre:** el nuevo archivo ya se generó en `~/.codex/recoveries/nido-20261015/store-release-privacy-20261015/Nido-unsigned.xcarchive`, con `ARCHIVE SUCCEEDED`. Lectura independiente del manifiesto incrustado: siete tipos e igualdad byte a byte con el canónico. Los archivos previos de cuatro tipos siguen siendo históricos.

La exportación local falla por perfiles ausentes de app y extensión; el intento automático también devuelve `No Accounts`, ambos código 70. El archivo sigue sin firmar y no se ha subido. La sesión de Safari recuperada no resuelve por sí sola la configuración de cuentas de Xcode. El cuestionario ASC no se ha publicado por este cambio. Este chat solo ha leído la evidencia y actualizado documentación, sin editar otro manifiesto ni ejecutar builds.

Estado en esa fase: el agente de Store preparaba cinco capturas reales. **Actualización posterior:** [el informe del 16 de octubre](release-progress-2026-10-16.md) confirma cinco escenas aprobadas individualmente, PNG originales 1206 × 2622 con datos sintéticos y cinco capturas persistentes tras recarga en la ficha española. Las imágenes están en la ranura «iPhone con Dynamic Island (pantalla mediana)». Orden recibido: Toma, Cuidados compartidos, Historial, Sueño, Hoy; falta revisar el orden editorial. No se ha repetido esta comprobación desde la UI de este chat.

Las siete categorías de App Privacy están ahora configuradas en borrador, con funcionalidad, vínculo a identidad y sin seguimiento; **no publicadas**. Los estados anteriores «sin rellenar» se conservan como históricos. Quedan teléfono de App Review, dos cuentas Apple dedicadas al recorrido real, creación de la clave de borrado y cuenta/perfiles de Xcode. No hay exportación de distribución, TestFlight o envío a revisión. El cambio legal conserva commit `f56c9dd` y PR borrador 1, sin merge; el backend nuevo de borrado tiene validación local 67/67 y aún no está desplegado.

Actualización posterior de Store: capturas reordenadas y persistentes como **Hoy → Toma → Sueño → Historial → Cuidados compartidos**. La clave SIWA de borrado **ya fue creada y protegida**; staging está separado y sin activar. Se elimina la necesidad de crear otra clave, conservando el pendiente de despliegue coordinado y prueba real. Véase [la revisión independiente de privacidad](app-store-privacy-review-2026-10-16.md): sin omisión demostrable o contradicción bloqueante en el alcance examinado, con límites de soporte/logs y sin certificación general o publicación.

**Estado posterior vigente:** Store ya publicó el cuestionario de siete tipos tras la confirmación expresa del usuario y verificó en ASC «Publicada hace unos segundos por David Prados Mancilla», con la URL legal correcta. Los estados de borrador anteriores son históricos. No se ha publicado una app binaria, subido a TestFlight ni enviado a revisión. Siguen pendientes Xcode/cuenta/perfiles, teléfono App Review, dos cuentas Apple dedicadas y despliegue/prueba real del backend de borrado; Store ya está pidiendo esos datos, sin duplicar la solicitud desde este chat.

Actualización posterior: **contacto App Review completado y persistente tras recarga**; no se guarda el teléfono en los informes. Sigue pendiente la ubicación de dos cuentas Apple dedicadas. Tras comunicar el usuario que añadió la cuenta a Xcode, la nueva exportación `export-account-added-20261016` sigue fallando con código 70, `No Accounts` y perfiles ausentes de app/extensión. Store aclara el estado de Apple Account/equipo frente a las identidades de control de versiones, sin negar el reporte del usuario ni dar la configuración por terminada. No hay IPA o subida; este chat no usa la interfaz ni repite el intento.

**Actualización posterior: firma resuelta.** Xcode ya reconoce cuenta y equipo; `export-team-confirmed-20261016` terminó con código 0 y produjo `Nido.ipa` 0.1.0 (48). Store validó Apple Distribution y perfiles Store para app/extensión; la lectura independiente del IPA confirma bundles/build y el manifiesto de siete tipos idéntico al canónico. Los errores de exportación anteriores son históricos, no el bloqueo actual.

Store inició la subida, cuyo resultado aún no está confirmado en esta revisión. No se acredita build recibido/procesado en ASC, TestFlight ni envío a revisión. Continúan el contraste de contrato cliente/backend y el despliegue del borrado con su prueba real; no se utiliza la interfaz ni se lanzan jobs en paralelo desde este chat.

**Resultado posterior de la carga:** código 0 y mensajes «Uploaded package is processing», «Upload succeeded» y «Uploaded Nido» en el log. El paquete **0.1.0 (48) ya está recibido y en procesamiento**, sin acreditar aún procesamiento final, testers, aprobación o envío a revisión. El cliente 48 es compatible con el candidato 67 según la revisión de Store; producción aún no incorpora el borrado sin hogar ni la prueba/revocación Apple del contrato nuevo. El backend sigue sin desplegar y necesita configuración protegida completa y entrega coordinada. No se inicia otra carga ni se usa la UI desde este chat.

## Estado posterior vigente: backend desplegado y prueba real pendiente

**Estado final vigente, 16 de octubre de 2026:** Nido 0.1.0 (49) **enviada a App Review y pendiente de revisión**, según comprobación directa de Store en el detalle de la solicitud. Fecha mostrada: 16 de octubre, 9:51. Identificador `090d79c2-8c2c-454d-af24-94a59e3ab0af`; [detalle en App Store Connect](https://appstoreconnect.apple.com/apps/6823152436/distribution/reviewsubmissions/details/090d79c2-8c2c-454d-af24-94a59e3ab0af). Store verificó tras recargar la asociación de 49, notas del demo guardadas y acceso requerido desmarcado porque el demo permite revisar sin Apple; confirmó «1 artículo enviado» y luego «Pendiente de revisión». **No está aprobada ni publicada.** Precio gratuito y disponibilidad 175 regiones/futuras guardados. Evidencia conservada: Core 152/152; suite nativa 116 casos, 108 aprobados, cero fallidos y ocho omitidos; nueve UI demo aprobadas; backend 67/67 con TDD previo. Las ocho omisiones y los hallazgos AX históricos siguen documentados. Apple real aprobado solo para cuenta aislada sin membresía, con revocación acreditada por el proveedor estricto y DELETE 200, sin captura HTTP Apple directa, nuevo acceso posterior ni dos cuidadores reales. Rollback: commits demo `533726b` → `4991342` → `66d2678` en orden inverso; backend conserva su imagen/parche/configuración de reversión. Ninguno recupera datos borrados ni restaura el grant Apple; tampoco retira automáticamente el envío o revierte ASC. Actualización documental sin cambio ejecutable: no aplica TDD unitario; se valida contra artefactos revisados y el estado ASC comunicado por Store. Los bloqueos y esperas siguientes son el historial previo a este resultado.

**Distribución 49 vigente, comprobación independiente:** logs con `ARCHIVE SUCCEEDED`, `EXPORT SUCCEEDED`, `Upload succeeded`, `Uploaded Nido` y `Uploaded package is processing`. IPA 0.1.0 (49), app/extensión mínimo iOS 17, 2 992 899 bytes, SHA-256 `874c02cf06a6f0f45c55a510c04680cf4fa4bf15c4871725ea88ceca52a399e7`. Manifiesto incrustado coincide con el canónico de siete tipos (`6796a467…080f23`). Store acredita firma Apple Distribution/equipo correcto y perfiles Store sin dispositivos ni depuración. Release de simulador ejecutado sin argumentos DEBUG: entrada demo, sueño/cuidados/edición/historial/ritmos/reinicio/salida comprobados; informe e invitaciones no se repitieron manualmente en Release, aunque pasan sus UI automatizadas. La revisión de fuente `533726b` se acredita por hashes de 109 archivos según Store, no por metadatos Git visibles en el binario. **Apple recibió 49 en procesamiento; todavía no se acredita procesado, seleccionado/asociado o enviado a revisión.**

**Resultado vigente de suite completa del demo 49:** log comprobado con `TEST SUCCEEDED`; resumen `xcresult`: 116 casos, 108 aprobados, cero fallidos y ocho omitidos. Los nueve casos UI demo pasan. Omisiones: una de Reduce Motion del sistema, tres de sesiones/backend provisionado, dos auditorías AX generales optativas y dos widgets en SpringBoard; no se acreditan por esta suite y se conservan los hallazgos AX históricos. Entrega local aislada: commits `66d2678` → `4991342` → `533726b`, sin push a main; rollback inverso de esas unidades retira demo, sin revertir backend ni ASC. Release para simulador sigue en verificación; aún no archivo/firma/subida/procesamiento/asociación de 49 ni envío. Notas de revisión demo redactadas localmente, todavía sin copiar a ASC.

**Último resultado enfocado del demo 49, según Store:** nueve casos aprobados mediante dos ejecuciones: siete en `ui-green-attempt3` y los dos de edición/reinicio en `ui-edit-reset-green`, tras corregir el arnés para abrir «Añadir detalles» y seleccionar de forma idempotente. Los dos fallos previos eran del arnés, sin cambio de producto para acomodarlos. Exclusión Apple/demo con estados reales y aviso completo de datos ficticios aprobados. La suite completa del esquema sigue ejecutándose; no se declara verde global. Aún no hay archivo 49 ni envío a revisión.

**Checkpoint demo 49:** [informe leído](demo-release-validation-2026-10-16.md): Core normal 152/152 y compilación iOS correctos; implementación terminada según Store, suite UI final de nueve pruebas en curso. Fixture inicial de concurrencia inválido descartado, nuevo rojo válido de ambos controles Apple/demo conservado; no se declara verde UI. Revisión independiente, Release, archivo y carga/asociación pendientes; sin envío. La variante del target de pruebas con MainActor tiene el límite del mock antiguo documentado; no se confunde con la suite normal aprobada.

**Último avance de Store:** precio 0 persistente tras navegación; 175 regiones con precio y disponibilidad «Disponible al publicarse», incluidos futuros países. Demo 49 con rojo UI válido por `demo-start` ausente, código 65 conservado; implementación en curso. Metadatos app/extensión 49 en cuatro configuraciones y `plutil` correcto, sin TDD unitario aplicable a metadatos. Sin archivo 49 ni envío a revisión. La configuración de precio/disponibilidad antes pendiente queda resuelta según Store.

**Decisión posterior vigente:** usuario eligió Gratis en todos los países y nueva compilación con modo demo completo. Store prepara 49 con TDD y gestiona precio/disponibilidad; aún no se acreditan configuración guardada, demo Release operativo ni envío. No se usan credenciales personales ni se cambia falsamente el requisito de acceso de 48. Las preguntas de decisión anteriores quedan resueltas; implementación y verificación pendientes.

**Bloqueo posterior vigente:** al intentar añadir a revisión, ASC exige franja de precios válida y usuario/contraseña de revisión. No hay envío. Notas SIWA en inglés guardadas y acceso requerido marcado, sin credenciales ficticias. Store ya pidió precio/disponibilidad y decidir cuenta Apple dedicada para revisión o nuevo build con demostración completa. No se repiten preguntas aquí. La prueba real de borrado aprobada sigue válida en su alcance.

**Resultado posterior vigente:** Apple real y borrado en la base aislada sin membresía completados. Log comprobado independientemente: sesión 201, desafío reciente 201, DELETE 200. Store confirma pantalla de acceso y cero filas en usuarios/sesiones/cuidadores/hogares/perfiles/registros/autorías. Código y hash revisados: el proveedor real exige exchange/revoke Apple 200 antes del éxito; no existe captura directa HTTP de Apple. No se acreditan hogares compartidos con dos identidades ni un nuevo acceso tras revocación. Preparativos de revisión en curso por Store, sin confirmar envío. Los bloqueos que siguen son históricos.

Último avance de Store: contraseña completada, acceso Apple real con POST de sesión 201 y onboarding. Base aislada: un usuario, una sesión, cero cuidadores y cero hogares. «Eliminar definitivamente» abierto; Store espera la confirmación solicitada antes del borrado y revocación. Sin DELETE, revocación o envío a revisión todavía. Rama real prevista: sin membresía. Esto supera los estados anteriores de contraseña pendiente.

El build 48 ya fue procesado, figura «Lista para enviar» y está asociado a la versión según Store. [El backend de borrado se desplegó](account-deletion-deployment-result-2026-10-16.md): API saludable, cinco variables validadas, código coincidente con el candidato 67/67 y otros 17 contenedores intactos. Commit `a0433fe...` conservado en rama de entrega, sin push/main; configuración personalizada y material privado separados de Git. Los estados anteriores «sin desplegar» y «en procesamiento» son históricos.

La comprobación pública independiente obtiene salud 200, API privada 401, legales 200/no-store, raíz 404 y POST de desafío 201, sin guardar valores. No acredita acceso, DELETE o revocación Apple reales. El usuario confirmó su sesión del simulador y Store la verificó visualmente. El flujo Apple real ya abre su diálogo de autorización para Nido, que solicita una contraseña adicional; Store pidió completarlo directamente allí. Sigue pendiente ese paso antes del acceso API y del borrado en la base local vacía. No se borra el hogar de producción ni se envía la app a revisión hasta verificar el recorrido. No se repiten preguntas ni se usan UI, VPS o simulador en paralelo desde este chat.

Este informe es documental: no aplica TDD unitario. Lo sustituyen las consultas de solo lectura de identidades y firma, inspección del proyecto, recuento de textos, búsqueda acotada de archivos, observación del formulario real de acceso y las actualizaciones posteriores atribuidas a Store. No se han repetido las suites anteriores. Revertir esta unidad documental consiste en retirar este informe y su enlace de la auditoría, sin tocar estado externo.
