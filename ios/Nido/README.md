# Nido para iPhone

Aplicación nativa en SwiftUI para registrar y compartir el cuidado diario del bebé.

Requiere un Mac con Xcode completo compatible con Swift 6 y un iPhone o simulador con iOS 17 o posterior.

## Abrir y ejecutar

1. Instala Xcode desde la App Store y ábrelo una vez para completar su configuración.
2. Abre `Nido.xcodeproj`.
3. Selecciona el esquema **Nido** y un iPhone.
4. Pulsa **Run** (`⌘R`).

Para probar la app sin cuenta, pulsa **Explorar demostración**. La demo funciona localmente y no necesita ejecutar la API ni disponer de una base de datos.

En **Debug sobre simulador**, la configuración normal utiliza `http://127.0.0.1:1` para evitar conexiones accidentales a producción. Si necesitas probar de forma deliberada una cuenta real desde el simulador, añade `NIDO_SIMULATOR_PRODUCTION_OPT_IN=1` en **Scheme > Run > Arguments > Environment Variables**. Este ajuste selecciona `https://nido.momentumia.com` y no es necesario para la demo. El resto de configuraciones utiliza la dirección de producción. La política está definida en `AppConfiguration` y `UITestLaunchPolicy`.

## Instalar en un iPhone

1. Conecta el iPhone al Mac y confía en el ordenador.
2. En **Signing & Capabilities**, configura un equipo y perfiles de Apple que admitan las capacidades del proyecto, incluidos Iniciar sesión con Apple y App Groups. Un Personal Team gratuito no basta para mantener todas esas capacidades.
3. Selecciona el iPhone como destino y pulsa **Run**.

Para probar la app sin preparar perfiles de distribución o capacidades de una cuenta de desarrollador, utiliza el simulador y **Explorar demostración**.

## Datos y funcionamiento

- Los familiares autorizados comparten el mismo perfil y los mismos registros.
- Los cambios pendientes se actualizan automáticamente cuando vuelve la conexión.
- Un sueño en curso sobrevive a cierres y reaperturas de la app.
- La app no incluye publicidad ni servicios de seguimiento.

## Demostración sin cuenta

En la pantalla de acceso, pulsa **Explorar demostración**. El hogar de Lucía y Leo contiene datos sintéticos y permite utilizar los formularios, editar registros, consultar Historia y Ritmos, preparar informes y gestionar invitaciones ficticias. No necesita credenciales de Apple ni accede a un hogar real.

La franja superior identifica la demostración y permite **Reiniciar** sus datos o **Salir** a la pantalla de acceso. Las invitaciones de este modo solo representan el flujo local y su texto compartido las identifica como ficticias. Las preferencias y los registros están aislados; no se publican widgets, Live Activities ni recordatorios reales desde la demo. El acceso con Apple conserva el funcionamiento normal de las cuentas reales.

## Verificación del núcleo

El núcleo de la aplicación también está disponible como paquete Swift para ejecutar sus pruebas:

```sh
swift test
```

Los recorridos de interfaz se ejecutan desde Xcode con `⌘U` usando el esquema **Nido**, o por terminal:

```sh
xcodebuild test \
  -project Nido.xcodeproj \
  -scheme Nido \
  -destination 'platform=iOS Simulator,name=Nido Motion iPhone 16 Pro' \
  -only-testing:NidoUITests
```

El Mac necesita Xcode completo seleccionado como developer directory para ejecutar las pruebas del paquete y compilar el simulador.

La cobertura, el alcance y las comprobaciones que todavía requieren un iPhone real están documentados en [`docs/ios-test-strategy.md`](../../docs/ios-test-strategy.md).

Para reproducir la pasada premium completa, utiliza el esquema compartido **NidoAppearanceValidation** y el [ejecutor por fases de apariencia](../../docs/contrast-appearance-closeout-2026-10-17/validation.md). Configura el modo del simulador antes de cada proceso y exige resultados sin fallos ni omisiones; la compilación del simulador debe conservar la firma ad hoc para las pruebas del llavero.

## Flujo de desarrollo

Los cambios de comportamiento siguen TDD estricto: primero se reproduce el requisito o el fallo con una prueba en rojo, después se implementa el mínimo cambio para llevarla a verde y finalmente se refactoriza manteniendo toda la suite correcta. Las reglas completas y la evidencia requerida están en [`AGENTS.md`](../../AGENTS.md).

## Identidad de las compilaciones

La versión pública y el número de compilación son valores independientes. La aplicación muestra ambos desde su `Info.plist` y añade, cuando Git está disponible durante la compilación, la revisión corta y un indicador `dirty` para cambios rastreados. El script solo escribe `BuildMetadata.plist` dentro del producto derivado; no modifica fuentes ni el proyecto.

El proyecto mantiene un número base reproducible para desarrollo. Los incrementos de distribución pueden administrarse en Organizer o CI, que deben proporcionar un `CURRENT_PROJECT_VERSION` válido sin asumir que la interfaz de Xcode lo deriva automáticamente de Git.
