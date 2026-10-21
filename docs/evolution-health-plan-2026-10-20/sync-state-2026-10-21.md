# Estado de sincronización en Evolución

El resumen LIVE separa carga, ausencia de registros guardados, desconexión y cambios pendientes. La desconexión y los cambios pendientes se muestran como señales independientes, por lo que una caché vacía sin conexión no se presenta como una confirmación del servidor. El indicador de pendientes agrega altas, ediciones y borrados de cuidados, cambios pendientes de BabyCare (incluido crecimiento) y la mutación durable de Sueño. El perfil queda fuera porque no forma parte de los datos de Evolución.

## TDD y validación

- **Rojo — modelo:** `swift test --package-path ios/Nido --filter EvolutionSyncStatusTests` falló con `cannot find 'EvolutionSyncStatus' in scope`.
- **Verde — modelo:** los dos casos de `EvolutionSyncStatusTests` pasaron, incluida la combinación de caché vacía, desconexión y cambios pendientes.
- **Rojo — cola durable de Sueño:** el test de reintento falló con `RegistrationMutationService has no member 'hasPendingSleepMutation'`.
- **Verde — cola durable:** `failedSleepUploadRemainsDurableAndRetries` confirmó pendiente después del fallo de transporte y limpio tras sincronizar el reintento.
- **Rojo — resumen LIVE:** `EvolutionSyncStatusUITests` cargó el resumen aislado y falló porque faltaban `evolution-offline-status` y `evolution-pending-status`.
- **Verde — interfaz:** el mismo test pasó con ambas etiquetas presentes por separado.
- **Verde — store real:** dos pruebas de `EvolutionSyncIntegrationTests` pasaron: cambios de crecimiento pendientes sin conexión y una mutación durable de inicio de Sueño encolada por un transporte offline.
- **Suite Core completa:** 242 pruebas en 38 suites pasaron.
- **Escenario real:** la interfaz se ejecutó en `evolution-live` con el fixture de prueba `pending-offline`, en el simulador de QA. No se hizo una instalación física.

Las ejecuciones Xcode retenidas para rojo, verde y store usaron el snapshot aislado `/tmp/nido-sync-state-20261021` y el simulador QA `4A7A40BF-4FEE-41F7-9019-1D1F5F5B04AD`. Los SHA-256 de los ocho archivos de código y pruebas comparados entre el workspace y el snapshot coincidieron. Los resultados detallados están en `ui-red.log`, `ui-green.log`, `store-final.log` y `core-full.log` bajo ese directorio temporal.

La consulta durable de Sueño puede fallar al leer el archivo de estado; ahora el resumen omite el indicador de pendientes cuando esa lectura falla. El resumen no presenta un mensaje de sincronización correcta.

El test de integración del store para Sueño se añadió como regresión después de implementar la composición entre store y servicio; el rojo inicial del store cubrió el accessor ausente, y el accessor durable sí siguió rojo→verde. No se creó ningún commit. El límite de rollback de comportamiento es el conjunto de cambios de esta unidad: modelo/servicio/store, resumen LIVE y sus pruebas; este documento conserva la evidencia.
