# Evidencia: Historia de Apple Fitness y base de Nido

Investigación de solo lectura. No se ha ejecutado ni descompilado el flujo de Fitness; se distingue la estructura observada de los contratos propuestos en el [plan](implementation-plan.md).

## Capturas del usuario

Las tres fotos muestran: detalle diario con franja semanal y anillos; la franja conservada sobre contenido desplazado con secciones horarias; calendario en superficie modal con cierre y meses consecutivos. Permiten juzgar composición y estados representados. No demuestran velocidad, curva de animación, reconocimiento de gestos, comportamiento al cancelar o resultado de tocar un día.

## REA: artefacto real inspeccionado

- Artefacto: Fitness.app del runtime local de simulador iOS 26.5, build 23F77; ejecutable arm64 `Fitness`.
- Ruta base: `/Library/Developer/CoreSimulator/Volumes/iOS_23F77/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.5.simruntime/Contents/Resources/RuntimeRoot/Applications/Fitness.app`.
- SHA-256 del ejecutable: `62db5351c1b1ac523acd24d9109e57830ff2a8f06d9134245778664017422668`.
- REA `inspect_plist`: `ev_b02ed757f0feda5c5cf37b99c878465021c43b30a48408241aa50efd5aac1ff1`, identificador `com.apple.Fitness`.
- REA `inspect_macho`, evidencia completa retenida: `ev_aee84eb8527550dd6001a043280c89f112097c35ac3620c6df74c58a3cc71b03`; resumen `ev_bfef1a21610aa0657c8a47e96411487f7b7ebe7d47e16fc11fd020ba533a0cc4`. UUID `C2CBC64E-6C65-331A-BD42-A24561AF682D`.
- Vista de dependencias: `ev_8eaec9d9d63283828b6ccc4030cd48c1a69feedaf5f9ea8dfe80543080c4a110`: referencias a `CalendarUIKit`, `ActivityUI`, `ActivityRingsUI`, `FitnessUI` y `Charts`, entre otras. Son dependencias del ejecutable, no prueba de que cada pantalla use cada una.
- Vista de imports: `ev_adc30ded1f3657d9e11699a90bbb07f933af40ef7a0f19bd22a3322b571ed6c9`: referencias a `HKCalendarWeekView`, `HKCalendarDayCell` y funciones de calendario/semana. Se inspeccionaron los 6015 imports retenidos; la fuente declara que símbolos ocultos o eliminados pueden faltar.

## Metadatos nativos complementarios

`get_objc_classes` de REA devolvió `provider_unavailable`: no hay Ghidra, Hopper ni IDA configurados. Se continuó con los metadatos estáticos del mismo ejecutable mediante `xcrun otool -ov`. Los métodos relativos apuntaban a referencias de selector con punteros encadenados; se verificó formato 6 en `LC_DYLD_CHAINED_FIXUPS` y se resolvieron sus destinos contra los segmentos Mach-O. Esta decodificación complementaria no se presenta como salida de un descompilador de REA.

| Clase observada | Selectores relevantes observados | Qué respalda |
|---|---|---|
| `HistoryPagingViewController` | `pageViewController:viewControllerAtIndex:`, `pageViewController:didUpdateCurrentlyDisplayedIndex:`, `showHistoryMonthView` | Componentes para páginas diarias y acceso al mes. |
| `HistoryDayViewController` | Métodos de secciones/celdas de tabla, `share`, callbacks de ciclo de vida | Detalle diario dividido en secciones y participación en compartir. |
| `CHActivityHistoryNavigationController` | `attachPaletteWithHeight:`, `setPaletteExpanded:`, `reattachPaletteIfNeededExpanded:`, `detachPalette`, `scrollToTop` | Franja/paleta con estados de tamaño vinculada a la navegación. |
| `PaletteScrollViewController` | `startOfFitnessWeekBeforeWeekStarting:`, `startOfFitnessWeekAfterWeekStarting:`, `scrollOrRelayoutWeekIfNeededToDate:`, `scrollViewDidEndDecelerating:`, `reloadViewDataAtDate:` | Manejo de semanas, desplazamiento y recarga por fecha. |
| `PaletteViewController` | `currentSelectedDateChanged:`, `paletteDateSelected:`, `paletteScrolledInDirection:`, `setIsExpanded:collapseDayMarkers:` | Coordinación explícita entre selección, franja y estado visual. |
| `MonthScrollViewController` | `scrollToDate:windowHeight:`, `week:cellSelected:`, `_findCenteredWeekAndUpdateTitleIfNecessary`, `_loadActivitySummariesForWeek:ringGroupIndex:`, `_timeZoneChanged:` | Mes con semanas/celdas, fecha visible, títulos, caché y atención a zona horaria. |
| `MonthViewController` | `dateSelected:`, `_didTapCancelButton`, `scrolledPastMonthWithDate:` | Rutas separadas para selección, cancelar y mes desplazado. |
| `MonthDayCellLayer` | `isFutureDay`, `setIsFutureDay:`, `pressToTransition:` | Estado de día futuro y respuesta visual de una celda; no demuestra por sí solo si un toque futuro está permitido. |
| `ActivityMoveAndExerciseChartView` | `moveAndExerciseChartPoints`, `moveAndExerciseChartMaxYValue`, `reloadDataWithShowFull:animated:` | Datos y escala de gráficos de movimiento/ejercicio. |
| `ActivityStandChartView` | `standChartPoints`, `reloadDataWithAnimated:` | Representación específica de De pie, separada de las otras barras. |

Los nombres y selectores son observaciones de metadatos. Su agrupación respalda la separación día/semana/mes y las relaciones que se proponen para Nido; **no establece el cuerpo de los métodos, su orden de llamadas ni un gesto observado en ejecución**. No se recuperaron curvas, duraciones o fórmulas internas. No se instalaron herramientas adicionales ni se reutilizan frameworks privados.

## Base actual de Nido comprobada

- `Features/History/HistoryView.swift`: franja de días, resumen de tres anillos, filtros, lista editable/borrable y hoja de un mes con flechas. No hay gráficos horarios de categorías ni franja fijada al scroll.
- `Core/HistoryPresentation.swift`: la franja acaba en la fecha elegida; sus fracciones son sueño/720 min, tomas/10 y pañales/8. La lista filtra por fecha del registro. Los totales delegan en `CircularTimeline.day`.
- `Core/CircularTimeline.swift`: para sueño, `entry.date` es el final del intervalo; recorta su contribución por día. La proyección actual de sesión abierta se añade solo para hoy. Estos contratos requieren atención antes de la nueva analítica.
- `Core/NidoAPI.swift`: la carga sigue todos los cursores de `/api/nido/entries` y deduplica antes de devolver el historial completo. No existe en esta ruta una carga por mes bajo demanda.
- `Features/Trends/TrendsView.swift`: patrones existentes de Swift Charts, reutilizables como técnica, con dominio distinto al detalle diario.
- Proyecto: mínimo iOS 17 y Swift 6.0.
- Pruebas relevantes existentes: `HistoryPresentationTests`, selección/calendario en `NidoUITests`, edición en `EntryEditorSafetyUITests` y `SwiftUIImprovementUITests`, además del caso de historial paginado superior a 500 registros. Se revisaron como base de la planificación, no se ejecutaron en esta pasada.

El árbol ya contiene muchas modificaciones previas. Esta investigación y plan no cambian archivos de aplicación, referencias visuales ni tests. La validación de esta entrega documental consiste en contrastar las afirmaciones con las capturas, los resultados de REA y el código actual; TDD unitario no aplica. No hay commit, push ni publicación.
