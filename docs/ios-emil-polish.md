# Pulido de Nido con los criterios de Emil

> Esta página recoge la primera pasada. El seguimiento de los cambios posteriores, resultados actuales y bloqueos de publicación está en [Cierre de calidad](ios-project-closeout.md).

Las tarjetas de sueño y lactancia en curso conservan su identidad azul y ámbar, pero ahora mantienen texto legible en claro, oscuro y contraste aumentado. El filtro seleccionado del historial también mantiene contraste en oscuro, y la selección del resumen del anillo respeta Reducir movimiento. Los cambios se comprueban exclusivamente en el simulador iPhone 16 Pro con iOS 26.5.

**Resultado final:** 136 pruebas de lógica aprobadas; suite iOS con 67 casos, 60 aprobados, siete omitidos y cero fallos; Release compilada correctamente. Las dos pruebas de widgets omitidas por defecto también pasan en ejecuciones específicas. Siguen pendientes tres pruebas con credenciales reales, dos auditorías nativas completas de accesibilidad y la validación de publicación. Este pulido local no equivale a una aprobación de producción.

## Decisiones de diseño

| Antes | Después | Motivo |
| --- | --- | --- |
| Las tarjetas activas reutilizaban colores de gráficas que se aclaraban en modo oscuro y texto blanco transparente. | Fondos propios `activeSleepFill` y `activeFeedFill`, con texto blanco sólido. | Se preservan las categorías de las gráficas y se garantiza contraste para las etiquetas pequeñas. |
| El resumen del anillo animaba cualquier cambio de selección, incluso con Reducir movimiento. | Mantiene 160 ms de ease-out en el modo normal y actualización inmediata con Reducir movimiento. | La respuesta sigue siendo breve y respeta la preferencia del sistema. |
| El filtro seleccionado del historial usaba blanco sobre un fondo claro en oscuro. | Usa `textOnMoss`, adaptado al fondo real. | La selección mantiene su identidad y texto legible. |
| El entorno de pruebas traducía el máximo tamaño de accesibilidad de UIKit a `.accessibility3`. | Traduce correctamente a `.accessibility5`. | Las comprobaciones de texto máximo ahora ejercitan el tamaño solicitado. |

No se añaden animaciones decorativas a los registros ni se sustituyen los gestos y presentaciones nativos.

## Evidencia rojo → verde

| Unidad | Rojo correcto | Verde enfocado |
| --- | --- | --- |
| Contraste de tarjetas | `SettingsContrastTests` renderiza las vistas reales y localiza sus etiquetas con Vision. Lactancia: aproximadamente 2,96:1 en claro y 2,04:1 en oscuro. Sueño: 3,68:1 y 2,00:1. Las ocho variantes fallan el mínimo de 4,5:1. | Las mismas pruebas pasan en cuatro apariencias para cada tarjeta, sin rebajar el umbral. |
| Reducir movimiento | `testSelectedEntrySettlesImmediatelyWithReduceMotion` comprueba primero que la selección cambia visiblemente; después falla porque la imagen temprana solo coincide en el 96,3562 % con la estabilizada, frente al 99,5 % requerido. | La misma prueba pasa tras condicionar la animación a la preferencia real del sistema. |
| Filtro de historial | El texto real «Todo» renderizado mide 2,7868:1 en oscuro normal y aumentado, inferior a 4,5:1. | Las mismas mediciones pasan usando `textOnMoss`. |
| Tamaño máximo de pruebas | La vista hija observa `.accessibility3` cuando la prueba exige `.accessibility5`. | La misma prueba observa `.accessibility5` después de corregir el mapeo del modificador DEBUG. |

La primera ejecución del test de movimiento falló al compilar por un EnvironmentValues de solo lectura; otra detectó un problema del alojamiento y recorte de la propia prueba. Esos intentos **no** se cuentan como reproducción del bug. El rojo válido está en `/tmp/nido-polish-motion-red3-20261015.log`.

Evidencia local:

- Rojo de contraste: `/tmp/nido-polish-red2-20261015.{log,xcresult}`.
- Rojo de movimiento: `/tmp/nido-polish-motion-red3-20261015.{log,xcresult}`.
- Verde enfocado: `/tmp/nido-polish-focused-green-20261015.{log,xcresult}`; seis pruebas aprobadas, cero fallos u omisiones.
- Rojo de historial y tamaño máximo: `/tmp/nido-polish-extra-red-20261015.{log,xcresult}`; dos pruebas fallidas por los motivos anteriores.
- Verde final enfocado: `/tmp/nido-polish-ax5-dark-green-20261015.{log,xcresult}`; ocho pruebas de renderizado y cinco de interfaz, **13 aprobadas, cero fallos u omisiones**. Incluye pañales, invitación y encabezados al máximo tamaño, y las dos comprobaciones de oscuro real.
- Lógica completa final: `/tmp/nido-polish-core-final-20261015.log`; **136 pruebas en 16 suites aprobadas**.
- Release final para el iPhone 16 Pro simulado: `/tmp/nido-polish-release-final-20261015.log`; **BUILD SUCCEEDED**, sin firma. El producto se conserva en `/tmp/nido-polish-release-20261015/Build/Products/Release-iphonesimulator/Nido.app`.
- Las capturas inicial, temprana y estable y las ocho tarjetas renderizadas se conservan en el resultado de Xcode y en `/tmp/nido-polish-green-attachments`.

## Reproducción

El proyecto canónico permanece en este repositorio. Se copió `ios/Nido` a `/tmp/nido-polish-20261015` excluyendo `.build` y `.swiftpm` para evitar los bloqueos de lectura de iCloud. Los ocho archivos de código y pruebas modificados, `project.pbxproj` y `Package.swift` se compararon mediante SHA-256 y coinciden con los usados en la compilación final.

Para ejecutar la prueba de movimiento debe estar activado Reducir movimiento en el simulador. La prueba comprueba la preferencia con `UIAccessibility.isReduceMotionEnabled` y se omite explícitamente si no está activa; una omisión no equivale a una comprobación aprobada. Las ventanas de prueba usan una escena real, restauran la ventana anterior y sus datos de prueba se aíslan por UUID.

```sh
swift test --package-path /tmp/nido-polish-20261015 --scratch-path /tmp/nido-polish-core-20261015
xcodebuild -project /tmp/nido-polish-20261015/Nido.xcodeproj -scheme Nido -configuration Debug -destination 'platform=iOS Simulator,id=516B4FA1-D8C4-4389-9836-79095056D5CB' -derivedDataPath /tmp/nido-polish-derived-20261015 -only-testing:NidoSnapshotTests test CODE_SIGNING_ALLOWED=NO
```

## Suite completa y entrega

La primera suite completa terminó con 65 casos: 54 aprobados, nueve omitidos y dos fallos al intentar pulsar Guardar con el selector de hora abierto. La captura confirma el popover nativo y la hora correcta seleccionada; el registro de XCTest muestra un punto de toque `{-1, -1}` para el botón todavía inaccesible.

El test ahora cierra el selector tocando fuera de él, exige que desaparezcan las ruedas y comprueba que Guardar sea pulsable. Las expectativas siguen siendo guardar la toma a las 16:00 y actualizar el pañal a las 13:24. Ambos casos pasan, sin omisiones, en `/tmp/nido-polish-timepicker-green-20261015.{log,xcresult}`. Este cambio corrige la interacción de la prueba; no cambia el guardado del producto. La captura previa al cierre se conserva en `/tmp/nido-polish-timepicker-attachments`.

La repetición intermedia de `/tmp/nido-polish-full-final-16pro-20261015.{log,xcresult}` terminó con 65 casos: 56 aprobados, nueve omitidos y cero fallos. Después se añadieron las dos regresiones de historial y tamaño máximo. La suite final de `/tmp/nido-polish-complete-16pro-20261015.{log,xcresult}` termina con **67 casos: 60 aprobados, siete omitidos y cero fallos**, salida 0 y resultado `Passed` en Xcode. La regresión de Reducir movimiento se ejecutó y pasó; las dos comprobaciones oscuras también pasaron dentro de esta suite.

Las siete omisiones son tres casos que necesitan credenciales reales, dos auditorías nativas completas de activación explícita y dos escenarios de widgets de activación explícita. Las omisiones de widgets tienen las ejecuciones aprobadas independientes indicadas abajo; no se sustituyen las precondiciones de los otros cinco casos.

Al ejercitar el tamaño máximo real, dos pruebas se detenían con elementos solo parcialmente visibles. El rojo se conserva en `/tmp/nido-polish-extra-green-20261015.{log,xcresult}`. El ayudante compartido ahora desplaza hasta encuadrar el elemento completo dentro del área visible, excluyendo navegación y la acción flotante. Mantiene las expectativas de altura y límites, acota los intentos y aporta captura y jerarquía si falla. Los casos pasan en el verde final enfocado. Es una corrección del recorrido de prueba, sin alterar el diseño para acomodar el test.

El simulador conservaba capturas claras pese a indicar modo oscuro. Reiniciar el mismo iPhone 16 Pro, conservando sus datos, resolvió la discrepancia. Las dos pruebas oscuras después del reinicio pasan con brillo de fondo medido de 23 y 24, frente a 243 en la captura clara anterior. El resultado enfocado de 13 casos aporta esta comprobación; no se cuenta una omisión como aprobación.

Al terminar se restauraron Reducir movimiento desactivado y la apariencia clara del simulador. No se borró ni restableció el dispositivo.

La aplicación queda abierta en el escenario local del anillo, con texto Large y datos de prueba aislados. La captura final revisada está en `/tmp/nido-polish-final-preview-16pro-20261015.png`.

Los widgets se verificaron por separado: la galería pasa en `/tmp/nido-polish-widgets-16pro-20261015.{log,xcresult}` y las apariencias Tintado y Traslúcido pasan en `/tmp/nido-polish-widget-appearance-16pro-20261015.{log,xcresult}`. La prueba de apariencia requiere enviar `TEST_RUNNER_TEST_RUNNER_NIDO_WIDGET_APPEARANCE_TEST=1` a Xcode porque elimina un prefijo al transmitir el entorno.

La revisión independiente final no encontró defectos concretos en los cambios. Quedan fuera de esta entrega las tres pruebas que requieren credenciales reales y las dos auditorías nativas completas de accesibilidad de activación explícita. No se ha publicado una nueva versión ni se declara terminada la validación de servicios externos.

## Reversión

Las unidades reversibles son: los fondos y textos de tarjetas con sus dos pruebas; el filtro de historial con su prueba de contraste; la preferencia de movimiento con su prueba de estabilización; el mapeo DEBUG del tamaño máximo con su prueba; y los ayudantes de interacción de XCTest. Cada unidad debe revertirse junto a su prueba mediante sus hunks concretos: `SettingsContrastTests.swift`, `CircularTimelineSnapshotTests.swift` y `NidoUITests.swift` contienen varias unidades. No revertir archivos completos ni las correcciones previas de sincronización y migraciones. No hay cambios de datos persistentes ni nuevas dependencias.

No se ha creado un commit: las operaciones de Git se bloquean al leer metadatos y objetos de este checkout en iCloud. El intento acotado de preparar tres archivos se canceló; sus entradas del índice conservaron los SHA anteriores y se retiró el bloqueo del proceso cancelado. Los cambios permanecen revisables en los archivos canónicos. No se ha reinicializado ni sustituido el repositorio.

Este documento no tiene comportamiento ejecutable: no aplica TDD unitario. Su validación consiste en contrastar nombres, resultados, comandos y rutas con los registros conservados.
