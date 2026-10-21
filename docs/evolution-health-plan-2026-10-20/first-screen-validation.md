# Hito 1 — validación de primera pantalla

**Estado: evidencia visual y focused final v5 reunidas, Release firmado compilado; siguen pendientes la matriz 208 y la aprobación explícita del usuario.** El plan de Evolución está aprobado; eso no aprueba la pantalla ni autoriza iniciar el detalle de métricas. El trabajo de detalle permanece detenido hasta la aprobación del usuario.

## Alcance y límites

La previsualización se activa solo en DEBUG mediante `goalpreview`, con un store nuevo de preview, wrapper de Trends y fixtures en `EvolutionDesignPreviewView`. La ruta live de Trends permanece sin cambios. El título Dock puede decir “Evolución” en preview; el default de producción sigue siendo “Ritmos” y la geometría del Dock no cambia. No se modifican datos reales, API ni esquema.

## Evidencia de TDD

- **Core:** [core-validation.md](core-validation.md) registra el rojo inicial por contrato ausente y el rojo funcional de sueño futuro: se esperaban 3.600 segundos y se observaron 86.400. Después pasaron 5 pruebas enfocadas y la suite core de 214 pruebas en 32 suites. Esa evidencia valida la capa de dominio, no la pantalla.
- **Primer rojo UI:** al tocar Trends no aparecía el preview (`tab-trends` en `/tmp/nido-evolution-preview-2026-10-20/red-focused.log`). El xcresult es incompleto y no tiene `rootInfo` válido; se conserva el log, pero no se presenta como xcresult válido.
- **v2:** 5 pruebas UI: 3 pasaron y 2 fallaron. Los previews Light/Dark y el default “Ritmos” pasaron; el estado vacío producía fechas AX vacías y el escenario XXXL falló. Root observó barras de cuidado en blanco aunque las cifras estaban presentes.
- **Rojo de barras antes del arreglo:** `/tmp/nido-evolution-preview-2026-10-20/care-bars-red.xcresult` falló 1 prueba. Con las tarjetas visibles, las tres aserciones de conteo dieron 0/0/0; las capturas mostraban recorte del 32 % a la derecha y barras entre 35–80 % del alto, con croma sRGB >55 y máximo >100. El control exige >8.
- **v3:** el intento con `xDouble` no resolvió el fallo de píxeles. La solución para el vacío —omitir texto vacío y eje Y— pasó 1/1 (`v4-empty.xcresult`).
- **v4:** cambiar a `xString`, siete categorías de dominio y eje Y desde cero hizo pasar la misma prueba pixel 1/1 (`v4-pixel.xcresult`), con conteos 1931/2201/1661; el estado vacío pasó 1/1 (`v4-empty.xcresult`). Root y reviewer aprobaron las barras Light v4. La pantalla Dark final sigue pendiente.

## Contención, XXXL y navegación

Un `isHittable` parcial no demuestra que el contenido quepa en pantalla. El rojo `/tmp/nido-evolution-preview-2026-10-20/xxxl-containment-red.xcresult` muestra tomas fuera de la ventana y peso debajo del Dock, aunque `hittable` era true. Tester corrige el helper con comprobaciones de contención y gestos seguros, preservando las expectativas; no se debilitan aserciones para obtener verde. El caso XXXL sigue sin aprobar.

Root observó además que el encabezado manual queda bajo el reloj en AX. La recomendación de arquitectura es usar `.navigationTitle("Evolución")` con presentación nativa grande y mover el avatar a toolbar, sin parches de desplazamiento. Tester añadirá una séptima prueba para el comportamiento de navegación nativa y debe obtener su rojo antes de que Root implemente el cambio. Ese cambio aún no está implementado en v5.

El metadata actual tiene seis IDs (204/207 planeados); al añadir la séptima prueba el worker lo actualizará a 205/208. La matriz 208 no está completa; los resultados parciales están anotados abajo. La última corrida v2 (5 pruebas) no valida las correcciones posteriores.

## Qué falta para cerrar este hito

1. Terminar los rojos previos y sus correcciones: contención XXXL, navegación nativa, estado vacío y barras.
2. Obtener resultados focused válidos y la matriz completa con metadata actualizado.
3. Revisar la pantalla final en Light/Dark y texto grande, con datos y vacía; incluir las capturas y sus estados de accesibilidad.
4. Presentar esa única pantalla al usuario y esperar su aprobación explícita antes de iniciar el detalle de métricas.

## Límite de rollback y alcance de evidencia

El rollback se limita a los archivos nuevos de preview/pruebas y a los hunks de `RootView`, `NidoStore`, `TrendsView` y Dock que pertenecen a este hito. Se preservan cambios preexistentes fuera de esos hunks. No se han creado commits ni se han hecho operaciones en teléfonos o VPS. El plan aprobado está en [plan.md](plan.md); esto no supone aprobación de la pantalla.

## Estado v5 — intento enfocado inicial

Root inspeccionó la primera pantalla v5 en Light/Dark y el scroll XXXL: las tarjetas y barras se ven correctas; el título nativo grande/compacto y el reloj con material nativo son legibles. Esta inspección interna no equivale a la aprobación del usuario.

`v5-class-7.xcresult` fue el intento inicial: 1 pasó, 6 fallaron, 0 skips. Cinco aserciones consultaban `navBar.label` vacío aunque el título nativo hijo era visible; otra prueba necesitaba desplazar la tarjeta individual. El reintento corregido de harness se registra en el checkpoint siguiente.

La matriz 208 aún no se ha ejecutado. Para cerrar siguen pendientes la prueba focused corregida, regresiones, compilación Release y revisión de artefactos. El alcance sigue limitado al preview DEBUG de primera pantalla con datos de ejemplo; no se han añadido detalle de métricas ni personalización/fijación. Sin commit, teléfono ni deploy. La pantalla debe recibir aprobación explícita del usuario antes de comenzar el siguiente hito.

## Checkpoint actualizado

El reintento focused corregido `v5-harness-class7.xcresult` pasó 7/7, 0 fallos y 0 skips. Conserva los umbrales pixel y la contención; el selector del título consulta el hijo `staticText`. Un error transitorio de destination de Xcode se resolvió seleccionando explícitamente OS 26.5.

Root inspeccionó el scroll XXXL y confirmó cinco valores de cuidado completamente por encima del Dock. La captura de crecimiento en tamaño normal es parcial y no se presentará como evidencia completa.

El lote de regresión original dio 73 pasadas, 2 fallos y 1 skip; se conserva sin reinterpretarlo como verde. Los dos fallos fueron de `GoalDesignPreview` ejecutados en Light, aunque requerían Dark: el launch no fija apariencia y el grupo de datos estaba mal preparado. La rerun explícita en Dark pasó 2/2; el pixel de Dark midió RGB 55,38,46, luminancia 46. Navigation pasó 2/2 y Dock 2/2.

Las reruns confirmadas y combinadas representan 76 casos únicos verdes en sus configuraciones correctas: 65 Snapshot, 7 GoalDesignPreview y 4 Dock/Navigation. El caso con Reduce Motion omitido pasó 1/1 con `ReduceMotionEnabled=1`; al terminar se restauró `ReduceMotionEnabled=0` y Light. También pasó Evolution 7/7; Core queda en 214 pruebas verdes. Esto no convierte en verde el lote original 73/2/1 ni acredita una matriz 208 completa. Aún faltan Release y la captura visual final. La pantalla sigue pendiente de aprobación explícita del usuario; no avanzar al detalle de métricas.

## Verificación final v5

Tester compiló el Release firmado con `BUILD SUCCEEDED` y 0 errores (`/tmp/nido-evolution-preview-2026-10-20/release-build-v5.log`). Root verificó con `xcresulttool` el focused `v5-harness-class7.xcresult`: 7 pasadas, 0 fallos, 0 skips. El lote original de regresión 73/2/1 queda conservado; la rerun Dark fue 2/2, 0 fallos, 0 skips. Los 76 casos únicos verdes por fases están descritos arriba, pero no constituyen la matriz completa 208.

Root inspeccionó las capturas AX v5 completas y las vistas nativas Light, Dark y vacía. La captura de crecimiento en tamaño normal sigue siendo parcial y no debe usarse como representación completa de esa pantalla. Estos resultados no sustituyen la revisión ni aprobación del usuario.

Los hashes canonical/mirror coinciden en preview `42d811c0…d655` y tests `bf5fa145…f02a`. El rollback sigue limitado a la preview DEBUG y los hunks de este hito; no hubo commit, instalación física ni deploy. La ruta live, los datos reales y las preferencias de fijación quedan fuera de alcance. La matriz 208 y la aprobación del usuario continúan pendientes.
