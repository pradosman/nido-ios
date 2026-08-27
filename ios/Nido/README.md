# Nido para iPhone

Aplicación nativa en SwiftUI que comparte datos con la versión web de Nido.

## Abrir y ejecutar

1. Instala Xcode desde la App Store y ábrelo una vez para completar su configuración.
2. Abre `Nido.xcodeproj`.
3. Selecciona el esquema **Nido** y un simulador de iPhone.
4. Pulsa **Run** (`⌘R`).

La configuración **Debug** usa `http://127.0.0.1:43133`, por lo que el servidor web local debe estar iniciado. En un iPhone físico, sustituye esa dirección en los Build Settings del target por la IP local del Mac, por ejemplo `http://192.168.1.20:43133`.

La configuración **Release** usa `https://nido.momentumia.com`.

## Instalar en un iPhone

1. Conecta el iPhone al Mac y confía en el ordenador.
2. En **Signing & Capabilities**, elige tu equipo personal de Apple.
3. Selecciona el iPhone como destino y pulsa **Run**.

## Datos y funcionamiento sin conexión

- El perfil y los registros se guardan primero en el iPhone.
- Los cambios pendientes se sincronizan automáticamente con la API de Nido.
- Un sueño en curso sobrevive a cierres y reaperturas de la app.
- La app no incluye publicidad ni servicios de seguimiento.

## Verificación del núcleo

El código de modelos, métricas, API y caché también vive como paquete Swift para poder validarlo sin arrancar la interfaz:

```sh
swift test
```

El Mac necesita Xcode completo seleccionado como developer directory para ejecutar las pruebas del paquete y compilar el simulador.
