# Cierre de calidad de Nido — 15 de octubre de 2026

Documento histórico. La entrega posterior del rediseño, el backend desplegado y la consolidación de Git se describen en [la entrega premium del 17 de octubre](premium-design-release-2026-10-17.md). Los estados y recuentos de los apartados siguientes corresponden a sus ejecuciones originales.

Estado: **pendiente de cierre y publicación de la app**. [Estado actualizado del 16 de octubre](release-progress-2026-10-16.md). Las páginas legales ya se han [desplegado y verificado en producción](legal-deployment-result-2026-10-15.md) tras la autorización posterior del usuario. No se ha subido una versión binaria a Apple ni desplegado el backend nuevo de borrado. Los apartados siguientes conservan las evidencias históricas y sus límites.

Seguimiento posterior: [accesibilidad y preparación legal](accessibility-and-legal-followup-2026-10-15.md). El resumen del dial ya tiene un área accesible real y dejó de repetir su descripción: TDD con dos rojos correctos, cinco verdes enfocados y suite posterior de **107 casos, 100 correctos, siete omitidos y ningún fallo** en el iPhone 16 Pro. El paquete legal se preparó de forma aislada sobre la revisión real de producción y después se publicó con verificación HTTPS. Las incidencias generales del auditor siguen separadas del resultado funcional.

La evidencia vigente está en ese seguimiento: archivo Release posterior aprobado y candidato legal con **48/48** pruebas, incluidas las de PostgreSQL real. Las cuatro auditorías `.all` posteriores siguen fallando, pero ya identifican todos sus elementos, sin `nil`. Los apartados siguientes conservan los resultados históricos de las cohortes anteriores; sus menciones a 105 casos o elementos sin identificar no describen la última repetición.

Comprobación remota adicional por SSH durante el cierre: los enlaces públicos `/api/nido/legal/privacy` y `/api/nido/legal/support` devuelven ambos **HTTP 404** en `nido.momentumia.com`. Las rutas locales y los contratos aprobados todavía necesitan despliegue y verificación pública; los enlaces de Ajustes no se consideran operativos en producción.

La auditoría adicional encontró un defecto visible en modo claro: «Sin registros este día» usaba el color secundario translúcido del sistema. Se reprodujo con una prueba UI que coloca la etiqueta dentro del área visible: **rojo, un fallo exclusivamente por «Contrast nearly passed»**; después de usar `readableSupportingInk`, **verde, una prueba correcta sin omisiones**. La auditoría general `.all` conserva su manejador sin filtros; la prueba nueva comprueba únicamente el contraste de esa etiqueta y no acredita el resto de la pantalla. Evidencia preservada en `/Users/pradosman/.codex/recoveries/nido-20261015/final-contrast-16pro-20261015/contrast-{red,green}.xcresult`. La repetición completa posterior sobre `/tmp/nido-final-contrast-16pro-20261015` pasó: **105 casos, 98 correctos, 7 omitidos, ningún fallo**, exclusivamente en el iPhone 16 Pro. `full-suite.xcresult` y su resumen están en la misma recuperación; Reducir movimiento estaba habilitado y se restauró al terminar. La copia de trabajo conserva 84 archivos seleccionados: los 83 legibles coinciden con el proyecto canónico y App Intents sigue sin poder verificarse por iCloud (`source-verification.json`).

El límite de rollback de este arreglo es una línea de color en `TodayView.swift` y el nuevo archivo `DayTimelineActivityContrastUITests.swift`. No se ha creado un commit para esta unidad; no debe confundirse con los cambios compartidos anteriores.

Se conservó además `contrast-fix.patch` con únicamente esa línea y la nueva prueba. `git apply --reverse --check` pasa contra el proyecto canónico: valida el límite reversible sin aplicar la reversión ni tocar los cambios compartidos.

Widgets posteriores al arreglo: **2/2 pruebas correctas, cero fallos y cero omisiones** en el mismo iPhone 16 Pro. Se comprobó añadir el widget pequeño desde la galería del sistema y usar las apariencias tintada y transparente. Evidencia: `final-contrast-16pro-20261015/widgets.xcresult` y `widgets-summary.json` dentro de la recuperación. Es una ejecución separada de los siete casos omitidos en la suite general.

La repetición de los cuatro diagnósticos nativos `.all` sobre esa misma cohorte ejecutó **cuatro casos, cuatro fallos, cero omisiones**. El aviso «Contrast nearly passed» de la etiqueta vacía visible ya no aparece; permanecen los demás avisos de contraste y los cuatro de Dynamic Type descritos abajo. No se han filtrado ni marcado como aprobados. Nueva evidencia: `final-contrast-16pro-20261015/audit-scroll{0,1}.xcresult`, sus resúmenes, registros y capturas exportadas. El código del producto no cambió durante esta repetición.

El diagnóstico enfocado de «Actividad del día» ejecuta claro y oscuro: claro no devuelve un aviso para ese texto, pero oscuro falla. En el recorte del propio auditor, los glifos recurrentes son RGB `(184,189,181)` —683 píxeles— sobre fondo dominante `(19,20,19)`: contraste medido **9,6595:1**, superior a 4,5:1. El cálculo reproducible está en `measure-visible-caption-contrast.py`, junto a `visible-caption-contrast.xcresult` y sus capturas. Es una discrepancia entre esa medición y el auditor, no motivo para cambiar otro color sin evidencia. Los cuatro avisos con elemento `nil` solo aportan capturas completas, sin recorte ni marco: siguen sin atribución y no se consideran resueltos.

El diagnóstico adicional de Dynamic Type sí pasó: **1/1, sin omisiones**, cambiando el ajuste real del simulador de Large a Accessibility XXXL mientras la app seguía abierta, sin forzar el tamaño desde SwiftUI. Alturas medidas dentro de la tarjeta: Hoy **24 → 65,67 pt**; Ver todo **44 → 58,67 pt**; Actividad del día **14,33 → 51,33 pt**; Sin registros este día **18 → 116,67 pt** con salto de línea. Los cuatro elementos siguieron accesibles individualmente. Se conservan ocho capturas y `live-dtype.xcresult` en la recuperación final. Esto demuestra el cambio entre esos dos tamaños, sin acreditar todos los tamaños intermedios ni convertir la auditoría `.all` en verde. El primer intento consultaba un texto hijo inexistente dentro del botón Ver todo: se conserva como `live-dtype-fixture-failure.*`, un error del diagnóstico, no un rojo de producto ni TDD.

Limpieza adicional de caché inactiva: se retiraron únicamente `Build`, `Index.noindex` y `ModuleCache.noindex` de `/tmp/nido-privacy-derived-20261015`, comprobando que el proceso de compilación activo usaba otra carpeta. `TestResults` y `Logs` siguen en su ubicación; los registros se copiaron además a `privacy-derived-logs` en la recuperación final. La eliminación terminó correctamente sin modo forzado; no se tocaron fuentes ni resultados. El espacio disponible después de esta fase era aproximadamente 3,7 GiB, sujeto al intercambio de memoria.

Diagnóstico general anterior a ese arreglo, sin filtros (las cuatro pruebas fallaron):

| Apariencia / scroll | Contraste | Dynamic Type |
| --- | --- | --- |
| Oscuro / 0 | Actividad `y770,5`, Sin registros `y819,67` | Sin avisos |
| Claro / 0 | Los anteriores, Ver todo `y742,67` y un elemento sin identificar | Sin avisos |
| Oscuro / 1 | Elemento sin identificar, Registrar sueño `y89,17`, Iniciar `y83,5`, Actividad `y620,5` | Hoy, Ver todo, Actividad y Sin registros |
| Claro / 1 | Dos elementos sin identificar, Registrar sueño e Iniciar; Sin registros `y669,67` casi supera contraste | Los mismos cuatro elementos |

El viewport acaba en `y735`: los textos de scroll 0 quedan cubiertos por el botón o las pestañas. Registrar sueño e Iniciar, con scroll 1, quedan bajo la navegación `y62–116`; los recortes respectivos muestran fondo, sin sus glifos. Esto no resuelve los elementos sin identificar, el aviso de Actividad oscuro / 1 ni los avisos de Dynamic Type. El texto vacío claro / 1 sí era visible y motivó la corrección TDD anterior. Registros completos y capturas: `final-integrated-16pro-20261015/audit-scroll{0,1}.*` dentro de la recuperación. Estas comprobaciones diagnósticas no cambian comportamiento y no requieren un nuevo ciclo TDD.

Punto de control anterior al arreglo final de contraste: la suite completa integrada pasó en el simulador iPhone 16 Pro: **104 casos, 97 correctos, 7 omitidos por configuración y ningún fallo**. La prueba de Reducir movimiento sí se ejecutó y pasó. Los tres flujos con servidor de esa cohorte pasaron por separado, sin omisiones. También pasaron 148 pruebas del núcleo en 20 suites y 77 contratos del servidor, sin omisiones. Los diagnósticos nativos de accesibilidad y la galería/apariencia de widgets se ejecutan aparte; sus resultados se indicarán expresamente. No se ha publicado ni firmado una versión de distribución.

La evidencia reciente y la copia de trabajo están conservadas mediante clones locales en `/Users/pradosman/.codex/recoveries/nido-20261015/native-deletion-checkpoint-20261015/`. Es un punto de control pendiente de validación final, no una versión lista para publicar. El usuario ya autorizó coordinar también Design Spells y limpiar únicamente cachés regenerables. Sigue pendiente la creación de la clave Apple preparada. El usuario ya confirmó los datos públicos legales y de soporte en el chat de la guía de App Store; su publicación aún no está verificada aquí.

## Coordinación y recuperación del entorno

Los chats «Instala skill de SwiftUI» y «Revisa mejoras de Design Spells» liberaron el simulador y congelaron sus cambios. La primera cohorte `/tmp/nido-final-16pro-20261015` se copió de la integración de Design Spells; sus 80 archivos relevantes legibles coincidían con el proyecto. La cohorte posterior probada es la de contraste, descrita al principio. Se verificó además el mensaje humano que autoriza coordinar los cuatro chats y se comunicó el turno exclusivo a «Revisa la guía para App Store». El archivo original `NidoRegistrationIntents.swift` sigue sin poder leerse por su estado de descarga de iCloud; el candidato conservado contiene las dos inyecciones revisadas del servicio de sueño compartido. No se afirma equivalencia byte a byte de ese archivo original ni se lo ha sobrescrito.

La limpieza conservó fuentes, copias de seguridad, registros y resultados: se retiraron tres carpetas temporales de compilación inactivas de Design Spells después de copiar sus registros, la caché de descargas de Homebrew y dos cachés de módulos inactivas de Xcode. La caché de npm y los datos de Docker permanecen intactos.

El consumo continuado coincidía con muchas instancias locales de Hostinger que tenían los mismos comandos: 311 procesos raíz y 622 procesos en sus árboles, con 11,63 GiB de memoria residente agregada. Se terminaron instancias tras revalidar usuario, proceso padre, fecha de inicio y comando, conservando una por cada uno de los diez servidores; quedaron 20 procesos y unos 109,5 MiB. El intercambio usado bajó de 24.593 a 13.142 MiB y el espacio libre subió de 546 MB a 12,36 GB. No se cambió la configuración del conector ni se ejecutaron operaciones remotas desde este trabajo. Estas medidas acreditan el consumo y su reducción; no demuestran que cada instancia correspondiera al mismo cliente MCP, porque varios chats pueden necesitar conexiones independientes.

Estas comprobaciones de entorno y documentación no modifican comportamiento de Nido: no aplica TDD unitario. Se validan con inventarios, procesos verificados y medidas antes/después conservados en `/Users/pradosman/.codex/recoveries/nido-20261015/`.

La suite del núcleo pasó: **148 pruebas en 20 suites, sin fallos ni omisiones**, salida 0; registro `/tmp/nido-final-core-20261015.log`. El núcleo no cambió con la corrección posterior de color. Esta verificación de pruebas existentes no añade un nuevo ciclo TDD. La interfaz y los flujos con servidor terminaron después con los resultados finales descritos al principio, por turnos exclusivos en el iPhone 16 Pro.

La primera corrida final con servidor ejecutó tres casos: **dos correctos, uno fallido, ninguno omitido** (`/tmp/nido-final-api-three-20261015.xcresult`). El fallo es la ausencia del aviso de reautenticación tras retirar acceso al cuidador; las comprobaciones HTTP 401 y la vuelta al inicio de sesión sí pasaron. Se verificó que `prepareAppleSignIn()` limpia `notice` al recibir el desafío. La hipótesis adicional del temporizador general de tres segundos fue descartada en revisión: pertenece a `MainTabView`, que desaparece al entrar en autenticación, y comprueba la cancelación antes de borrar el aviso. No se modificará ese temporizador sin un fallo reproducido. Se conserva la expectativa literal del mensaje. La suite amplia iniciada a continuación se detuvo de forma controlada para corregir el fallo confirmado con TDD antes de repetir la cohorte completa; su resultado interrumpido no se cuenta como aprobado ni como fallo funcional.

El arreglo del aviso completó un ciclo TDD verificable en iPhone 16 Pro. El primer rojo mostró `notice=nil` frente al mensaje esperado (`nido-auth-notice-store-red-20261015.xcresult`). La revisión amplió el caso a credencial Apple revocada y a no arrastrar el motivo al siguiente inicio correcto: cuatro pruebas produjeron dos fallos por esas razones exactas (`nido-auth-notice-semantic-red-20261015.xcresult`). Después se sustituyó la clasificación por texto por estado explícito de reautenticación: **4/4 correctas**, y **7/7 correctas en la clase completa**, sin omisiones (`nido-auth-notice-semantic-green-20261015.xcresult` y `nido-auth-notice-semantic-all7-20261015.xcresult`). También se comprueba que un reintento correcto elimine un error transitorio de preparación.

La integración canónica se hizo mediante seis fragmentos de `NidoStore` y los cambios revisados de pruebas; `RootView` no cambió. Copias anteriores: `/Users/pradosman/.codex/recoveries/nido-20261015/auth-notice-before-merge/`. La cohorte `/tmp/nido-final-integrated-16pro-20261015` incorpora además los enlaces de privacidad y soporte: sus **82 archivos relevantes legibles coinciden con el proyecto**, y el archivo App Intents original sigue sin poder verificarse por iCloud. El manifiesto de 83 archivos está en `final-integrated-16pro-20261015/native-source-manifest.json` dentro de la recuperación. La comprobación UI añadida de permanencia del mensaje durante cuatro segundos es una ampliación de regresión y se validó en la repetición con servidor real descrita a continuación.

La repetición integrada con servidor ya pasó: **3/3 casos correctos, sin omisiones**, incluido el mensaje de revocación visible después de cuatro segundos (`nido-final-integrated-api-three-20261015.xcresult`). También terminó la suite completa del servidor sobre la cohorte de contratos integrada: **77/77 contratos correctos, sin omisiones**, con los casos de PostgreSQL real habilitados y una base desechable PostgreSQL 17.10. La compilación y migración correspondientes terminaron correctamente. El contenedor propio fue eliminado comprobando su etiqueta; los siete servicios existentes permanecen activos, seis con estado saludable y uno sin comprobación de salud configurada. Registros y fuentes conservados en `final-integrated-16pro-20261015/` dentro de la recuperación.

El manifiesto de privacidad incorporado en la app Debug compilada está presente y su contenido coincide con el del candidato; también pasan las validaciones de sintaxis de las tres listas de propiedades. No es todavía una validación de firma o distribución de la versión de App Store.

Al detener temporalmente la protección reaparecieron los duplicados del conector y el espacio volvió a bajar a 318 MiB, antes de iniciar las pruebas de API. Se pausó su lanzamiento y se restauró una única protección temporal con límite máximo de 90 minutos: diez árboles conservados y espacio recuperado a más de 6 GiB. Esta mitigación mantiene las pruebas posibles; no constituye una corrección permanente de las reconexiones del conector.

Codex interrumpió posteriormente la sesión y cambió su proceso anfitrión. Antes de reanudar se verificó que no hubiera compilaciones ni ejecutores de pruebas activos y que solo estuviera encendido el iPhone 16 Pro autorizado. Se preparó `/tmp/nido-final-16pro-v2-20261015` para el nuevo ciclo TDD del aviso; la cohorte anterior y sus resultados siguen intactos. El vigilante anterior ya no estaba activo: se inició uno solo para el nuevo proceso anfitrión, con la misma lista limitada y caducidad de 90 minutos. Sus medidas iniciales pasaron de 116 a diez instancias del conector, con unos 16,9 GB libres. Evidencia: `/Users/pradosman/.codex/recoveries/nido-20261015/runtime-hostinger-guard/resume-61724/`.

Ese vigilante terminó antes de su plazo al superar cinco segundos una consulta de procesos; el registro de salida confirma `TimeoutExpired`, no una señal de parada. Se mantiene apagado mientras se verifica la identidad por cliente: limitar únicamente por comando podría provocar reconexiones de chats legítimos. El espacio seguía por encima de 14 GiB al detectar este límite; no se presenta la mitigación temporal como una reparación permanente del conector.

## Alcance comprobado

Se han aplicado las guías de Emil a contraste, respuesta de controles, movimiento reducido, jerarquía y tamaños de texto. Las comprobaciones de interfaz se limitan al simulador **iPhone 16 Pro**, iOS 26.5, identificador `516B4FA1-D8C4-4389-9836-79095056D5CB`, conforme a la petición del usuario.

Cambios: colores de tarjetas activas y filtros con contraste legible; transición del centro del reloj desactivada con Reducir movimiento; corrección del tamaño de prueba AX5; encabezado estable, reloj sin comprimir y acción «Registrar» compacta con texto grande; lista de actividad vertical para evitar textos truncados; retirada del encabezado de fecha invisible del árbol de accesibilidad.

La revisión de código de la cohorte integrada también comprobó las nuevas interacciones de registro: expansión del formulario breve, selección de cuidados y respuesta de avisos usan transiciones de 180–250 ms condicionadas por Reducir movimiento. La transición de fase conserva su condición de movimiento reducido y la respuesta háptica se emite desde el evento central. Esta revisión de implementación no sustituye la repetición final de interfaz ni acredita una prueba en hardware físico.

## Evidencia TDD y comprobaciones

Los registros y resultados siguientes están en `/tmp`; conservarlos fuera de esa carpeta antes de limpiar el equipo.

| Cambio | Rojo conservado | Verde enfocado |
| --- | --- | --- |
| Contraste de tarjetas | `nido-polish-red2-20261015`: ocho fallos de contraste reales | `nido-polish-ax5-dark-green-20261015`: 13 pruebas correctas |
| Reducir movimiento | `nido-polish-motion-red3-20261015`: similitud 0,963562 frente al mínimo 0,995 | Incluido en la verificación enfocada y la primera suite completa |
| Tamaño AX5 y filtro | `nido-polish-extra-red-20261015` | `nido-polish-ax5-dark-green-20261015` |
| Orden, reloj y botón con texto grande | `nido-close-accessibility-layout-red-20261015`: reloj de 167,83 pt frente a 279; botón de 187,335 pt frente al máximo 110; encabezado fuera de orden | `nido-close-accessibility-layout-green2-20261015`: cuatro pruebas de disposición correctas |
| Texto completo de actividad | `nido-close-caption-rendered-regression-20261015`: OCR no encuentra «Actividad del día» en AX5 porque aparece truncado | `nido-close-caption-layout-green-20261015`: ocho combinaciones de tamaño, apariencia y contraste; crecimiento y acceso correctos |
| Fecha invisible | `nido-close-date-accessibility-red2-20261015`: la fecha sigue presente al salir de pantalla | `nido-close-date-native-green3-20261015`: prueba específica correcta; las auditorías nativas generales siguen fallando |

El primer intento de prueba de fecha ejecutó cero casos y **no constituye evidencia roja**. Los intentos intermedios fallidos se conservan y no se han sustituido por expectativas más débiles.

La primera suite completa anterior a los últimos cambios tuvo **67 casos: 60 correctos, 7 omitidos, ningún fallo** (`nido-polish-complete-16pro-20261015.xcresult`). No sustituye a la suite final de los cambios posteriores.

La primera repetición con 72 casos detectó tres incidencias: reloj parcialmente oculto con sueño activo, desplazamiento insuficiente antes de pulsar el botón de edición y un error de captura de accesibilidad del sistema. Se conservan en `nido-close-complete-16pro-20261015.xcresult` (62 correctos, 3 fallos, 7 omitidos). El encabezado activo ahora omite la fecha redundante y conserva la fecha completa en accesibilidad; la prueba de edición exige colocar el botón entero dentro del área visible. No se han rebajado sus expectativas. Generalizar ese desplazamiento a la pulsación larga produjo un intento fallido; se restauró su helper original y se limitó el cambio al botón de edición.

**Suite integrada verificada antes del nuevo borrado Apple: 79 casos, 72 correctos, 0 fallos, 7 omitidos**, `/tmp/nido-five-full-frozen.xcresult`. Incluye los 72 casos anteriores y siete de la pasada SwiftUI coordinada. Los omitidos son tres flujos con API externa, dos auditorías nativas optativas y dos pruebas de SpringBoard optativas; no se contabilizan como aprobados. Esta fuente quedó congelada antes del nuevo flujo de reautorización Apple y no valida sus cambios posteriores.

Verificaciones de lógica: 136 en la pasada inicial y **145 en 19 suites** en la pasada SwiftUI congelada (`nido-five-core-final.log`), seguidas de **148 en 20 suites** en la integración final. **7 pruebas del soporte del entorno API correctas** (`nido-close-api-harness-node-final.log`). Galería de widgets y apariencia tintada/traslúcida se comprobaron por separado en el mismo simulador.

La integración nativa de borrado añadió pruebas HTTP enfocadas antes de corregir el envío de credenciales, la aceptación indebida de `deleted:false` y el tiempo máximo de espera. La prueba de cancelar la hoja de Nido se añadió después del prototipo: es una prueba de regresión y no demuestra cancelación de la autorización del sistema Apple.

Las nuevas pruebas de carrera sí reprodujeron fallos antes de modificar las protecciones de sesión, en el iPhone 16 Pro autorizado:

- `/tmp/nido-account-deletion-fence-red5.log`: una respuesta DELETE antigua cambiaba la fase y borraba el token de una nueva sesión Apple; un caso ejecutado, dos fallos de aserción.
- `/tmp/nido-account-deletion-challenge-red2.log`: se devolvía una autorización pendiente de la sesión anterior después de cambiar de cuenta; un caso ejecutado, un fallo de aserción.
- `/tmp/nido-account-deletion-logout-red.log`: el cierre de sesión antiguo borraba la credencial de una nueva sesión; un caso ejecutado, un fallo de aserción.

La primera prueba nueva denominada AX5 utilizó por error `UICTContentSizeCategoryAccessibility5`. Su fallo del botón de reintento de 15,04 pt frente a 44 pt acredita el problema en tamaño normal, **no** una comprobación AX5. La repetición usa el valor real `UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge`, sin contabilizar el intento anterior como accesibilidad máxima verificada. La suite final 105 incluye verdes tanto de tamaño accesible como del mínimo táctil normal.

Las tres pruebas de carrera pasaron después de las protecciones de generación/token; cancelar la hoja de Nido también pasó (`/tmp/nido-account-deletion-focused-green.log`). Esa ejecución conjunta conserva un fallo del botón de reintento, por lo que no se presenta como una suite completamente verde. La repetición con configuración AX5 válida pasó su comprobación inicial (`/tmp/nido-account-deletion-ax-red2.log`, pese al nombre del registro), pero la captura posterior mostró título, explicación y reintento truncados. `isHittable` era insuficiente para demostrar texto completo: se está reforzando esa expectativa antes de corregir la disposición. El botón en tamaño normal se reprodujo además con categoría Large válida: 42,2488 pt frente a 44 pt (`/tmp/nido-account-deletion-standard-ax-red.log`).

La lógica de la copia integrada anterior a las nuevas mejoras de Design Spells pasó **147 pruebas en 20 suites**, `/tmp/nido-final-core-integrated-20261015.log`, salida 0. Este resultado incluye el nuevo modelo de prueba Apple y la pasada SwiftUI anterior; no acredita cambios concurrentes posteriores de otro chat.

## API real y equivalencia de fuentes

El entorno local usa PostgreSQL desechable y la API real, con usuarios sintéticos y sesiones de prueba. No demuestra inicio de sesión real con Apple. Dos ejecuciones finalizaron con un flujo correcto y dos fallos del soporte de prueba: selección de fecha civil frente al identificador UTC del calendario y sustitución del texto con el teclado. Las expectativas funcionales se mantienen.

La tercera ejecución quedó interrumpida y produjo un resultado incompleto: no es una ejecución válida. La repetición final integrada posterior pasó tres de tres, como se detalla al principio.

Después de coordinar el simulador se obtuvo otra ejecución limpia de tres casos: alta independiente correcta y dos expectativas del soporte obsoletas (`nido-close-real-api-ui-20261015-final.xcresult`, 1 correcto/2 fallos). La fecha incluía un año ausente de la etiqueta real; ahora el formateador reproduce el de la app. Tras revocar al cuidador, la app ya mostraba la pantalla Apple y el mensaje de volver a iniciar sesión, como exige un token invalidado; la prueba esperaba erróneamente introducir una invitación sin reautenticar. Se mantiene el HTTP 401 y se exige Apple, mensaje de reautenticación, ausencia de invitación y ausencia de Historia. Hace falta repetir los tres casos con estas correcciones.

El siguiente intento falló durante la compilación por falta de espacio (`ENOSPC`), antes de ejecutar las pruebas; no aporta un resultado de los tres casos. Se retiraron exclusivamente cachés de compilación propias e inactivas, conservando fuentes, registros, resultados y archivos. Docker se recuperó mediante su parada forzada y arranque oficiales; los siete servicios Supabase existentes volvieron a estar activos. Se eliminó únicamente el contenedor temporal del entorno UI tras comprobar su etiqueta de propietario. Las siguientes compilaciones se realizan de una en una en el iPhone 16 Pro autorizado.

Backend actualizado: **67/67 pruebas sin omisiones, con PostgreSQL 17.10 real y compilación correcta**, `nido-revocation-compose-full-pg-final-20261015.log`; el handler de borrado se comprobó además con el driver real en 11/11 casos. Véanse [borrado sin hogar](account-deletion-verification.md) y [revocación Apple](apple-account-revocation.md). Las pruebas usan proveedor Apple simulado; no demuestran canje/revocación reales.

Las unidades de servidor se validaron además contra la revisión base, excluyendo los cambios previos de sueño compartido: **57/57** para borrado/revocación y **59/59** al añadir configuración, sin fallos ni omisiones, con PostgreSQL temporal propio. Registros: `/tmp/nido-backend-unit-a-pg-validation-20261015.log` y `/tmp/nido-backend-units-ab-pg-validation-20261015.log`. Sus compilaciones independientes también finalizaron correctamente.

La copia local de API tiene un manifiesto de 43 entradas en `/tmp/nido-api-e2e/source-manifest.sha256`. La ruta de incorporación de cuidadores procede del índice porque iCloud impedía leer el archivo actual; coinciden tamaño y fecha, pero no se ha verificado su contenido actual byte a byte. Esto limita la equivalencia demostrada del entorno.

## Compilación y publicación

La [copia cifrada y recuperación de producción](production-recovery-verification-2026-10-15.md) ya se ha comprobado: restauración aislada, migraciones y API con HTTP 200 de salud y 401 sin autenticación. Producción no se ha modificado.

Archivo de dispositivo sin firmar generado correctamente: `/Users/pradosman/.codex/recoveries/nido-20261015/Nido-20261015-final.xcarchive`. Registro: `/tmp/nido-close-archive-final-20261015.log`, `ARCHIVE SUCCEEDED`. Identificador `com.momentumia.nido`, versión `0.1.0`, compilación `48`; firma y equipo vacíos. **No es un paquete listo para subir**.

También se conservó el archivo posterior `Nido-20261015-release-candidate.xcarchive` y su registro `/tmp/nido-close-archive-candidate-20261015.log`. Incluye las cuatro categorías de datos recogidos del manifiesto de privacidad comprobadas en el paquete. Ambos archivos preceden a la integración final del nuevo borrado Apple y no sustituyen el archivo actualizado siguiente.

Archivo actualizado posterior a la suite 105: `final-contrast-16pro-20261015/Nido-unsigned.xcarchive` dentro de la recuperación, con `ARCHIVE SUCCEEDED` en `release-archive.log`. Bundle `com.momentumia.nido`, versión `0.1.0`, compilación `48`, arquitectura arm64 y mínimo iOS 17; firma y equipo vacíos. El manifiesto incrustado pasa `plutil -lint` y coincide con el de la fuente probada: cuatro categorías de datos recogidos y una categoría de API de motivo obligatorio, UserDefaults `CA92.1`. No está firmado para distribución ni preparado para subir. Esta validación del paquete no cambia comportamiento: no aplica un nuevo TDD unitario; la sustituyen compilación Release, validación del plist y comparación del manifiesto.

App Store Connect dispone ahora de una sesión autenticada. Tras el rechazo de «Nido» por estar ocupado, el usuario eligió **Nido · Sueño y lactancia**. Se ha creado la ficha Apple `6823152436`, bundle `com.momentumia.nido`, versión `0.1.0`, y guardado los textos españoles; sigue «En preparación para el envío». Véase [contenido de tienda](app-store-es.md). No enviada a revisión.

Dokploy está en Hostinger. Los nueve servidores del MCP están configurados, pero sus herramientas no se exponen en esta sesión. Después de que el usuario pidiera expresamente usar SSH, se comprobó el acceso con la clave existente y verificación estricta de la identidad del servidor. No se han mostrado claves ni valores de secretos.

Inspección SSH de solo lectura: servicio `nido-nido-wuwhrr-nido-1` saludable, PostgreSQL 17.10 saludable, código remoto en `main` revisión `b6a8f58bfcf99c0029e5698652e2dc25f29cf1c7`. `compose.vps.yml` tiene una modificación previa que debe preservarse. Están presentes las variables `NIDO_APPLE_AUDIENCE`, `NIDO_AUTH_BUCKET_SECRET` y las de PostgreSQL. No aparecen variables de clave privada/equipo para revocación Apple en el contenedor. Esta inspección no acredita que no existan credenciales en otro almacén. No se ha modificado producción.

En Apple Developer está preparado el registro de una clave exclusiva de Sign in with Apple para Nido, pendiente de la confirmación solicitada para crear y guardar esa credencial. Todavía no se ha registrado ni descargado. El usuario confirmó expresamente como responsable a David Prados Mancilla y como contacto público a pradosman@gmail.com en «Revisa la guía para App Store». Esos datos sustituyen el bloqueo de información pendiente; falta verificar las páginas y su configuración publicada. No se publicarán valores provisionales.

## Pendientes que impiden declarar terminado

- Resolver o atribuir con evidencia los hallazgos restantes de las auditorías nativas `.all`, en especial los cuatro sin elemento. Los verdes enfocados y las mediciones de píxeles se mantienen separados de los cuatro diagnósticos generales fallidos.
- Completar la configuración de revocación Apple y probar el flujo real con dos cuentas Apple. Los contratos y las pruebas con identidades sintéticas no sustituyen ese escenario. La creación de la clave preparada sigue pendiente de la confirmación solicitada.
- Verificar los originales que iCloud mantiene sin descargar, especialmente App Intents; las fuentes probadas y conservadas no acreditan equivalencia byte a byte de esos originales.
- Cerrar las unidades locales posteriores de Git preservando los cambios compartidos. El arreglo de aviso y el último contraste tienen parches reversibles comprobados; no se afirma que ya estén en un nuevo commit aislado.
- Desplegar y comprobar los enlaces públicos de privacidad y soporte que actualmente devuelven 404; completar firma de distribución, ficha/material de tienda y publicación. Véase también la [auditoría de lanzamiento](app-store-launch-audit-2026-10-15.md).

La suite final 105, los tres flujos con API, los dos widgets, las pruebas de acceso al borrado sin hogar y el nuevo archivo Release ya tienen evidencia positiva descrita arriba. Las pruebas terminadas dejan únicamente el iPhone 16 Pro encendido, aspecto claro, texto Large y Reducir movimiento desactivado; no queda ningún `xcodebuild` activo.

La revisión independiente y visual del diagnóstico claro confirmó que el elemento «Actividad del día» señalado está en `y=770,5…784,83`, por debajo del ScrollView que termina en `735` y detrás del botón fijo `735…783`; su recorte adjunto contiene exclusivamente el fondo del botón, sin glifos. Esto acredita una atribución a contenido recortado para **ese** aviso. No justifica ocultar contenido desplazable a VoiceOver. Los avisos `element=nil` siguen sin causa demostrada. La instrumentación conserva `.all` y `return false`, adjunta captura/árbol/geometrías y ya se ejecutó en ambas posiciones y apariencias con los resultados indicados arriba.

## Límites de rollback y documentación

Commits locales del cierre visual y del servidor, sin push:

- `16d4d0a4d557e5496a5d6b9d236529dc5a7ab539`: acción compacta y prueba real del tamaño AX5; 4 rutas.
- `8984dfb5c48f3cb857edcc1e52b6aee8dafaccdc`: contraste, movimiento y disposición accesible con pruebas; 8 rutas.
- `d52a128161665736868ad01e733a82063ac4d1f7`: categorías de privacidad y validación documental; 2 rutas.
- `19e749de36338ad183f407f9530d2528ab954d84`: borrado con prueba Apple reciente, revocación y reparación de cuentas sin hogar, con contratos y documentación; 10 rutas.
- `b96e17a938c3f24a8343218b7e7cedd009aea027`: configuración obligatoria de revocación Apple, plantilla sin secretos y validación; 6 rutas.

Se comprobó la cadena desde `97c6efc`, ausencia de cambios preparados y conservación de todas las entradas/flags del índice. El proceso no escribió archivos de trabajo ni incluyó los cambios previos de sueño compartido, la pasada SwiftUI o el nuevo borrado Apple.

Límite de rollback: deshacer primero `d52a128`, después `8984dfb` y por último `16d4d0a`, revisando los conflictos del árbol de trabajo antes de cualquier reversión. No restablecer globalmente el proyecto. Los cambios de fecha invisible dependen del desvanecimiento previo y permanecen sin incluir en esos commits. Candidatos, copia del índice y comprobación de rutas: `/Users/pradosman/.codex/recoveries/nido-20261015/commit-candidates/isolated-index-hmvnerae/`.

Las dos unidades de servidor posteriores se revierten en orden `b96e17a` → `19e749d`, cada una completa y conservando los cambios ajenos. El contrato HTTP de borrado y el cliente nativo deben desplegarse o revertirse coordinadamente. Sus fuentes y manifiestos aislados están bajo `commit-candidates/backend-account-revocation/`, `backend-revocation-config/` y `backend-isolated-index-1p0kxm9m/` en la misma recuperación. No se ha realizado push ni despliegue.

El análisis de dependencias de la unidad nativa, conservado como evidencia local en `native-apple-deletion-isolation-dag.md` dentro de la recuperación del 15 de octubre, identifica pruebas y servicios previos todavía mezclados en el árbol de trabajo de aquel momento. No se forzó un commit nativo incompleto; su historial TDD previo no queda demostrado por una suite de regresión posterior. Este antecedente no describe la entrega consolidada posterior, enlazada al inicio del documento.

Este informe es documentación: **no aplica TDD unitario**. Su validación consiste en contrastar recuentos, rutas, resultados y limitaciones con los registros conservados. Se actualizará con los resultados finales antes de la entrega.
