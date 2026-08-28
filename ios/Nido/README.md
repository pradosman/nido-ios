# Nido para iPhone

Aplicación nativa en SwiftUI para registrar y compartir el cuidado diario del bebé.

## Abrir y ejecutar

1. Instala Xcode desde la App Store y ábrelo una vez para completar su configuración.
2. Abre `Nido.xcodeproj`.
3. Selecciona el esquema **Nido** y un iPhone.
4. Pulsa **Run** (`⌘R`).

Todas las configuraciones utilizan `https://nido.momentumia.com`.

## Instalar en un iPhone

1. Conecta el iPhone al Mac y confía en el ordenador.
2. En **Signing & Capabilities**, elige tu equipo personal de Apple.
3. Selecciona el iPhone como destino y pulsa **Run**.

## Datos y funcionamiento

- Los cuidadores autorizados comparten el mismo perfil y los mismos registros.
- Los cambios pendientes se actualizan automáticamente cuando vuelve la conexión.
- Un sueño en curso sobrevive a cierres y reaperturas de la app.
- La app no incluye publicidad ni servicios de seguimiento.

## Verificación del núcleo

El núcleo de la aplicación también está disponible como paquete Swift para ejecutar sus pruebas:

```sh
swift test
```

El Mac necesita Xcode completo seleccionado como developer directory para ejecutar las pruebas del paquete y compilar el simulador.
