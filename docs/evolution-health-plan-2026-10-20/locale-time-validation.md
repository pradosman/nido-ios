# Distinción de horas en formatos de 12 horas

La revisión independiente detectó que omitir AM/PM no fuerza el ciclo de 24 horas. En `en_US`, la 01:00 y las 13:00 se mostraban ambas como `01` en el eje y como `01:00` en registros.

TDD real: primero se añadió `twelveHourLocaleDistinguishesMorningAndAfternoon`. La ejecución enfocada falló con dos expectativas causales: `01 != 01` y `01:00 != 01:00`. Después se cambió el formato a AM/PM abreviado según locale, conservando el calendario y la zona familiar. En español se mantiene el ciclo de 24 horas.

Verde: las tres pruebas de `SleepEvolutionDateFormattingTests` aprobaron, incluyendo las expectativas existentes de Madrid/Honolulu y medianoche. La suite completa `swift test` terminó con código 0. La prueba nueva añade un caso al inventario Core de 239; el recuento final se confirmará en el gate congelado.

Sincronización verificada por SHA-256: formato `adda2e75152f5db9f1862025ccb0263a7cbb49c63f01f3a7a43754d7e40046fc`, pruebas `906f4813bf7395da6d423a48e983c7cf765762289d4f6a15b5410a7c884c74a8`. Coinciden mirror y proyecto.

No hay commit. Unidad reversible: `Nido/Core/SleepEvolutionDateFormatting.swift` y `Tests/NidoCoreTests/SleepEvolutionDateFormattingTests.swift`. No modifica datos. La revisión visual final del eje pertenece al gate de integración.
