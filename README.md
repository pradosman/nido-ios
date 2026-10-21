# Nido para iPhone

Nido es una aplicación nativa para registrar y compartir el cuidado diario del bebé. Permite consultar la actividad, registrar alimentación y sueño, revisar el historial y la evolución, preparar informes y coordinar el cuidado familiar.

## Funcionalidades principales

| Funcionalidad | Uso |
|---|---|
| Hoy | Consulta de actividad del día y acceso al registro de cuidados |
| Alimentación, sueño, pañales y cuidados | Alta y edición de registros, con seguimiento del sueño en curso |
| Historia | Consulta por fecha, filtros y detalle de los registros |
| Evolución | Resúmenes y gráficas a partir de los registros disponibles |
| Cuidado familiar | Perfil compartido y cuidadores autorizados en el uso con cuentas reales |
| Informes | Preparación de información para compartir desde la aplicación |
| Demostración | Recorrido local con datos sintéticos, sin cuenta ni contraseña |

## Probar la aplicación

Necesitas un Mac con Xcode completo compatible con Swift 6 y un simulador de iPhone con iOS 17 o posterior. Clona el repositorio cuando dispongas de acceso, abre [`ios/Nido/Nido.xcodeproj`](ios/Nido/Nido.xcodeproj) en Xcode, selecciona el esquema **Nido** y el simulador, y pulsa **Run**. Las instrucciones de ejecución, firma e instalación están en la [guía de iOS](ios/Nido/README.md).

```bash
git clone https://github.com/pradosman/nido-ios.git
cd nido-ios
open ios/Nido/Nido.xcodeproj
```

En la pantalla de acceso, pulsa **Explorar demostración** para utilizar datos ficticios sin una cuenta ni contraseña. Puedes editar registros, probar los formularios, consultar el historial y preparar informes. **Reiniciar** restaura los datos de ejemplo y **Salir** vuelve al acceso. Las invitaciones de demostración son ficticias y no contactan con personas reales.

El uso con una cuenta real utiliza **Iniciar sesión con Apple**. La demostración permite probar la app sin compartir credenciales personales. Los flujos de sincronización entre cuentas reales y los servicios del sistema se comprueban por separado.

La demo no necesita levantar la API ni configurar una base de datos. En Debug sobre simulador, la configuración normal usa una dirección local de protección y no conecta a producción. La conexión real del simulador requiere activar expresamente `NIDO_SIMULATOR_PRODUCTION_OPT_IN=1` en el esquema de ejecución. Ese ajuste no es necesario para usar la demo.

## Stack tecnológico

| Componente | Tecnología |
|---|---|
| Aplicación para iPhone | Swift y SwiftUI, proyecto Xcode |
| API | TypeScript y Vinext, ejecutada en Node.js |
| Persistencia del servidor | PostgreSQL y Drizzle ORM |
| Autenticación real | Iniciar sesión con Apple y sesiones bearer |
| Infraestructura | Docker Compose y Dokploy en un VPS |
| Validación | Swift Testing, XCTest UI y contratos automatizados de la API |

## Estructura del proyecto

| Ruta | Contenido |
|---|---|
| [`ios/Nido/`](ios/Nido/) | Aplicación nativa, proyecto Xcode y pruebas de iOS |
| [`app/`](app/) | API y recursos del servidor |
| [`db/`](db/) y [`drizzle-pg/`](drizzle-pg/) | Acceso a datos y migraciones PostgreSQL |
| [`tests/`](tests/) | Contratos y pruebas automatizadas del servidor |
| [`deploy/`](deploy/) | Herramientas de operación, copia y restauración |
| [`docs/`](docs/) | Documentación técnica y evidencias de validación |

## Arquitectura del servicio

Nido es una app nativa para iPhone. El VPS ejecuta únicamente la API con Vinext en modo standalone y guarda los datos en PostgreSQL. La ruta `/` responde con `404`; la superficie pública prevista es `/api`.

## Desarrollo local

Para trabajar con el backend necesitas Node.js 22.13 o posterior y una instancia PostgreSQL accesible. La imagen Docker utiliza Node.js 24; se recomienda esa misma versión para reproducir el entorno del servidor.

```bash
npm install
export DATABASE_URL='postgres://nido:contraseña@127.0.0.1:5432/nido'
export NIDO_APPLE_AUDIENCE='com.momentumia.nido'
export NIDO_AUTH_BUCKET_SECRET="$(openssl rand -hex 32)"
npm run local
```

Comprueba el servicio con:

```bash
curl http://localhost:3000/api/nido/status
```

La ejecución local de la API permite probar sus rutas y contratos. La app no lee una variable genérica `NIDO_API_BASE_URL`: `AppConfiguration` selecciona la URL mediante `UITestLaunchPolicy`. El ejecutor de [pruebas UI con API local](docs/ios-local-real-api-ui-tests.md) prepara su propia configuración controlada. Para probar la aplicación con datos de ejemplo basta con la demo descrita arriba.

## Verificación

```bash
npm test
npm run lint
```

`npm test` genera el servidor standalone, compila el ejecutor de migraciones y ejecuta los contratos automatizados. Las pruebas de base de datos utilizan PGlite con el esquema PostgreSQL real; no necesitan una base externa.

### Límite de migración de datos

Este despliegue PostgreSQL se aprobó exclusivamente para la instalación **pre-user**, sin datos reales que conservar. **NO incluye ni realiza ninguna migración de datos desde D1**. Si una instalación contiene datos en D1, no debe desplegarse este cambio hasta preparar y validar un plan separado de exportación, transformación e importación. Nunca se deben abandonar datos existentes de forma silenciosa.

## Despliegue en Dokploy

### 1. Preparar secretos

Configura estas variables protegidas en Dokploy. Se inyectan directamente en los contenedores para conservar `read_only: true` sin depender de archivos dentro del checkout del repositorio:

```bash
NIDO_POSTGRES_PASSWORD=<contraseña-aleatoria-segura-para-url>
NIDO_AUTH_BUCKET_SECRET=<secreto-aleatorio-de-al-menos-32-caracteres>
NIDO_APPLE_AUDIENCE=com.momentumia.nido
```

No copies estos valores al repositorio ni a los archivos `.example`. El password de PostgreSQL admite únicamente caracteres seguros para URL porque el contenedor construye `DATABASE_URL` sin imprimirlo. Si el volumen `postgres-data` ya fue inicializado, reutiliza su contraseña original: cambiar únicamente la variable no cambia la contraseña almacenada por PostgreSQL.

### 2. Configurar Dokploy

1. Crea un servicio **Docker Compose** con `./compose.vps.yml`.
2. Define `NIDO_POSTGRES_PASSWORD`, `NIDO_AUTH_BUCKET_SECRET` y `NIDO_APPLE_AUDIENCE` como variables protegidas del servicio Compose. Para esta app, la audiencia es `com.momentumia.nido`.
3. Añade el dominio limitándolo a la API:

   | Campo | Valor |
   |---|---|
   | Host | `nido.momentumia.com` |
   | Path | `/api` |
   | Service | `nido` |
   | Container Port | `3000` |
   | HTTPS | Activado |
   | Strip Path | Desactivado |

4. Despliega. Compose espera a PostgreSQL, ejecuta las migraciones una vez y después inicia la API como usuario sin privilegios.

El servicio de PostgreSQL solo pertenece a la red interna y no publica puertos en el host. No añadas autenticación básica delante de `/api`: la app usa sus propias sesiones bearer.

### 3. Comprobar el despliegue

```bash
curl https://nido.momentumia.com/api/nido/status
curl --fail https://nido.momentumia.com/ && exit 1 || true
```

La primera petición debe responder correctamente. La segunda debe recibir `404`.

## Copias de seguridad y restauración

Los datos viven en el volumen `postgres-data`. El volumen sobrevive a reconstrucciones y reinicios; `docker compose down -v` lo elimina de forma irreversible.

### Crear una copia cifrada

Instala [`age`](https://age-encryption.org/), conserva la identidad privada fuera del VPS y ejecuta:

```bash
NIDO_AGE_RECIPIENT='age1...' \
  bash deploy/backup-postgres.sh "nido-$(date +%F-%H%M).dump.age"
```

El script transmite `pg_dump` directamente a `age`: no deja una copia en texto claro. Transfiere el archivo cifrado a almacenamiento fuera del VPS y aplica una política de retención.

### Restaurar

La restauración reemplaza por completo la base actual. Conserva antes una copia reciente y detén cualquier proceso externo que escriba en la API.

```bash
NIDO_AGE_IDENTITY='/ruta/fuera-del-repositorio/keys.txt' \
NIDO_RESTORE_CONFIRMED='restore-nido' \
  bash deploy/restore-postgres.sh nido-2026-09-01-1200.dump.age
```

El script valida primero el archivo, detiene la API, recrea la base, restaura, aplica migraciones y vuelve a iniciar el servicio.

Si la restauración falla después de detener Nido, el script termina sin reiniciar la API. No reinicies la API manualmente contra una base incompleta: conserva los registros, corrige la causa, vuelve a ejecutar la restauración desde una copia verificada y comprueba `/api/nido/status` antes de iniciar `nido`.

Una copia no está verificada solo porque existe. Programa periódicamente una restauración de prueba en un entorno aislado, comprueba `/api/nido/status` y valida datos representativos antes de considerar recuperable la copia.

## Lista operativa

- `/` responde con `404`.
- `/api/nido/status` responde sin credenciales.
- Las rutas privadas rechazan peticiones sin bearer válido.
- Los servicios `postgres` y `nido` figuran como saludables.
- PostgreSQL no publica ningún puerto en el host.
- Existe una copia reciente, cifrada, verificada y almacenada fuera del VPS.
- La aplicación de iPhone puede crear y sincronizar un registro.
