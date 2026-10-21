# Límites de integración

La continuación aprobada incluye detalles de las cinco métricas, edición de datos fijados e integración de Evolución con los datos de Nido. No hay una segunda aprobación obligatoria después de Sueño.

El resumen comparte presentación con la revisión aprobada. Sueño, Tomas y Pañales comparten una plantilla con entradas, fecha actual, calendario familiar y permisos explícitos; las medidas usan el detalle de crecimiento existente. Los periodos de cuidados son naturales y los de crecimiento conservan sus rangos existentes, con fechas explícitas.

Los fijados se guardan en los UserDefaults inyectados del store, con scope de cuidador autenticado y bebé `primary`. Nido todavía no ofrece un identificador estable multibebé. No usar nombre o cumpleaños como identidad; no guardar preferencias bajo un cuidador anónimo. El vacío elegido por el usuario es válido y el catálogo sigue accesible.

Los escenarios DEBUG `evolution-design-summary` y `evolution-design-empty` conservan la revisión de solo lectura sin tarjetas interactivas. `evolution-design-sleep` permite abrir el detalle y sus registros con una fuente inmutable; no ofrece acciones reales de mutación. La anotación anterior sobre un escenario `evolution-design-interactive` de cinco rutas no correspondía al código recuperado y no se considera una función validada. `evolution-live` prepara un store local aislado para probar los flujos reales y su persistencia. La función LIVE se integra en la ruta normal de producción, sin depender de ese escenario. Ningún ID de los ejemplos inmutables se entrega al editor real.

`GrowthSeriesDetailView` admite una fuente inmutable opcional para el escenario de ejemplo. Su inicializador habitual conserva las mediciones reconciliadas y las operaciones reales de alta, edición y borrado del store. Las acciones de filas no se sustituyen por closures vacíos.

Carga, ausencia de registros, desconexión y cambios pendientes son estados distintos. El agregado de pendientes se expone mediante una propiedad estrecha del store; no se hacen públicas las colas privadas. Los registros cargados no garantizan cobertura histórica completa: conservar las expresiones «registrado» y la cobertura del periodo.

La instrucción posterior del usuario del 21 de octubre autoriza commits, integración en `main` y publicación en App Store; se registra en `../evolution-release-2026-10-21.md`. No se han solicitado instalaciones físicas. Las compilaciones y pruebas se coordinan en el mirror hidratado y un único simulador de QA; cada archivo se sincroniza individualmente con comparación SHA-256 para evitar los placeholders de FileProvider.
