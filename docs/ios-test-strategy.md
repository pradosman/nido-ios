# Estrategia de pruebas de Nido para iPhone

## Estado actual

La aplicación cuenta con dos capas automatizadas:

- 41 pruebas de caracterización y regresión con Swift Testing para modelos, métricas, valores recordados de formularios, caché, copias de seguridad y contratos HTTP.
- 4 pruebas de interfaz con XCTest para onboarding, navegación, registro de sueño y edición del inicio de un sueño activo.

La cobertura de líneas del paquete `NidoCore` es del 75 %. Los archivos con lógica de dominio principal están entre el 90 % y el 100 %. El porcentaje global incluye adaptadores de Apple que no se ejecutan en macOS, como Keychain, WidgetKit y notificaciones.

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

Antes de una entrega deben probarse en un iPhone real:

- aparición, actualización y cierre de Live Activities en Dynamic Island y pantalla bloqueada;
- instalación y actualización de widgets;
- permisos y entrega de notificaciones;
- persistencia de credenciales en Keychain tras reinstalaciones y cambios de firma;
- invitación de un segundo cuidador y sincronización entre dos dispositivos contra la API real;
- funcionamiento sin conexión, reconexión y resolución de cambios pendientes.

Estas integraciones dependen del sistema operativo, la firma, las notificaciones y el servidor. Las pruebas unitarias deben cubrir sus decisiones internas, pero no sustituyen esta comprobación final.
