# Flujo de desarrollo de Nido

## TDD obligatorio

Todo cambio de comportamiento se desarrolla con un ciclo **rojo → verde → refactor**:

1. Escribir primero la prueba automatizada más pequeña que describa el resultado esperado.
2. Ejecutarla y conservar evidencia de que falla por la razón correcta antes de modificar código de producción.
3. Implementar únicamente lo necesario para hacerla pasar.
4. Ejecutar la prueba enfocada y después la suite completa.
5. Refactorizar sin cambiar el comportamiento y volver a ejecutar las pruebas.

Reglas:

- Una prueba añadida después de la implementación es una prueba de regresión, no TDD. Debe declararse como tal.
- No se eliminan, debilitan ni adaptan expectativas correctas para hacer pasar una implementación.
- Cada corrección de un bug comienza reproduciéndolo con una prueba fallida.
- La lógica Swift comprobable debe vivir fuera de las vistas cuando eso permita probarla con Swift Testing.
- Los flujos que solo puedan demostrarse en interfaz usarán XCTest UI. Si todavía no existe el soporte necesario, se crea como parte del mismo trabajo antes de implementar el flujo.
- Los cambios de API empiezan por una prueba del contrato HTTP.
- Cada commit de comportamiento incluye su prueba y forma una unidad reversible.

Para cambios sin comportamiento ejecutable —documentación, recursos gráficos o metadatos— se define antes de editar una validación proporcional: renderizado y comparación visual, compilación del catálogo, validación de configuración o revisión reproducible. La entrega debe indicar expresamente que no aplica TDD unitario y qué comprobación lo sustituye.

## Evidencia mínima de entrega

Cada cambio debe informar:

- prueba roja y motivo exacto del fallo;
- prueba verde enfocada;
- suite completa;
- compilación o escenario real correspondiente;
- límite de rollback del commit.

No se considera terminado un cambio si solo compila.
