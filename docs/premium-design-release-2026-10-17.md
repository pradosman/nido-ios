# Entrega de la rama premium de Nido

Rama: `codex/nido-premium-design`. Destino: `origin` en `pradosman/nido-ios`. Esta entrega conserva los anillos por objetivos, los datos históricos del bebé y las pruebas que acompañan la implementación. La publicación de la rama no modifica App Store ni fusiona cambios en la rama de producción.

## Unidades de entrega

1. `f774759` — backend: objetivos y crecimiento compartidos, autorización, migraciones aditivas, configuración legal y evidencia del despliegue. Se verificaron los 59 hashes del código utilizado para construir la imagen desplegada. Las 82 pruebas con PostgreSQL y las 12 comprobaciones HTTP aprobadas constan en el informe de despliegue.
2. `dd6a9d2` — cliente iOS: implementación nativa, proyecto, widgets, pruebas de lógica e interfaz y ejecutor de integración. La pasada final aprobó 167/167 métodos nativos, sin fallos ni omisiones, más 20/20 contratos del ejecutor y la compilación firmada del esquema público `NidoAppearanceValidation`. Las 209 pruebas del núcleo constan en la evidencia previa de esta misma implementación.
3. Documentación: decisiones de diseño, evidencias seleccionadas y galería de capturas nativas. Los prototipos descartados, capturas duplicadas y herramientas locales se conservan en el equipo sin publicarse con el producto.

## Backend en producción

La imagen activa es `nido-babycare:20261017-goals`, identificador `sha256:de15db54204960edc1791efeb30168faac9a68dcbd18b48c31363235c2fb9a94`. El checkout del VPS sigue en su rama de despliegue anterior; el código de esta entrega se publica en una rama diferente para su revisión. No se sustituye automáticamente el checkout del VPS.

Una futura operación de despliegue debe construir el código elegido, ejecutar el migrador de esa misma imagen y conservar las variables legales y de autenticación existentes. Para recrear **la versión actualmente desplegada**, se necesitan el Compose original y el override privado de imagen descritos en [el resultado del despliegue](backend-baby-care-deployment-result-2026-10-17.md). Ejecutar solo el Compose base no acredita que se haya seleccionado esa imagen.

## Reversión

El backend admite reversión de la imagen de la API conservando las tablas, columnas y datos de las migraciones aditivas. No se debe deshacer el journal ni restaurar una copia sobre producción para revertir una interfaz. El procedimiento y los respaldos están documentados en [el resultado del despliegue](backend-baby-care-deployment-result-2026-10-17.md).

La unidad del cliente se revierte junto con su proyecto, recursos y pruebas; su contrato previo sigue siendo compatible con el esquema aditivo. La documentación se puede revertir por separado. No se debe restaurar todo el checkout ni borrar los prototipos locales para deshacer un commit.

## Alcance de la validación

Las auditorías de contraste mantienen todos sus hallazgos. El ajuste de «Ver todo» de `.subheadline` a `.body` conserva la tinta, el fondo y una altura táctil mínima de 44 puntos. Las auditorías completas clara y oscura pasaron de dos fallos a dos aprobados, sin filtros. Las capturas se revisaron visualmente antes de aceptar el cambio.

La comprobación de apariencia configura el simulador antes de iniciar cada proceso de pruebas. No añade un override de tema a la app. Tres pruebas que mezclaban capturas claras y oscuras se separan en dos métodos cada una: el inventario pasa de 164 a 167 métodos, preservando la cobertura anterior. Una ejecución deliberada del caso oscuro en un simulador claro falló; el mismo caso y código aprobaron al arrancar en oscuro. El comprobador de píxeles falla ante un modo incorrecto y no lo convierte en una omisión.

Un primer recorrido HTTP en iPhone 16 Pro agotó la espera al abrir el registro rápido de pañal. Los tres recorridos aprobaron con datos nuevos en un simulador aislado y volvieron a aprobar en el iPhone 16 Pro con otra instalación de datos nueva. Se conserva el fallo como incidencia intermitente: las repeticiones aprobadas no demuestran su causa ni garantizan que no vuelva a ocurrir.

El ejecutor `ios/Nido/Scripts/run-appearance-phased-ui-tests.mjs` cubre 111 casos UI claros, tres integraciones con la API, 43 casos Snapshot y diez casos UI oscuros. Sus contratos verifican el inventario completo, la configuración antes de cada fase, la detención por errores y la restauración de apariencia con lectura de comprobación. También exige que cada resultado nativo tenga exactamente los casos esperados y cero fallos u omisiones: un proceso que termine correctamente no basta. El fallo de restauración, el contrato del resumen nativo y la selección explícita de otro simulador tuvieron pruebas rojas antes de corregirse; los contratos de apariencia, resultados y soporte/sesiones de la API aprobaron, 20/20 sin omisiones. El comprobador de resultados se contrastó además con bundles reales aprobados. El resultado nativo completo se recoge en [el cierre de contraste y apariencia](contrast-appearance-closeout-2026-10-17/validation.md).

No aplica TDD unitario a la selección de documentos ni a la limpieza de líneas vacías al final de cinco archivos de Crecimiento: se verifican mediante revisión de diferencias y comprobación de formato. Los logs originales conservan sus espacios para mantener la evidencia; la comprobación de espacios del código los excluye expresamente.

La autenticación real con Apple y la pasada en un iPhone físico quedan fuera de esta entrega, conforme a los puntos solicitados por el usuario. Las pruebas con sesiones sintéticas no sustituyen esas validaciones.
