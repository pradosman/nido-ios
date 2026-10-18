# Nido luminoso — validación

## Alcance

Aplicar la paleta sRGB de Nido luminoso: sueño `#F43B83`, tomas `#FFB02E` y pañales `#00BFAE`. La definición compartida cubre categoría, glifo, acento y tinta legible. El pañal tiene un glifo propio y la marca luna/nido se comparte entre la app y los widgets. `drop.fill` queda reservado al subtipo Pis y al fallback documentado de App Shortcuts, cuya API exige literales SF Symbols. Deben conservarse la geometría de los anillos y el degradado.

El trabajo contempla `Core/CareCategory.swift` (lógica pura), `Shared/CareCategoryIcon.swift`, extracción del snapshot Codable compartido en `Core/NidoWidgetSnapshot.swift` y `Design/NidoDayWidgetContent.swift` para el contenido común de app y widget.

Los acentos de los anillos no se reutilizan indiscriminadamente como texto pequeño. Las tintas dependen de la apariencia:

| Categoría | Acento sRGB | Tinta clara | Tinta oscura | Alto contraste claro | Alto contraste oscuro |
| --- | --- | --- | --- | --- | --- |
| Sueño | #F43B83 | #B31557 | #F43B83 | #85003B | #FF9ABB |
| Tomas | #FFB02E | #875000 | #FFB02E | #583000 | #FFD18B |
| Pañales | #00BFAE | #006D63 | #00BFAE | #004C45 | #7DEBDD |
| Cuidados | #C26BFF | #8031BB | #D5A3FF | #5A168F | #E5C4FF |

Se conservan los símbolos específicos de lactancia, biberón, extracción, sólidos y las actividades de cuidados. Marca y acciones siguen usando musgo; el estado sin conexión usa el color de advertencia. El arco del reloj heredado usa el acento compartido de sueño y su marca duplicada delega en el símbolo común.

## Evidencia conocida

- La comprobación roja nativa previa está en `/tmp/nido-palette-tdd-red-2026-10-18b.xcresult`: 2 pruebas, 1 pasada, 1 fallida y 0 omitidas.
- `testChartAccentsUseTheNidoPaletteInSRGB` falló porque los colores P3 heredados no coinciden exactamente con los valores sRGB solicitados.
- `testCategorySmallTextTintsMeetContrastOnEachAppearanceBackground` pasó.
- Segundo rojo, antes de corregir los alias de colores: `/tmp/nido-static-alias-red-2026-10-18-sixth.xcresult`. Compilación correcta; `testStaticCategoryColorsMatchSmallTextPaletteInEveryAppearance` ejecutó una prueba con 42 aserciones fallidas porque los accesos directos `NidoTheme.sleep/feed/diaper/care` aún devolvían tintas antiguas. Las cinco ejecuciones previas no llegaron al test y no se cuentan como rojo TDD.
- Rojo del menú nativo: `/tmp/nido-diaper-glyph-ink-red-2026-10-18.xcresult`, una prueba fallida. OCR encontró las filas correctas y midió cero píxeles del icono de Pañal frente a 376 en la referencia. UIKit omitía el `Shape` del `Label`. La imagen de plantilla generada desde el mismo dibujo corrigió la omisión: `/tmp/nido-diaper-glyph-ink-green-verified-2026-10-18.xcresult`, 1/1, 89 píxeles detectados. Se calibró el umbral para la menor masa del dibujo recortado; el mismo algoritmo sigue midiendo cero y fallando con la captura anterior. La revisión visual principal e independiente confirma un pañal reconocible y coherente con el resumen.
- El contenido nativo de small/medium pasó la comprobación OCR en fullColor, accented y vibrant. El accesorio rectangular pasó también a 160 × 36 tras añadir una composición compacta, en `/tmp/nido-widget-accessory-responsive-retry-2026-10-18.xcresult` (1/1). Son renderizados del contenido; los modos transformados por el sistema se revisan por separado en SpringBoard.
- La galería real de SpringBoard pasó (1/1) en `/tmp/nido-widget-gallery-native-2026-10-18.xcresult`: el widget pequeño muestra las tres métricas y el pañal propio. El árbol de automatización de SpringBoard expone el widget como icono sin hijos de métricas; esa captura no acredita el recorrido de VoiceOver.
- Los modos Tintado y Translúcido reales pasaron en SpringBoard: `/tmp/nido-widget-tinted-clear-native-2026-10-18.xcresult`, 1/1. Las capturas incluyen el modo seleccionado. En estas variantes iOS sustituye la paleta por su tratamiento monocromo y controla el fondo; no se fuerza el RGB de Nido ni se afirma contraste universal frente a cualquier fondo de pantalla.
- El plan de pruebas incorpora diez comprobaciones nuevas sin retirar las 164 anteriores: 174 casos base y 177 ejecuciones por la separación de tres casos claro/oscuro (113 Light UI, 3 API UI, 51 Snapshot y 10 Dark UI). La nueva prueba del ledger falló primero por faltar `testChartAccentsUseTheNidoPaletteInSRGB` y volvió a fallar al exigir la nueva prueba de lactancia; tras actualizar el inventario y sus guardas, las 13 pruebas de los scripts pasaron.
- Hoy con datos del Store pasó en claro y oscuro (1/1 cada uno): `/tmp/nido-today-babycare-light-2026-10-18.xcresult` y `/tmp/nido-today-babycare-dark-2026-10-18.xcresult`. Revisión visual principal e independiente aprobada para estas capturas; no se extrapola a todos los tamaños. Se conservan el degradado, la geometría de anillos y la separación de métricas sin divisores.
- La actividad real de sueño se publicó mediante ActivityKit (log de inicio confirmado) y pasó su comprobación en Dynamic Island expandido: `/tmp/nido-live-sleep-systemui-retry-2026-10-18.xcresult`, 1/1. No es un render de una vista simulada.
- Soporte de pruebas de lactancia: `/tmp/nido-feed-activity-red-2026-10-18.xcresult` falló antes del cambio por no existir el escenario de prueba y no aparecer «Lactancia» en Dynamic Island. Se añadieron únicamente dentro de `#if DEBUG` el escenario de lactancia y la limpieza de actividades de QA. Release no incorpora esos escenarios. `/tmp/nido-feed-activity-green-2026-10-18.xcresult` pasó 1/1 y la captura real confirma el símbolo de lactancia ámbar y el temporizador. El test solicita la limpieza en `defer`.
- Las tres pruebas de contenido/DTO finales pasaron en `/tmp/nido-widget-content-date-circular-final-2026-10-18.xcresult`: incluyen las cuatro familias, circular en reposo/sueño/lactancia, el formato compacto y el contrato de fechas con la estrategia JSON que usa producción.
- Core pasó 209 pruebas en 31 suites (`/tmp/nido-luminous-core-tests-2026-10-18.log`).
- El test que exige Reduce Motion pasó por separado (1/1). El driver activa esa preferencia únicamente para Snapshot y conserva el valor inicial en las fases UI. Tres pruebas nuevas fallaron antes de añadir el hook (estado no aplicado, no restaurado y precondición no verificada); después pasaron las 16 pruebas completas de los scripts. Se comprueba y restaura la preferencia también ante fallos.
- La primera fase completa de capturas pasó 49/51; los dos casos del reloj heredado detectaron cuatro referencias antiguas a 350/280 pt y texto normal/XXXL. La inspección principal e independiente comparó referencias, capturas y diferencias: los cambios de paleta, pañal y marca compartida son intencionados; las métricas del glifo desplazan ligeramente la leyenda sin recortes nuevos, cambios de datos ni de ángulos. Se autorizó actualizar únicamente esas cuatro imágenes desde los renderizados nativos, manteniendo las precisiones 0,99/0,98. El resultado de la repetición se recoge en el cierre.
- El primer intento de integración local agotó 180 s antes de abrir conexiones a PostgreSQL. El proceso estaba esperando un archivo de `drizzle-orm` marcado `dataless` por iCloud; PostgreSQL estaba preparado y sano. Se conserva la evidencia original en `/tmp/nido-luminous-fullgate-2026-10-18/local-api-ui-evidence/`. Este intento no se cuenta como integración aprobada.
- El backend se preparó después en `/tmp/nido-api-runner-mirror-2026-10-18`, fuera de iCloud, con el lockfile intacto y `npm ci --offline` (439 dependencias). Migraciones, servidor y sesiones sintéticas arrancaron correctamente. La primera ejecución de API pasó 2/3: el caso histórico falló antes de consultar la paginación porque el toque automatizado cayó bajo la barra del calendario. La jerarquía conservada muestra la barra en y=78…132 y la celda en y=100…157: su centro y=128,5 estaba cubierto pese a `isHittable`. Se conserva ese rojo en `local-api-ui-final.xcresult`; la corrección se limita al gesto del test, con la fecha completamente descubierta antes de tocarla y las aserciones de cierre y registro histórico intactas.
- La primera corrección enfocada detectó a su vez una lectura de `frame` antes de que el calendario materializara el nodo. La versión final exige `exists`, usa el scroll identificado, desplaza la fecha con un gesto acotado y comprueba su contención en el área descubierta. El caso enfocado pasó 1/1, sin omisiones, en `/tmp/nido-history-safe-tap-focused-v2-2026-10-18.xcresult`; se revisó su captura anterior a la selección y se confirmó el cierre del calendario y el registro histórico. No cambia código de producción ni debilita las aserciones de paginación.
- La repetición conjunta posterior pasó el historial, pero falló en selección del menú y aviso de reautenticación: `/tmp/nido-api-final-3-pass-2026-10-18.xcresult`, 1/3. Se conservaron aserciones y producción. Tras borrar únicamente el simulador QA propio, la suite completa API pasó 3/3, cero omisiones, en `/tmp/nido-api-clean-qa-final-2026-10-18.xcresult`. Esto documenta intermitencia, sin demostrar su causa. Una revisión señaló una posible carrera en el motivo de reautenticación; no se considera confirmada ni corregida en esta entrega. Se conservan los intentos fallidos y los logs sanitizados, sin presentar el resultado como una primera ejecución limpia.

## Capturas

Capturas nativas de Hoy con datos de prueba del Store y del menú de iOS:

![Hoy claro](</Users/pradosman/Documents/ChatGPT/App Marco/docs/nido-luminoso-2026-10-18/screenshots/today-light.png>)
![Hoy oscuro](</Users/pradosman/Documents/ChatGPT/App Marco/docs/nido-luminoso-2026-10-18/screenshots/today-dark.png>)
![Registro con icono de pañal](</Users/pradosman/Documents/ChatGPT/App Marco/docs/nido-luminoso-2026-10-18/screenshots/registration-menu-light.png>)

Evidencia del sistema, con ActivityKit y SpringBoard reales:

![Sueño en Dynamic Island](</Users/pradosman/Documents/ChatGPT/App Marco/docs/nido-luminoso-2026-10-18/screenshots/live-sleep-island.png>)
![Lactancia en Dynamic Island](</Users/pradosman/Documents/ChatGPT/App Marco/docs/nido-luminoso-2026-10-18/screenshots/live-feed-island.png>)
![Widget tintado](</Users/pradosman/Documents/ChatGPT/App Marco/docs/nido-luminoso-2026-10-18/screenshots/widget-tinted.png>)
![Widget translúcido](</Users/pradosman/Documents/ChatGPT/App Marco/docs/nido-luminoso-2026-10-18/screenshots/widget-clear.png>)

Renderizados de la misma vista de producción, sin representar los efectos del host de WidgetKit:

![Contenido mediano](</Users/pradosman/Documents/ChatGPT/App Marco/docs/nido-luminoso-2026-10-18/screenshots/widget-medium-content.png>)
![Contenido rectangular compacto](</Users/pradosman/Documents/ChatGPT/App Marco/docs/nido-luminoso-2026-10-18/screenshots/widget-accessory-rectangular-content.png>)
![Contenido circular en lactancia](</Users/pradosman/Documents/ChatGPT/App Marco/docs/nido-luminoso-2026-10-18/screenshots/widget-accessory-circular-feed-content.png>)

- Las pruebas de contrato de Core añadidas después de la implementación son pruebas de regresión, no TDD.
- Para el resultado gráfico no aplica TDD unitario: lo sustituyen la compilación de los targets afectados y la inspección de capturas nativas. Los cambios de comportamiento y los bugs reproducibles tienen la evidencia roja y verde descrita arriba.
- La revisión de código detectó que los detalles interiores del pañal se fusionaban con la silueta y que el accesorio circular activo no identificaba su categoría. Se corrigieron con recortes transparentes `eoFill` y una etiqueta Sueño/Lactancia con el temporizador como valor accesible. Las capturas finales correspondientes están revisadas.

## Resultados finales

Resultados verificados directamente a partir de los bundles nativos:

- Prueba roja: conversión incorrecta de colores Display P3 a sRGB, alias con tintas antiguas e icono del pañal omitido en el menú nativo; evidencia detallada arriba.
- Prueba enfocada verde: paleta e iconos, menú, contenido de widgets, modos del sistema y actividades de sueño/lactancia comprobados; resultados detallados arriba y en `results.json`.
- Suite completa: Core 209/209 en 31 suites y scripts 16/16. Las cuatro fases nativas suman 177/177 ejecuciones aprobadas y cero omisiones: Light UI 113, API UI 3, Snapshot 51 y Dark UI 10. Son resultados consolidados de las fases y repeticiones documentadas, no una ejecución inicial sin incidencias. Bundles finales: `light-ui.xcresult`, `snapshots-final.xcresult`, `dark-ui.xcresult` en `/tmp/nido-luminous-fullgate-2026-10-18/`, y `/tmp/nido-api-clean-qa-final-2026-10-18.xcresult`.
- Compilación de los targets afectados: Debug de app y extensión compilado para las pruebas nativas; Release para simulador aprobado en `/tmp/nido-luminous-release-build-2026-10-18.log` (`BUILD SUCCEEDED`, cero errores). Se comprobó la presencia de ambos binarios Release y que ninguno contiene los tres escenarios DEBUG de actividades en vivo. Es una compilación para simulador, no un archivo firmado para App Store.
- Renderizados y revisión visual en app y widgets: aprobados en las capturas documentadas, con las limitaciones de alcance indicadas arriba.
- Límite de rollback: una única unidad de cambio para paleta, iconos compartidos, contenido del widget y pruebas/referencias asociadas, sobre `20c5464468b8c74f1ad6db109f585062d39e750b`. Revertir íntegramente ese commit evita dejar app y extensión con definiciones distintas. No incluye cambios de backend, migraciones de producción ni publicación en App Store.
- Limpieza: se eliminó únicamente el simulador QA creado para esta validación (`0EB49BCB-37A7-466D-AD5C-8C6E3AEFD634`). Se conservaron los tres simuladores del usuario y todos los resultados. La única edición de producción posterior a las fases visuales eliminó una línea vacía al final de `CareCategory.swift`: hash del contenido sin espacios finales idéntico y parseo Swift aprobado.
