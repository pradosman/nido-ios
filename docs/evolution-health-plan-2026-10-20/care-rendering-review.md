# Construcción de datos del detalle

La revisión de arquitectura encontró que la propiedad calculada `snapshot` ejecutaba `EvolutionCareSnapshot.build` cada vez que la usaban los helpers, valores, cobertura y cierres de Charts. SwiftUI no memoriza automáticamente esa propiedad. Había más de veinte sitios directos, además de los accesos indirectos de las etiquetas.

Para Sueño anual, la agregación recorre los intervalos por día y realiza uniones. Con miles de intervalos, repetir toda esa operación durante el mismo renderizado es trabajo evitable. Es una observación del código y de su coste algorítmico; no es una medición de latencia en un dispositivo.

Se ha encargado una refactorización sin cambio de comportamiento: el contenedor que posee rango, ancla y selección construye una instantánea por renderizado y entrega ese valor inmutable a una subvista de presentación. Todos los helpers y cierres leen esa instantánea. No se introduce caché, estado derivado, `.task` ni actualización asíncrona.

La aceptación requiere revisión del código resultante y repetir las pruebas existentes de rangos, selección, edición y retorno. No se inventa una prueba roja de comportamiento para una refactorización que conserva los resultados; la mejora acreditable será eliminar construcciones redundantes. La percepción de fluidez exige validación posterior en el escenario correspondiente.
