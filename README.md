# Nido para iPhone en un VPS

Nido es una app nativa para iPhone. El VPS ejecuta únicamente la API con Vinext en modo standalone y guarda los datos en PostgreSQL. La ruta `/` responde con `404`; la superficie pública prevista es `/api`.

## Desarrollo local

Necesitas Node.js 22.13 o posterior y una instancia PostgreSQL accesible.

```bash
npm install
export DATABASE_URL='postgres://nido:contraseña@127.0.0.1:5432/nido'
export NIDO_APPLE_AUDIENCE='com.example.nido'
export NIDO_AUTH_BUCKET_SECRET='un-secreto-aleatorio-de-al-menos-32-caracteres'
npm run local
```

Comprueba el servicio con:

```bash
curl http://localhost:3000/api/nido/status
```

Para usarlo desde el Simulator, configura `NIDO_API_BASE_URL` en el target `Nido`. En un iPhone físico usa la dirección LAN del equipo que ejecuta la API, no `127.0.0.1`.

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

No uses los valores de los archivos `.example`. Genera valores nuevos y guárdalos sin salto de línea final:

```bash
mkdir -p deploy/secrets
openssl rand -base64 36 | tr -d '=+/' | cut -c1-40 > deploy/secrets/postgres_password
openssl rand -hex 32 > deploy/secrets/auth_bucket_secret
chmod 600 deploy/secrets/postgres_password deploy/secrets/auth_bucket_secret
```

Los secretos reales están excluidos de Git. El password de PostgreSQL admite únicamente caracteres seguros para URL porque el contenedor construye `DATABASE_URL` sin imprimirlo.

### 2. Configurar Dokploy

1. Crea un servicio **Docker Compose** con `./compose.vps.yml`.
2. Define `NIDO_APPLE_AUDIENCE` con el identificador de la app que acepta Sign in with Apple.
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
