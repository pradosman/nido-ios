# Nido para iPhone: local y VPS

Nido es una app nativa para iPhone. El servicio del repositorio conserva y sincroniza los datos entre cuidadores; no es una versión web para uso diario. En el VPS utiliza una base SQLite persistente dentro de un volumen Docker.

## Arranque local

Necesitas Node.js 22.13 o posterior.

```bash
npm install
npm run local
```

Cada arranque verifica el esquema de forma segura y, si hace falta, crea la base local dentro de `.wrangler/state`. Comprueba el servicio con:

```bash
curl http://localhost:3000/api/nido/status
```

Para usarlo desde el Simulator, configura `NIDO_API_BASE_URL` en el target `Nido` con la dirección local del servicio. En un iPhone físico usa la IP local del Mac, no `127.0.0.1`.

Para comprobar una compilación de producción:

```bash
npm test
```

## Despliegue en el VPS

Requisitos: Docker con Compose, Caddy instalado en el host y un registro DNS `A` o `AAAA` de `nido.momentumia.com` apuntando al VPS.

1. Copia o clona el proyecto en el servidor.
2. Construye y arranca Nido:

   ```bash
   docker compose -f compose.vps.yml up -d --build
   docker compose -f compose.vps.yml ps
   ```

3. Copia el bloque de `deploy/Caddyfile.example` al Caddyfile del servidor. Valida y recarga Caddy:

   ```bash
   sudo caddy validate --config /etc/caddy/Caddyfile
   sudo systemctl reload caddy
   ```

4. Comprueba la API:

   ```bash
   curl https://nido.momentumia.com/api/nido/status
   ```

El contenedor solo publica el servicio en `127.0.0.1:43129`; Caddy es el único punto expuesto a Internet y obtiene/renueva HTTPS automáticamente. Los datos privados requieren la credencial de cuidador guardada en el Keychain del iPhone. No añadas `basic_auth` delante de toda la API: impediría que la app nativa sincronizase.

## Operaciones habituales

| Acción | Comando |
|---|---|
| Ver estado | `docker compose -f compose.vps.yml ps` |
| Ver registros | `docker compose -f compose.vps.yml logs -f nido` |
| Actualizar | `git pull && docker compose -f compose.vps.yml up -d --build` |
| Detener | `docker compose -f compose.vps.yml down` |
| Verificar desde el VPS | `curl http://127.0.0.1:43129/api/nido/status` |

## Datos y copias de seguridad

Los datos viven en el volumen `nido-data` y sobreviven a reconstrucciones y reinicios. `docker compose down` no los elimina; evita `docker compose down -v` salvo que quieras borrar todo.

Copia de seguridad:

```bash
docker compose -f compose.vps.yml exec -T nido \
  sh -c 'tar -czf - -C /data .' > "nido-backup-$(date +%F).tar.gz"
```

Guarda la copia fuera del VPS. Antes de restaurar, detén Nido y conserva una copia del volumen actual.

## Comprobación final

- `/api/nido/status` responde con `configured`.
- La aplicación de iPhone abre y permite crear un registro.
- Un segundo iPhone puede unirse con una invitación y ve la misma información.
- El contenedor figura como `healthy`.
- El registro sigue presente después de `docker compose restart nido`.
