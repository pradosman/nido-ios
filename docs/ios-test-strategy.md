# Estrategia de pruebas de Nido para iPhone

## Estado verificado (8 de octubre de 2026)

La aplicación cuenta con dos capas automatizadas:

- 115 pruebas del paquete Swift superadas en la última ejecución completa registrada tras las correcciones del timeline y de las pruebas de interfaz. Se usó un directorio de compilación aislado tras un error en la base de compilación local del repositorio. Cubren modelos, métricas, formularios, caché, copias de seguridad y contratos HTTP, entre otras áreas.
- 41 pruebas de interfaz XCTest en cada simulador aislado, iPhone SE (3.ª generación) e iPhone 17 Pro: 38 superadas, 0 fallidas y 3 omitidas por requerir credenciales en cada dispositivo. Resultados: `/tmp/nido-au12b-full-se.xcresult` y `/tmp/nido-au12b-full-pro.xcresult`, después del commit `73e0e1c`. Incluyen navegación, registro, edición, controles compactos y cancelación de una restauración sintética.
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
  CODE_SIGNING_ALLOWED=NO
```

También pueden ejecutarse desde Xcode con `⌘U` usando el esquema **Nido**.

Las 3 pruebas omitidas en cada simulador requieren credenciales y un backend reales; un resultado verde en el simulador no equivale a haber comprobado esos recorridos. El ensayo de medicación con teclado a tamaños Large y XXXL pasó 2/2 en una comprobación temporal aislada: dosis y notas eran alcanzables mediante desplazamiento dentro del formulario. Esa comprobación no se incorporó a la suite del repositorio.

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

La restauración sintética en simulador sí comprobó que «Cancelar» es visible, cierra la alerta y conserva los dos registros originales; no ejecutó «Restaurar». La captura de una Live Activity sintética de más de diez horas comprobó segundos completos en Dynamic Island y legibilidad en modo oscuro, pero no sustituye las verificaciones de dispositivo, servidor y accesibilidad anteriores. Los contratos locales de API y PostgreSQL anteriores tampoco constituyen una ejecución de integración con el servicio real en esta pasada.
