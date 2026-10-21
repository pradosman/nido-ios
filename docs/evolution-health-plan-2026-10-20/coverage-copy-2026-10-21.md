# Cobertura del día y unidades del gráfico

La captura horaria mostró `1 de 0 días terminados con registros` al incluir una toma de hoy. El cálculo era correcto: hoy todavía no es un día terminado. El error era reutilizar el texto de cobertura de periodos terminados para el total parcial del día.

## TDD y validación

- Rojo UI: `/tmp/nido-evolution-coverage-red.xcresult`; esperaba `Datos registrados hasta ahora` y recibió exactamente `1 de 0 días terminados con registros`.
- `EvolutionCareCoverageTests` comenzó rojo por ausencia del helper; las cinco pruebas de cobertura pasaron después de implementarlo. La regresión UI de cobertura y navegación pasó 2/2 en `/tmp/nido-evolution-v3-focused.xcresult`.
- La nota del gráfico horario también decía «días». Primero se extrajo su lógica sin cambiar las cadenas y se mantuvieron verdes las cinco pruebas. La nueva expectativa de unidades falló con `Los días…` frente a `Las horas…`; después del ajuste, las seis pruebas enfocadas pasan. La comprobación UI de esta nota se añadió como regresión de conexión de la vista, no como un rojo UI retroactivo.
- Suite Core completa: **248 pruebas, 39 suites**, verde en `/tmp/nido-evolution-core-final.log`.
- La captura necesaria confirmó `00`, `06`, `12`, `18` completos. El detalle oscuro también se revisó renderizado. La validación conjunta del candidato v4 y su Release se registrarán en el cierre de integración; este documento no los da por terminados.

## Comportamiento

| Contexto | Texto |
| --- | --- |
| Día actual | Datos registrados hasta ahora |
| Día histórico | Datos registrados del día |
| Hora seleccionada | Registros de la hora seleccionada |
| Periodo sin días terminados | Aún no hay días terminados en este periodo |
| Gráfico por horas | Las horas sin registros se muestran sin valor. |

Los periodos con días terminados conservan su cobertura numérica; semanas y meses conservan las unidades de sus notas. No se modifican agregación, registros elegibles ni aritmética.

## Reversión

La unidad local incluye el nuevo helper y sus pruebas, las llamadas de presentación en `EvolutionCareDetailView` y las expectativas correspondientes. Revertir solo esos cambios, conservando la redisposición accesible y el reloj LIVE anteriores. No se creó ningún commit. Para el texto documental no aplica TDD unitario; se valida contrastándolo con fuentes, logs y resultados citados.
