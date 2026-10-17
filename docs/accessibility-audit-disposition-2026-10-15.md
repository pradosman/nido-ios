# Diagnóstico de los avisos nativos de accesibilidad

Las cuatro auditorías generales `.all` conservan sus fallos y su callback sin filtros. La investigación posterior distingue elementos recortados y dos discrepancias de contraste sobre contenido visible; no presenta una auditoría nativa aprobada.

## Contraste con el elemento entero visible

El sondeo adicional ejecutó dos casos, claro y oscuro, únicamente en el iPhone 16 Pro autorizado: **dos fallidos, cero omitidos**. Comprobó ocho estados geométricos antes de auditar: tarjeta de sueño, título de actividad, estado vacío y resumen del dial, en ambas apariencias. Cada grupo objetivo estaba entero dentro del área libre entre la barra de navegación y el botón fijo, incluidas sus coordenadas horizontales. La auditoría sigue examinando toda la pantalla; sus 30 registros repetidos no son 30 defectos diferentes.

| Elemento al estar visible | Resultado observado |
| --- | --- |
| Sueño de hoy, Registrar sueño, Iniciar | No se señala el propio grupo visible; los avisos reaparecen cuando estos textos quedan bajo la barra superior. |
| Sin registros este día | No se señala el propio texto visible en este sondeo; los avisos se asocian a la posición recortada bajo el área inferior fija. |
| Actividad del día, oscuro | El auditor señala el texto visible. Su propio recorte da **9,6595:1**, con 683 píxeles interiores recurrentes RGB `(184,189,181)` sobre fondo `(19,20,19)`. |
| 0 tomas / 0 pañales, claro | El auditor señala el texto visible. Su propio recorte da **6,7947:1**, con 1.429 píxeles interiores recurrentes RGB `(87,87,82)` sobre fondo `(250,247,241)`. |

Las dos mediciones superan 4,5:1 y fueron repetidas independientemente. El cálculo empareja la descripción del aviso con su recorte por tiempo y exige una diferencia máxima de 2 ms; no usa un recorte arbitrario de otra pantalla. Las capturas también verifican que las apariencias clara y oscura se renderizaron. Esta evidencia contradice esos dos avisos para las muestras capturadas; no justifica suprimir hallazgos del auditor ni cambiar otro color sin demostrar un defecto.

Evidencia reproducible: `/Users/pradosman/.codex/recoveries/nido-20261015/visible-contrast-probe-20261015/`, con fuente y ejecutor del sondeo, `visible-contrast-16pro.xcresult`, exportaciones, `measure-visible-issues.py` y análisis. No se modificó código de producción.

## Tamaño de texto

El [seguimiento anterior](accessibility-and-legal-followup-2026-10-15.md) acredita doce cambios reales del ajuste del sistema y 48 mediciones de cuatro textos, con crecimiento entre extremos y sin reducciones de un píxel. Ese sondeo pasó, pero su comprobación inicial de interacción no demostraba que todo el marco quedara libre de superposiciones.

La ampliación ya se ejecutó en el mismo iPhone 16 Pro: **una prueba aprobada, cero fallos y cero omisiones**. Los doce ajustes reales del sistema se confirmaron antes de sus 48 mediciones. Los **48 marcos** quedaron enteros dentro del área libre, tanto horizontal como verticalmente; las cuatro secuencias de altura en píxeles no disminuyen y crecen entre extremos. La raíz volvió a calcular la contención a partir de las coordenadas registradas, además de ejecutar los validadores y consultar el xcresult.

Evidencia: `/Users/pradosman/.codex/recoveries/nido-20261015/dynamic-ramp-fit-probe-20261015/`. Un primer análisis de validación no reconoció el campo adicional `points=[...]`; se corrigió únicamente ese parser y se volvió a analizar el mismo resultado, sin repetir ni cambiar la prueba. No fue un fallo de producto ni un rojo TDD.

Los cuatro avisos nativos de tamaño quedan contradichos por crecimiento y contención comprobados en las doce categorías para esos cuatro elementos. Se documentan como discrepancia del auditor en esta configuración, conservando su resultado rojo. No se extiende esa conclusión a otras pantallas o contenidos sin comprobar.

## TDD y reversión

Estos son diagnósticos adicionales y documentación, sin cambios ejecutables en la aplicación. No constituyen un nuevo ciclo TDD de producto ni sustituyen los rojos/verdes de las correcciones anteriores. El sondeo temporal se retira eliminando únicamente su copia identificada; se preservan sus resultados. Cualquier corrección futura de producto debe empezar con una reproducción roja concreta y conservar la auditoría general sin filtros.
