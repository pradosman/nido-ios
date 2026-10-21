# Inventario de pruebas de Evolución

Estado intermedio, 20 de octubre de 2026. No acredita la ejecución de toda la matriz del simulador.

Se incorporaron los nueve selectores de `SleepEvolutionDetailUITests` al inventario del gate. Una prueba de Node obtiene los nombres desde el código fuente y comprueba que cada uno figure exactamente una vez en las fases. Las pruebas con apariencia propia conservan su escenario explícito.

Rojo: la nueva comprobación falló con `Missing sleep detail baseline test: NidoUITests/SleepEvolutionDetailUITests/testSleepCardOpensNativeSleepDetail` antes de modificar el inventario y los recuentos del plan.

Verde enfocado y suite: `node --test Scripts/appearance-phase-plan.test.mjs Scripts/appearance-result-validation.test.mjs`, 31 pruebas aprobadas, cero fallos. Inventario intermedio: 214 selectores únicos, 217 ejecuciones previstas; esto es planificación, no resultado de ejecución iOS.

Los tres archivos del plan y del inventario se sincronizaron desde el mirror hidratado al proyecto y sus SHA-256 coinciden. Los nuevos flujos de integración y fijados se incorporarán al congelar sus selectores.

No se ha creado commit. El límite reversible de esta unidad son `Scripts/appearance-phase-plan.mjs`, `Scripts/appearance-phase-plan.test.mjs` y `Scripts/appearance-test-baseline.json`; no modifica datos ni comportamiento de Nido.
