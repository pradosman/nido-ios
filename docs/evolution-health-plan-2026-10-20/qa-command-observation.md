# Duplicación observada en el comando de QA

El 20 de octubre, `pgrep -fl xcodebuild` mostró que la ejecución `evolution-live-summary-green` incluía la acción `test` dos veces: una inmediatamente después de `xcodebuild` y otra al final de los argumentos, después de `-resultBundlePath`.

Esto es una causa plausible de las sesiones repetidas y recompilaciones dentro de un mismo comando que se habían observado. No se atribuyen automáticamente a retries ni se cuentan como casos únicos adicionales. Los logs anteriores siguen siendo evidencia solo para las aserciones causales y las sesiones que efectivamente contienen.

QA ha sido informado para dejar una sola acción por comando. Para permitir trabajo en paralelo, se recomienda congelar hashes y producto con `build-for-testing`, después ejecutar `test-without-building`; las modificaciones del siguiente candidato no alteran el binario ya compilado. Ningún cambio de fuentes debe coincidir con la compilación cuya evidencia se esté capturando.
