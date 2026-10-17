# Accesibilidad y preparación legal — 15 de octubre de 2026

Estado actualizado: arreglo de VoiceOver integrado con TDD y suite completa aprobada. Tras la autorización posterior «Hazlo», el paquete legal independiente **ya está publicado y verificado**: véase el [resultado del despliegue](legal-deployment-result-2026-10-15.md). Los apartados de preparación siguientes conservan el estado anterior a esa autorización.

## Arreglo del dial

El resumen de estado del reloj tenía un marco de accesibilidad de 1×1 puntos, frente a unos 73×71 puntos del contenido visible. Otro elemento hijo repetía exactamente la descripción del contenedor. El cambio elimina esa lectura duplicada y hace que el resumen de estado cubra el centro del dial; conserva su identificador, su texto y las referencias a la hora actual. No cambia el aspecto del reloj.

- Rojo: dos pruebas ejecutadas y dos fallos correctos, por marco insuficiente y una descripción hija repetida.
- Verde enfocado: las dos pruebas nuevas y tres pruebas existentes de orientación, jerarquía y cambio de día pasaron, 5/5 sin omisiones.
- Suite completa posterior: **107 casos, 100 correctos, cero fallos y siete omisiones por configuración**, exclusivamente en el iPhone 16 Pro `516B4FA1-D8C4-4389-9836-79095056D5CB`. Las omisiones corresponden a tres flujos con servidor, dos auditorías nativas generales y dos pruebas de widgets que se ejecutan aparte. Reducir movimiento estuvo habilitado durante la corrida.
- Rollback: `CircularTimelineView.swift` y `DialAccessibilityUITests.swift`, mediante `dial-accessibility-fix.patch`; `git apply --reverse --check` pasó, sin aplicar la reversión. No hay un nuevo commit aislado para este arreglo.

Fuentes y resultados están preservados en `/Users/pradosman/.codex/recoveries/nido-20261015/final-accessibility-16pro-20261015/`. El primer intento de otro diagnóstico no compiló y no se cuenta como rojo. El diagnóstico posterior sí ejecutó dos casos: contraste por separado pasó con cuatro elementos identificables y el marco de 1×1 falló.

La comparación seleccionó 85 archivos de fuente/configuración: los 84 legibles coinciden con el proyecto canónico. El original de App Intents continúa sin descargar desde iCloud y no se afirma equivalencia byte a byte de ese archivo. Estas pruebas comprueban marcos y etiquetas del árbol de accesibilidad, sin acreditar una sesión manual de lectura con VoiceOver.

El archivo Release de esta misma copia terminó con `ARCHIVE SUCCEEDED`: `com.momentumia.nido`, versión 0.1.0, compilación 48, arm64 y mínimo iOS 17.0. Es un archivo sin firma de distribución, no una subida a App Store. El manifiesto de privacidad incluido coincide con la fuente canónica y la copia probada: cuatro categorías de datos y la razón `CA92.1` para UserDefaults. Se conserva como `Nido-unsigned.xcarchive` junto a `release-archive.log`.

## Diagnósticos restantes

Las auditorías generales `.all` conservan sus expectativas y manejadores sin filtros. La repetición posterior al arreglo ejecutó cuatro casos —claro y oscuro, antes y después de desplazar— y los cuatro fallaron, sin omisiones. Todos los avisos de esta repetición tienen ahora un elemento asociado; ninguno devuelve `nil`. No se considera cerrada la auditoría de accesibilidad.

| Escenario | Avisos de contraste | Avisos de tamaño de texto |
| --- | --- | --- |
| Sin desplazar, oscuro | Actividad del día; Sin registros este día | Ninguno |
| Sin desplazar, claro | Actividad del día; Ver todo; Sin registros este día; 0 tomas / 0 pañales | Ninguno |
| Desplazado, oscuro | Sueño de hoy; Registrar sueño; Iniciar; Actividad del día | Hoy; Ver todo; Actividad del día; Sin registros este día |
| Desplazado, claro | Sueño de hoy; Registrar sueño; Iniciar; Sin registros este día; 0 tomas / 0 pañales | Los mismos cuatro |

Los marcos permiten distinguir contenido cubierto de contenido visible: sin desplazar, la tarjeta de actividad queda bajo la zona fija inferior; después de desplazar, los textos de sueño señalados quedan bajo la barra de navegación. Los avisos sobre texto visible se conservan como pendientes de diagnóstico. Las capturas y los resultados completos están en `audit-scroll0.xcresult` y `audit-scroll1.xcresult`, junto a sus exportaciones, dentro del directorio de evidencia de esta entrega.

El contraste aislado ahora asoció su cuarto aviso al texto «0 tomas / 0 pañales», sin devolver `nil`; esto es una pista y no prueba la identidad de todos los avisos anteriores sin elemento. Sus píxeles de captura dan aproximadamente 6,79:1. El aviso oscuro de «Actividad del día» conserva una medición de 9,66:1 en el recorte del propio auditor. Las mediciones no convierten los diagnósticos nativos en verdes. El crecimiento entre Large y Accessibility XXXL del ajuste real del sistema ya pasó para los cuatro textos de la tarjeta.

La ampliación del diagnóstico recorre las doce categorías reales del sistema, desde XS hasta Accessibility XXXL, sin relanzar la aplicación ni inyectar un tamaño en su entorno. El primer intento completó doce confirmaciones de `simctl` y 48 mediciones, todas posteriores a su confirmación. Su único fallo fue comparar exactamente `44.0` con `44.000000000000114` en «Ver todo»; se conserva como fallo de precisión de la prueba, no como rojo de producto. La corrección del diagnóstico compara alturas en píxeles físicos enteros del iPhone 16 Pro, manteniendo las exigencias de no encoger y crecer entre extremos. No modifica código de la aplicación.

La repetición corregida pasó: **una prueba, cero fallos y cero omisiones**, exclusivamente en el iPhone 16 Pro aprobado. La verificación independiente del registro confirma doce ajustes y doce lecturas del sistema, anteriores a las 48 mediciones; las cuatro secuencias no disminuyen en píxeles y crecen entre extremos. La comprobación de la prueba confirma además que una reducción real de un píxel sigue detectándose.

| Elemento | Altura XS → Accessibility XXXL | Píxeles físicos iniciales → finales |
| --- | --- | --- |
| Hoy | 20,33 → 65,67 pt | 61 → 197 |
| Ver todo | 44 → 58,67 pt | 132 → 176 |
| Actividad del día | 13,33 → 51,33 pt | 40 → 154 |
| Sin registros este día | 14,33 → 116,67 pt | 43 → 350 |

Evidencia: `/Users/pradosman/.codex/recoveries/nido-20261015/dynamic-ramp-probe-20261015/attempt-1/` y `attempt-2/`, con fuente del diagnóstico, ejecutor, validador, registros y resultados. Los 43 archivos de producción comparados coinciden con la copia de la suite completa. Este diagnóstico aporta evidencia sobre los cuatro avisos de tamaño; no convierte las cuatro auditorías `.all` en aprobadas ni demuestra por sí solo toda la accesibilidad de la aplicación.

## Páginas legales

El [plan de despliegue legal](legal-only-deployment-2026-10-15.md) contiene el candidato construido sobre la revisión exacta de producción, su manifiesto, el parche y la reversión. Solo incorpora tres archivos de páginas y su contrato HTTP: no arrastra la configuración pendiente de revocación Apple ni cambia autenticación, esquema, `.env` o Compose.

La revisión corrigió una promesa heredada de anonimización: la versión de producción conserva datos de autoría en registros compartidos al eliminar una cuenta integrante. La página preparada describe ese comportamiento y no afirma que este paquete lo corrija. El arreglo de autoría del backend más reciente necesita su propio despliegue; no se considera cerrado el requisito de borrado por publicar estas páginas.

TDD legal inicial: cuatro contratos fallan por 404, después cuatro pasan. TDD de la corrección de autoría: cinco casos, cuatro correctos y un fallo por la promesa incorrecta; después cinco correctos. La primera suite serial aprobó 43 y omitió cinco casos de PostgreSQL externo. La repetición final habilitó esos casos en PostgreSQL 17.10 temporal propio: **48/48 correctas, cero fallos, cancelaciones u omisiones**, con migración correcta. Compilación y cuatro comprobaciones HTTP del servidor standalone correctas. La primera ejecución paralela interrumpida se conserva y no se cuenta como verde. El contenedor temporal fue retirado validando su identidad; los siete contenedores existentes conservaron sus identificadores y estado. No se usó una base de datos del usuario para las pruebas.

Producción sigue intacta. Publicar exigirá revalidar revisión, hashes, imagen anterior, configuración local existente y los dos endpoints por HTTPS. El paquete y su rollback ya son revisables; no se ha ejecutado el despliegue.

## Entorno y validación documental

Se limpiaron únicamente cachés regenerables inactivas, preservando registros y resultados: `.build` de copias locales, productos y módulos de una compilación Release ya archivada, caché global de módulos de Xcode, caché de descargas de npm y productos de una compilación antigua sin archivos abiertos. Los paquetes instalados, configuración, credenciales, fuentes y archivos de publicación permanecen intactos. No se limitaron ni terminaron conexiones MCP.

Este informe y los metadatos de preparación no cambian comportamiento: no aplica TDD unitario adicional. Su validación consiste en contrastar resultados, hashes, parche y fuentes. Los dos cambios ejecutables anteriores sí tienen sus ciclos rojo/verde separados.
