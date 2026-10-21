# Evolución de Nido — plan basado en Resumen de Apple Health

Estado histórico del plan: propuesta inicial. La implementación está en curso; el estado recuperado y la evidencia vigente se documentan en `recovery-2026-10-21.md` e `integration-review-status.md`. La integración aún no tiene aprobación final. Las referencias siguientes describen el punto de partida y la dirección de diseño, no certifican el estado actual del código.

## Objetivo

Convertir Ritmos en Evolución: un lugar para entender los cambios de sueño, tomas, pañales, peso y talla. Hoy sirve para registrar y consultar el día; Historia para revisar fechas y entradas; Evolución para explorar periodos y crecimiento.

La referencia es la estructura de información de Resumen en Salud, adaptada a Nido. Se conserva la identidad Nido luminoso, el degradado calmado y los iconos de cuidado ya unificados.

## Evidencia y límites de la investigación

- Las dos capturas del usuario muestran un resumen con datos fijados, edición, valor, unidad, fecha y pequeñas gráficas; al abrir una métrica aparecen los periodos D/S/M/6M/A, resumen numérico, gráfica y datos importantes.
- REA abrió el binario Health del simulador iOS 26.5: bundle `com.apple.Health`, versión de compilación `6200.6.8.2.1`, SHA-256 `09ddd44120d7bfe794837c1cc54c036ea06cf52a8380454fb7e80ea5ae1e254e`.
- La inspección nativa de símbolos mediante REA encuentra `PinnedContentManager`, su operación `pin(identifier:)`, `HKInteractiveChartViewController` y `HKSharedSummaryCloudSyncManager`. Esto acredita componentes presentes; no demuestra su configuración exacta ni todos sus gestos en ejecución.
- REA leyó los recursos españoles de Health y HealthExperienceUI: «Resumen», «Sin datos», «No hay temas fijados», «Editar lista», «Fijar en el resumen», «Los temas fijados aparecerán al principio del resumen» y «Mostrar todos los datos importantes».
- El proveedor de descompilación y el trazado de acciones de REA no están disponibles en este entorno. No se han medido curvas de animación, alturas ni duraciones exactas de Health, ni se ha recorrido su interfaz en vivo. Los detalles de interacción siguientes son decisiones propuestas para Nido, no afirmaciones sobre código interno de Apple.

## Experiencia propuesta

### Entrada: Evolución

Título grande y perfil del bebé, seguidos por «Datos fijados» y «Editar». Cinco tarjetas iniciales: Sueño, Tomas, Pañales, Peso y Talla. Cada tarjeta completa abre su detalle y contiene icono y título, periodo o fecha, valor principal con unidad y una pequeña gráfica.

Para sueño, tomas y pañales se propone resumir los siete últimos días naturales terminados, con periodo y cobertura visibles. «Terminado» describe el calendario, no la integridad de los registros. El primer hito definirá el denominador y el texto del promedio registrado: un día sin entradas no es cero y tener alguna entrada no acredita un día completamente registrado. Peso y talla muestran la última medición y su fecha, acompañadas por observaciones históricas reales. Esta distinción se rotula; no se mezclan «último valor», «total» y «promedio» sin explicarlo.

Las tarjetas se diseñan según sus datos: las barras expresan cantidades por intervalo; peso y talla usan puntos y líneas entre mediciones. No habrá gráficas decorativas ni mediciones interpoladas presentadas como registros reales. El tamaño de las tarjetas responderá a su contenido y al tamaño del texto.

La jerarquía utiliza estilos tipográficos del sistema, cifras con unidades secundarias, fecha legible y espacio vertical suficiente. El fondo lleva la identidad de Nido; las superficies de contenido son tranquilas y la transparencia se reserva a los controles flotantes. La etiqueta Evolución debe caber sin recortes en la barra existente, también con tamaños de accesibilidad.

«Editar» permite fijar, desfijar y ordenar. Una entrada «Ver todos los datos» mantiene accesibles las métricas que no estén fijadas. Se propone guardar esta personalización localmente por cuidador y bebé; los registros siguen usando la sincronización existente. Sincronizar también la personalización entre dispositivos sería una ampliación independiente.

### Detalle de una métrica

Navegación nativa con título y acción de añadir cuando corresponda; selector D/S/M/6M/A; cifra principal con etiqueta TOTAL, PROMEDIO o ÚLTIMA MEDICIÓN y rango exacto; gráfica interactiva; información descriptiva basada en registros; acceso a todas las entradas del periodo y a añadir, editar y eliminar con los permisos existentes.

El cambio de periodo actualiza cifra, gráfica y texto conjuntamente. Seleccionar una barra o un punto muestra fecha y valor; al salir de la selección vuelve el resumen del periodo. Desplazarse entre intervalos debe conservar el periodo elegido y permitir volver al actual. Estas interacciones se validarán en prototipo antes de generalizarlas.

### Reglas de datos

- Calendario y cortes diarios según la zona horaria de la familia, incluidos cambios de hora y sueño que cruza medianoche.
- Días sin registros se representan como ausencia de información. No se convierten automáticamente en cero ni en días completos.
- Se verifica primero la cobertura y la paginación antes de mostrar un promedio o una comparación histórica. Si no se conoce la integridad del periodo, se explicita su cobertura y se evita un promedio que parezca completo.
- Un sueño en curso puede contribuir al detalle del día hasta «ahora», claramente indicado; no altera el promedio de días completos.
- Las tomas cuentan eventos registrados. El volumen solo se muestra cuando está registrado y es aplicable; una toma sin volumen no se convierte en cero mililitros.
- Peso y talla conservan fecha y precisión de las mediciones; no se suman ni se interpretan como objetivos diarios.
- Las comparaciones describen periodos equivalentes con datos suficientes. No etiquetan como mejor o peor que un bebé duerma, coma o moje más pañales.
- Estados diseñados: sin datos, una única medición, datos parciales, periodo futuro, carga, desconexión, sincronización pendiente y error. Una tarjeta fijada sin datos sigue disponible.

## Hitos y condiciones de cierre

1. **Contrato de datos y navegación.** Definir catálogo de métricas, fórmulas, periodos, cobertura, selección de intervalos y persistencia de fijados. Comprobar qué histórico carga realmente el store. Entrega: contrato y casos de prueba; cualquier necesidad real de API se identifica aquí, antes de diseñar cifras sobre datos incompletos.
2. **Primera pantalla para revisión.** Construir solo Evolución con datos de prueba representativos, en claro y oscuro. Mostrarla con y sin datos, en tamaño normal y con texto grande. Revisar jerarquía, aire, degradado, unidades, fechas, iconos y barra flotante. Enseñar capturas al usuario y detenerse hasta su aprobación antes de extender el diseño a los detalles.
3. **Una interacción vertical completa: Sueño.** Modelo puro y pruebas primero, tarjeta, apertura del detalle, periodos, selección de gráfica y acceso a registros. Incluir medianoche, sueño activo, ausencia de datos y cambio horario. Su aprobación fija el patrón reutilizable.
4. **Completar métricas y personalización.** Aplicar el patrón a Tomas y Pañales. Integrar Peso y Talla reutilizando los detalles y la edición existentes. Añadir fijar, desfijar y ordenar, persistencia por cuidador/bebé y acceso a todos los datos. No sustituir los flujos de crecimiento que ya funcionan sin una razón concreta.
5. **Información descriptiva.** Añadir solo los resúmenes y comparaciones definidos en el contrato y comprobables con registros suficientes. Diseñar «No disponible» y explicar la falta de cobertura. Sin porcentajes o tendencias fabricados para rellenar tarjetas.
6. **Cierre de calidad.** Pruebas enfocadas y suites completas, compilación Release, revisión visual y pruebas de interacción en simulador y después iPhone. Verificar navegación y retorno, VoiceOver, texto máximo, aumentar contraste, reducir movimiento/transparencia, permisos y sincronización. Entrega con evidencia y límites de lo probado.

## Reutilización técnica

- `Features/Trends/TrendsView.swift`: punto de entrada que se sustituye; actualmente mezcla sueño semanal, cifras de hoy y crecimiento.
- `Features/Baby/GrowthOverviewView.swift`, `GrowthSeriesDetailView.swift`, `GrowthRange.swift` y `GrowthMetric.swift`: reutilizar navegación, periodos, mediciones y edición de crecimiento.
- `Core/BabyCareMetrics.swift`, `NidoMetrics`, `BabyCareReconciliation` y `NidoStore`: fuentes de cálculo, reconciliación y permisos existentes. Crear fuera de las vistas una capa pura de series por periodo y presentación del resumen.
- Conservar las identidades de navegación necesarias para no romper rutas y pruebas al cambiar la etiqueta visible Ritmos por Evolución.
- Evitar añadir campos a `BabyCareState` o migraciones del backend solo para preferencias locales de presentación.
- `Core/NidoAPI.swift::load` recorre `nextCursor` hasta terminar y `NidoStore.load` mezcla el histórico completo con registros locales. La agregación puede ser local tras una carga correcta; no se ha detectado necesidad de un endpoint nuevo. Durante la carga o desconexión puede mostrarse una caché anterior: ese estado debe acompañar las cifras. Completar la descarga no garantiza que la familia haya registrado todos los cuidados; esa segunda cobertura también debe explicarse.

## Pruebas y reversión previstas

Todo comportamiento nuevo seguirá rojo → verde → refactor: primero pruebas de agregación y cobertura; después pruebas UI de navegación, periodos, selección y personalización. Las capturas verifican diseño y no sustituyen las pruebas funcionales. Para recursos y documentación no aplica TDD unitario: se usa renderizado/revisión visual o validación de configuración según el cambio.

Cada unidad reversible incluirá implementación y prueba: modelo de periodos, pantalla inicial, detalle de sueño, ampliación a otras métricas, personalización y comparaciones. Las pruebas existentes no se debilitarán ni se ocultarán hallazgos de accesibilidad. Las 209 pruebas de lógica y 201 ejecuciones de la entrega anterior son una línea base histórica; no validan esta función aún no implementada.

El primer punto de decisión es aprobar este plan. El siguiente será la revisión visual de una sola pantalla, antes de completar la sección.
