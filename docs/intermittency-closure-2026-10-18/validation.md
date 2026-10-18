# Correcciones y diagnóstico — registro y sesión

**Estado: cierre parcial.** Las correcciones de sesión tienen reproducciones causales y pruebas verdes. El menú pasa su cobertura ampliada, pero su causa histórica no está demostrada. La suite completa conserva una intermitencia adicional al seleccionar una fecha en el calendario; no se declara una validación íntegramente verde.

## Alcance

Cerrar las dos incidencias conservadas tras Nido luminoso: selección de una acción del menú de registro que no abre su destino y desaparición del motivo de reautenticación después de revocar el acceso. Base de trabajo: `3e8f4ffa2134218f5f4c8e4e7f8795d61c11005b`, rama `codex/nido-premium-design`.

## Criterio de cierre

- Reproducción causal antes de modificar producción, con resultados rojos conservados.
- Corregir únicamente la causa demostrada, conservando las expectativas de registro y revocación.
- Comprobar cargas repetidas y concurrentes, nueva sesión y cierre de sesión como contrajemplos del aviso.
- Comprobar selección con un solo toque, destino correcto, cierre y reapertura del menú para las categorías pertinentes; repetir recorridos sin reiniciar el simulador entre ellos.
- Ejecutar los casos enfocados, las suites completas correspondientes y compilación Release; revisión independiente de los cambios y de la evidencia.
- No atribuir fallos al estado del simulador únicamente porque desaparezcan al borrarlo.

## Evidencia

Los resultados de la entrega anterior siguen conservados en `docs/nido-luminoso-2026-10-18/validation.md`; no se sustituyen por las nuevas ejecuciones.

### Sesión: reproducción causal

Antes de editar producción se añadió `testLoadWithoutCredentialPreservesAccountRevocationNotice`. La primera carga recibe la revocación; la siguiente, sin credenciales, debe mantener su explicación. Resultado rojo verificado directamente: `/tmp/nido-auth-notice-red-2026-10-18.xcresult`, 1 prueba fallida y cero omisiones. El valor real fue `nil` frente a `Vuelve a iniciar sesión para acceder.`. El fallo demuestra que la ruta de `load()` sin credenciales podía borrar el aviso; no depende del estado acumulado del simulador.

### Sesión: limpieza antigua frente a un inicio nuevo

La prueba `testLatePrivateDataCleanupCannotClearANewAppleSession` controla la suspensión de la limpieza: pausa la respuesta 401 antigua, completa un inicio nuevo y libera la limpieza anterior. En `/tmp/nido-auth-cleanup-red-v2-2026-10-18.xcresult` falla porque, aunque la credencial persistida sigue siendo `new-nido-session`, la sesión en memoria queda ausente y la fase vuelve a autenticación en vez de onboarding. El callback antiguo podía invalidar el estado de la sesión nueva antes del fence posterior al `await`.

Esta prueba se añadió después del primer borrador de la protección; se retiró esa protección para reproducir el fallo anterior. Es evidencia de regresión y comparación contra la implementación previa, no TDD rojo primero. El intento anterior agotó la espera por un fixture incorrecto y no cuenta como rojo de producto. La prueba del aviso descrita arriba sí se escribió y ejecutó antes de modificar producción.

La revisión independiente rechazó el primer guard basado en una generación pendiente global: podría consumir la notificación equivocada si una revocación real de la sesión nueva llegase antes que el callback antiguo. No se entrega ese guard.

Se añadió y ejecutó antes del cambio final una prueba causal distinta: `testStoreOwnedSessionInvalidationDoesNotReenterEventHub`. Resultado rojo en `/tmp/nido-auth-eventhub-red-2026-10-18.xcresult`: la limpieza iniciada por el Store volvía a emitir una invalidación por EventHub. La solución final separa ambos orígenes: el Store elimina su credencial y usa `clearHouseholdData()` para limpiar el hogar; las invalidaciones externas siguen entrando por EventHub. Revisión de paridad: ambos caminos eliminan las mismas cachés, estado persistido y claves heredadas; la carga de credenciales lee Keychain, sin caché independiente de SessionProvider. Se mantienen la limpieza de memoria, datos del bebé, widgets y actividades en vivo, con protección de generación ante cambios de sesión.

El test anterior de callback tardío se sustituyó por la comprobación de que la limpieza propia no emite ese callback: la solución evita la notificación redundante completa, en vez de filtrar su llegada. Se mantienen las expectativas de sesión nueva y revocación externa real como contrajemplos del test final. No se relajaron las expectativas de estado o credenciales.

La primera tanda enfocada pasó 5/5 en `/tmp/nido-auth-final-focused-2026-10-18.xcresult`. Después se reforzó el caso de no-reentrada con una nueva sesión y su revocación externa real. La clase completa final pasó **15/15, sin omisiones**, en `/tmp/nido-auth-dismiss-final-focused-2026-10-18.xcresult`, incluyendo las protecciones de descarte automático descritas abajo.

### Menú

La prueba nueva `testRegistrationMenuSupportsConsecutiveSelectionsAndCancellation` pasó sobre producción sin cambios: `/tmp/nido-registration-menu-red-2026-10-18.xcresult`, 1/1. El nombre del bundle no determina el resultado: este caso es una comprobación de regresión, no una reproducción roja del fallo histórico. Se instrumenta además el caso exacto FreshInstallation para observar posición y estado antes y después del toque, manteniendo sus aserciones.

La captura histórica sitúa el toque en `(257,754)`, centro de la fila `{{132,733},{250,42}}`; el menú seguía abierto y el destino no apareció. No hay evidencia para atribuirlo a coordenadas erróneas, al simulador o a una carrera concreta de SwiftUI. Se conserva el fallo original y no se introduce una modificación especulativa de navegación.

La prueba de regresión recorre categorías, selección con un solo toque, cancelación y reapertura. Las esperas observan que el botón sea interactuable después de cerrar una hoja; no repiten el toque. Pasó cinco ejecuciones consecutivas sobre el mismo simulador acumulado, sin borrado ni reintentos: `/tmp/nido-registration-menu-iterations5-2026-10-18.xcresult`. El resumen de Xcode agrupa las repeticiones como una prueba lógica; `/tmp/nido-registration-menu-iterations5-test.log` conserva `Iteration 1 of 5` a `5 of 5` y `Executed 5 tests, with 0 failures`, 315,249 s.

También pasó el contexto combinado de menú, Dynamic Island, galería real de widgets y apariencias de widgets: **4/4** en `/tmp/nido-menu-stress-context-v2-2026-10-18.xcresult`. La integración final con API pasó **3/3** en `/tmp/nido-menu-accum-api-3-final-2026-10-18.xcresult`, incluyendo el aviso visible de acceso revocado. La repetición y la instrumentación aportan cobertura y diagnóstico, pero **la causa del fallo histórico del menú sigue sin demostrarse**.

Las trazas nuevas se compilan únicamente en DEBUG y registran categorías, destinos y presencia de estados, sin contenido de avisos ni datos del bebé. Una integración anterior registró acción→hoja en 71 ms; ese recorrido correcto no demuestra la causa de un fallo previo.

### Descarte automático: reproducción causal

La primera integración acumulada volvió a perder el aviso de revocación pese al verde enfocado del primer arreglo: `/tmp/nido-menu-accum-api-1-2026-10-18.xcresult`, 2/3. Registro de hogar e historial pasaron. Por eso no se dio por cerrada la incidencia.

Se separó el punto de entrada automático del cierre manual conservando inicialmente su lógica incondicional y añadiendo trazas DEBUG. Antes de añadir protección se escribieron y ejecutaron tres casos. `/tmp/nido-auth-auto-dismiss-red-2026-10-18.xcresult`: 3/3 fallaron y cero omisiones. El descarte automático borraba el motivo de reautenticación, un aviso que había sustituido al original y el aviso/registro necesario para deshacer una creación o eliminación.

El temporizador debe capturar su mensaje original y, al completarse, comprobar que la app siga lista, que el mensaje coincida, que no sea una explicación protegida y que no exista una acción pendiente de deshacer. El cierre manual conserva su semántica. Esta reproducción demuestra el defecto de descarte obsoleto; la atribución de un fallo UI concreto requiere sus trazas, no se deduce solo del verde posterior.

Un cuarto rojo aisló la fase de navegación antes de añadir los guards: `/tmp/nido-auth-ready-phase-red-2026-10-18.xcresult`, 1/1 fallida. Un aviso coincidente fuera de `.ready` también se borraba. Los casos positivos comprueban el descarte normal de un aviso transitorio coincidente y el cierre manual sin cambios de comportamiento.

## Validación final

- Revisión independiente del diff final: sin hallazgos bloqueantes; conserva la limitación causal del menú.
- Inventario: 183 pruebas únicas y 186 ejecuciones; se conservan las 174 pruebas base anteriores y se añaden nueve, sin duplicados.
- Contratos del runner: **16/16**, sin omisiones, en `/tmp/nido-appearance-ledger-green-2026-10-18.log`. Su rojo previo detectó tres contratos incompletos; no modifica comportamiento de la app.
- Suite nativa completa: **185/186 ejecuciones correctas, una fallida y cero omisiones**. Interfaz clara 114/114 en `/tmp/nido-final-auth-menu-gate-2026-10-18/light-ui.xcresult`; capturas 59/59 y oscuro 10/10 en `/tmp/nido-auth-menu-remaining-phases-2026-10-18/`.
- Integración acumulada de esa suite: **2/3** en `/tmp/nido-final-auth-menu-gate-2026-10-18/local-api-ui.xcresult`. Creación de hogar y revocación de acceso pasan. Falla primero el cierre del calendario al seleccionar el 15 de julio; las búsquedas posteriores del registro antiguo son consecuencias de seguir dentro de la hoja. Los 505 registros se habían cargado y la celda de julio expone un pañal. La captura previa muestra la celda descubierta; refuta la hipótesis de superposición del encabezado. Se conserva el fallo y no se presenta esta suite como verde.
- Core: **209 pruebas en 31 suites correctas**, `/tmp/nido-core-209-31-final-2026-10-18.log`. Release de simulador: **BUILD SUCCEEDED**, app y extensión `NidoLiveActivity.appex`, en `/tmp/nido-auth-menu-release-build-2026-10-18.log`. Comprobación independiente: ninguna cadena `authNotice`, `RegistrationRouting`, `HistorySelection` o `NIDO_UI_TEST_SCENARIO` en ninguno de los dos binarios Release. Conserva advertencias de compilador preexistentes en `TodayView.swift:303` y `NidoStore.swift:262`.
- Diagnóstico adicional de selección de fecha: instrumentación temporal exclusivamente en la copia `/tmp/nido-native-validation`, fuera del repositorio y de la entrega. Registra acción de celda, selección, estado de presentación y fase de desplazamiento; no cambia navegación ni incorpora reintentos. La integración trazada pasó **3/3**, `/tmp/nido-history-selection-trace-2026-10-18/local-api-ui.xcresult`. Después pasaron **cinco invocaciones independientes 1/1**, cada una con base de datos y sesión nuevas, en `/tmp/nido-history-selection-stress-2026-10-18/history-{1..5}.xcresult`. Las trazas conservadas muestran `selectable=true` → selección correcta → `calendarPresented=false` → desaparición de la hoja aproximadamente 0,8 s después. Ninguna reprodujo el fallo; no demuestra su causa ni convierte la suite fallida en verde.
- Inspección visual del vídeo del fallo: la hoja sigue abierta después del toque, por lo que la evidencia no se limita a una jerarquía de accesibilidad atrasada. Grabación original: `/tmp/nido-final-auth-menu-gate-api-all-attachments-2026-10-18/A7846748-A420-42E7-A2A3-FBB6995385B1.mp4`; fotograma examinado `/tmp/nido-history-failed-post-tap-43s.png`.
- Restauración verificada: `HistoryView.swift` del repositorio y mirror conservan el SHA-256 `fd5cbf7d31c5313a76cd67188bc52e0e98a33bf793d344a336bb81bc413fbbc7`. No se entrega instrumentación del calendario. El simulador propio `4A7A40BF-4FEE-41F7-9019-1D1F5F5B04AD` queda apagado con su estado conservado, apariencia clara y Reducir movimiento desactivado. No se modificaron los simuladores del usuario.

![Aviso de reautenticación comprobado en simulador](</Users/pradosman/Documents/ChatGPT/App Marco/docs/intermittency-closure-2026-10-18/screenshots/reauthentication-notice.png>)

## Pendiente para el cierre completo

Capturar una ejecución fallida con trazas en la frontera toque→acción→selección→presentación. Hasta entonces no hay evidencia para cambiar el hit testing, la navegación o la paginación. Los recorridos correctos posteriores no sustituyen ese diagnóstico ni eliminan el fallo conservado de la suite.

## Límite de rollback

El cierre se guarda como una unidad reversible con código, pruebas y su inventario de ejecución, sobre `3e8f4ffa2134218f5f4c8e4e7f8795d61c11005b`. Revertir esa unidad retira las correcciones de sesión y la cobertura/diagnóstico del menú. No incluye cambios de paleta ni modificaciones de backend de producción.
