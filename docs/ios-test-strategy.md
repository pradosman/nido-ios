# Estrategia de pruebas de Nido para iPhone

## Actualización del 17 de octubre de 2026

La rama premium tiene una pasada de 167 métodos nativos aprobados sin omisiones: 111 UI claros, 3 integraciones HTTP con PostgreSQL aislado, 43 Snapshot y 10 UI oscuros. Los contratos del ejecutor aprobaron 20/20. Las dos auditorías nativas completas de contraste están resueltas; el modo oscuro se acredita con píxeles de la captura real. El [cierre de contraste y apariencia](contrast-appearance-closeout-2026-10-17/validation.md) conserva resultados, incidencias intermitentes y las instrucciones reproducibles con el esquema `NidoAppearanceValidation`.

El estado del 8 de octubre que sigue se conserva como historial; sus recuentos y omisiones no describen la pasada premium actual. La validación física y la identidad real con Apple siguen pendientes y no se sustituyen con sesiones sintéticas.

## Estado verificado (8 de octubre de 2026)

La aplicación cuenta con pruebas automatizadas, pero la evidencia más reciente no cubre todos los dispositivos ni las integraciones reales:

- Paquete Swift (8 de octubre de 2026): 116 pruebas superadas en 15 suites desde la copia de fuentes de AU27 cotejada por SHA-256, con directorio de compilación aislado. No es una ejecución nueva desde el árbol de trabajo activo.
- Esquema completo en iPhone 17 Pro (8 de octubre de 2026, iOS 26.5): 54 pruebas totales, 49 superadas, 5 omitidas y 0 fallidas (`/tmp/au27-ui-full.6lVdIv/results/iphone17pro-full-scheme.xcresult`). El destino UI ejecutó 52 pruebas; las omisiones incluyen dos diagnósticos nativos `.all` optativos y tres casos que requieren credenciales. Una omisión no equivale a una aprobación.
- iPhone SE (3.ª generación), suite completa corregida (8 de octubre de 2026, iOS 26.5): 52 pruebas totales, 46 superadas, 6 omitidas y 0 fallidas (`/tmp/au27-ui-full.6lVdIv/results/iphone-se3-full-latest.xcresult`). El resultado confirma el modelo `iPhone SE (3rd generation)`. Las omisiones fueron 3 pruebas de backend real que requieren credenciales, 2 diagnósticos `.all` optativos sin filtrar y 1 prueba de hit regions en modo oscuro porque no se pudo confirmar el renderizado oscuro. La comprobación enfocada anterior pasó 2/2 (`/tmp/au27-ui-full.6lVdIv/results/iphone-se3-focused.xcresult`).
- La ejecución completa SE3 anterior fue una RED y no debe citarse como aprobada: 52 pruebas, 45 superadas, 2 fallidas y 5 omitidas (`/tmp/au27-ui-full.6lVdIv/results/se3.xcresult`). Las dos fallas detectaron problemas del arnés de prueba antes de su corrección.
- Como antecedente histórico posterior al commit `73e0e1c`, las ejecuciones del 8 de octubre a las 00:42 CEST (iPhone SE 3.ª generación) y 00:49 CEST (iPhone 17 Pro) registraron 41 pruebas cada una, con 38 superadas, 3 omitidas por credenciales y 0 fallidas (`/tmp/nido-au12b-full-se.xcresult` y `/tmp/nido-au12b-full-pro.xcresult`). Esos recuentos son anteriores a AU27 y no resuelven la suite completa SE3.
- 2 pruebas de snapshots existentes superadas; inspección visual de las 12 presentaciones modales; compilación del esquema `Nido` para el simulador superada.
- 18 pruebas de contratos y sesión de la API superadas en un proceso local sintético, sin variables de conexión ni servicio desplegado. Por separado, las migraciones y el contrato con PostgreSQL real superaron una ejecución local aislada; no se conservó el recuento TAP individual de esa prueba.

El 75 % de cobertura global de `NidoCore` y el 90–100 % de sus archivos de dominio principales proceden de una medición anterior; no se recalcularon en esta verificación y no deben presentarse como cobertura actual. El porcentaje global también incluye adaptadores de Apple que no se ejecutan en macOS, como Keychain, WidgetKit y notificaciones.

Estas pruebas no convierten retrospectivamente el código existente en TDD. Fijan su comportamiento actual mediante pruebas de caracterización. Todo comportamiento nuevo o defecto corregido sí debe seguir rojo, verde y refactorización, como establece `AGENTS.md`.

## Ejecutar las pruebas

Desde `ios/Nido`:

```sh
swift test
```

Para obtener cobertura del núcleo:

```sh
swift test --enable-code-coverage
xcrun llvm-cov report \
  .build/debug/NidoCorePackageTests.xctest/Contents/MacOS/NidoCorePackageTests \
  -instr-profile .build/debug/codecov/default.profdata \
  -ignore-filename-regex='Tests|runner.swift'
```

Para ejecutar los recorridos de interfaz en un simulador disponible:

```sh
xcodebuild test \
  -project Nido.xcodeproj \
  -scheme Nido \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NidoUITests \
  CODE_SIGN_IDENTITY=-
```

También pueden ejecutarse desde Xcode con `⌘U` usando el esquema **Nido**.

La firma ad hoc del simulador permite que las pruebas que usan el llavero real conserven sus permisos. Desactivar la firma con `CODE_SIGNING_ALLOWED=NO` produjo `errSecMissingEntitlement` y cinco fallos de preparación de sesiones; el mismo target Snapshot pasó 43/43 con firma habilitada.

Los tres recorridos que antes se omitían por credenciales ya se ejecutaron con sesiones sintéticas de Nido, HTTP local y PostgreSQL aislado: 3/3 aprobados. Esto verifica el contrato de Nido y no sustituye una autenticación real con Apple. El [cierre de simuladores](simulator-closeout-2026-10-17/validation.md) conserva el historial de resultados y las auditorías de accesibilidad sin filtros. El ajuste posterior de «Ver todo» a `.body` pasó las dos auditorías completas clara y oscura; la evidencia y la comprobación de apariencia se recogen en [el cierre de contraste y apariencia](contrast-appearance-closeout-2026-10-17/validation.md).

El ensayo de medicación con teclado a tamaños Large y XXXL pasó 2/2 en una comprobación temporal aislada: dosis y notas eran alcanzables mediante desplazamiento dentro del formulario. Esa comprobación no se incorporó a la suite del repositorio.

### Contratos locales de API

Desde la raíz del repositorio, la ejecución sintética en proceso fue:

```sh
env -u DATABASE_URL -u NIDO_REAL_POSTGRES_URL -u NODE_ENV node --test tests/nido-households.contract.test.mjs tests/nido-apple-auth.contract.test.mjs tests/apple-session-handler.test.mjs
```

Terminó con código 0: 18 pruebas superadas, 0 fallidas y 0 omitidas. En una comprobación separada, las migraciones y `tests/postgres-real.contract.test.mjs` terminaron con código 0 contra un contenedor efímero local PostgreSQL 17.10 con almacenamiento `tmpfs`, eliminado al terminar. No se conservó el detalle TAP ni un recuento por prueba para ese contrato. No se usaron la base de producción, credenciales remotas ni un servidor desplegado. Estas comprobaciones no demuestran HTTP desplegado, identidad Apple real ni integración desde un iPhone con la API o el VPS.

Una comprobación HTTP adicional arrancó la API local con ese PostgreSQL efímero: la migración y `npm run build` terminaron con código 0; `GET /api/nido/status` respondió 200 con las capacidades activadas, `GET /api/nido` sin autenticar respondió 401, y `POST /api/nido/auth/apple/challenge` respondió 201 con `challengeID`, `nonce` y `expiresAt` no vacíos. La API y el contenedor se detuvieron sin dejar puertos abiertos. Esto no prueba una sesión Apple/JWKS, una invitación con credenciales, un iPhone físico, el VPS ni HTTP de producción.

## Qué protege cada capa

| Área | Evidencia automatizada |
| --- | --- |
| Sueño, tomas, pañales y cuidados | Modelos, textos generados, intervalos y métricas |
| Últimos valores introducidos | Valores compartidos por bebé y compatibilidad con registros antiguos |
| Edición y sincronización | Identidad de registros, reconciliación local/remota y contratos HTTP |
| Persistencia sin conexión | Lectura, escritura, directorios y datos corruptos de la caché |
| Onboarding | Campos esenciales y bloqueo de creación incompleta |
| Navegación | Hoy, Historia, Ritmos y Ajustes |
| Sueño manual | Fechas Desde/Hasta sin un campo de fecha redundante |
| Sueño activo | Acceso a la edición de su fecha y hora de inicio |

## Comprobaciones que siguen siendo de dispositivo

Antes de afirmar que la versión está lista para producción, falta verificar y registrar:

- navegación y acciones principales con VoiceOver, incluyendo orden de foco y etiquetas;
- legibilidad y estados de widgets en apariencias tintada y transparente; la falta de control CLI en el simulador y el Mac bloqueado impidieron reproducir esos modos, sin demostrar un defecto de color;
- restauración y cancelación con datos controlados en un dispositivo real, sin poner en riesgo datos personales;
- aparición, actualización y cierre de Live Activities en Dynamic Island y pantalla bloqueada;
- instalación y actualización de widgets;
- permisos y entrega de notificaciones;
- persistencia de credenciales en Keychain tras reinstalaciones y cambios de firma;
- invitación de otro familiar y sincronización entre dos dispositivos contra la API real;
- funcionamiento sin conexión, reconexión y resolución de cambios pendientes.

Aunque la suite completa SE3 pasó, sus seis omisiones siguen sin verificarse y la pasada no demuestra que el modo oscuro se haya renderizado correctamente. Tampoco hay evidencia de navegación real con VoiceOver, de los estados tintado/transparente de widgets, de un iPhone físico ni de API desplegada o identidad Apple real; el diagnóstico `.all` permanece abierto.

La restauración sintética en simulador sí comprobó que «Cancelar» es visible, cierra la alerta y conserva los dos registros originales; no ejecutó «Restaurar». La captura de una Live Activity sintética de más de diez horas comprobó segundos completos en Dynamic Island y legibilidad en modo oscuro, pero no sustituye las verificaciones de dispositivo, servidor y accesibilidad anteriores. Los contratos locales de API y PostgreSQL anteriores tampoco constituyen una ejecución de integración con el servicio real en esta pasada.
